package com.simiconnect.next.support.autoregister

import android.content.Context
import android.util.Base64
import android.util.Log
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.simiconnect.next.support.BuildConfig
import kotlinx.coroutines.flow.first
import retrofit2.HttpException
import java.io.IOException

private val Context.supportRegisterDataStore by preferencesDataStore(
    name = "simi_support_auto_register",
)

/**
 * One-shot worker. Read RustDesk identity → look up device pairing →
 * encrypt → POST → store marker. See README "Operator TODO(verify)
 * checklist" before assuming any of the I/O paths are settled.
 */
class SupportAutoRegisterWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    private val tag = "SimiSupportAutoReg"
    private val markerKey = stringPreferencesKey("last_registered_id_pwfp")

    override suspend fun doWork(): Result {
        // 1. Read RustDesk's locally-generated identity.
        val rd = RustDeskIdentityReader.read(applicationContext)
        if (rd == null) {
            Log.w(tag, "RustDesk identity not yet available; will retry")
            return Result.retry()
        }

        // 2. Resolve device pairing from the main player's ContentProvider.
        val pairing = DevicePairingClient(applicationContext).fetchDeviceCredentials()
        if (pairing == null) {
            Log.e(tag, "main player not installed; cannot register for support")
            return Result.failure()
        }

        // 3. Compute fingerprints.
        val pwdSha = Crypto.sha256(rd.passwordPlaintext.toByteArray(Charsets.UTF_8))
        val pwdShaHex = pwdSha.toHexLower()
        val markerValue = "${rd.rustdeskId}:$pwdShaHex"

        // 4. Idempotent skip.
        val prefs = applicationContext.supportRegisterDataStore.data.first()
        if (prefs[markerKey] == markerValue) {
            Log.i(tag, "already registered for id=${rd.rustdeskId} pwfp=${pwdShaHex.take(8)}; skipping")
            return Result.success()
        }

        // 5. Encrypt + sign payload.
        val pubKey = decodePubKey()
        val sealed = Crypto.sealBoxEncrypt(
            plaintext = rd.passwordPlaintext.toByteArray(Charsets.UTF_8),
            recipientPubKey = pubKey,
        )
        val ciphertextB64 = Base64.encodeToString(sealed, Base64.NO_WRAP)
        val pubKeyFpHex = Crypto.sha256(pubKey).toHexLower()

        // 6. POST.
        val api = SupportAutoRegisterApi.build(applicationContext, pairing)
        val body = SupportRegistrationRequest(
            rustdesk_id = rd.rustdeskId,
            password_ciphertext = ciphertextB64,
            client_pub_key_fp = pubKeyFpHex,
        )
        return try {
            val resp = api.register(body)
            if (resp.isSuccessful) {
                applicationContext.supportRegisterDataStore.edit { it[markerKey] = markerValue }
                Log.i(tag, "registered id=${rd.rustdeskId} pwfp=${pwdShaHex.take(8)}")
                Result.success()
            } else when (val code = resp.code()) {
                401, 403 -> {
                    Log.e(tag, "auth failed ($code); operator must investigate")
                    Result.failure()
                }
                in 500..599 -> {
                    Log.w(tag, "backend $code; will retry")
                    Result.retry()
                }
                else -> {
                    Log.e(tag, "unexpected $code; not retrying")
                    Result.failure()
                }
            }
        } catch (e: HttpException) {
            if (e.code() in 500..599) Result.retry() else Result.failure()
        } catch (e: IOException) {
            Log.w(tag, "network IO; will retry: ${e.javaClass.simpleName}")
            Result.retry()
        }
    }

    private fun decodePubKey(): ByteArray {
        val raw = BuildConfig.BACKEND_SUPPORT_PUBKEY
        require(raw.isNotBlank()) { "BACKEND_SUPPORT_PUBKEY missing" }
        val bytes = Base64.decode(raw, Base64.DEFAULT)
        require(bytes.size == 32) { "BACKEND_SUPPORT_PUBKEY must be 32 bytes (got ${bytes.size})" }
        return bytes
    }

    private fun ByteArray.toHexLower(): String {
        val sb = StringBuilder(size * 2)
        for (b in this) {
            sb.append(HEX[(b.toInt() ushr 4) and 0x0f])
            sb.append(HEX[b.toInt() and 0x0f])
        }
        return sb.toString()
    }

    private companion object {
        val HEX = "0123456789abcdef".toCharArray()
    }
}
