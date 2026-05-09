package com.simiconnect.next.support.autoregister

import com.goterl.lazysodium.LazySodiumAndroid
import com.goterl.lazysodium.SodiumAndroid
import com.goterl.lazysodium.interfaces.Box
import java.security.MessageDigest

/**
 * Sealed-box encryption + SHA-256, the only crypto this module needs.
 * Backed by lazysodium-android (libsodium JNA). The matching server
 * decrypt path is `backend/src/crypto.ts#decryptSealedBox`.
 *
 * No private key handling on the device — sealed boxes are write-only
 * to the device by design (anonymous sender, holder of recipient
 * private key is the only reader).
 */
object Crypto {

    private val lazy: LazySodiumAndroid by lazy { LazySodiumAndroid(SodiumAndroid()) }

    /**
     * libsodium `crypto_box_seal`. Output layout is:
     *   ephemeral_pubkey(32) || XSalsa20-Poly1305 ciphertext+tag
     * Total overhead = `Box.SEALBYTES` (48 bytes).
     */
    fun sealBoxEncrypt(plaintext: ByteArray, recipientPubKey: ByteArray): ByteArray {
        require(recipientPubKey.size == Box.PUBLICKEYBYTES) {
            "recipient pubkey must be ${Box.PUBLICKEYBYTES} bytes; got ${recipientPubKey.size}"
        }
        val out = ByteArray(plaintext.size + Box.SEALBYTES)
        val ok = lazy.sodium.crypto_box_seal(
            out,
            plaintext,
            plaintext.size.toLong(),
            recipientPubKey,
        )
        check(ok == 0) { "crypto_box_seal failed (rc=$ok)" }
        return out
    }

    fun sha256(b: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(b)
}
