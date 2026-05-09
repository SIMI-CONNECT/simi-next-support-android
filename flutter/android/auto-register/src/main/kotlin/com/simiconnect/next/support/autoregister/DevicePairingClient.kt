package com.simiconnect.next.support.autoregister

import android.content.Context
import android.net.Uri
import android.util.Log

data class DeviceCredentials(
    val deviceId: String,
    val deviceAccessKey: String,
    val macAddress: String,
)

/**
 * Reads device-pairing info from the **main player**
 * (`simi-next-android`) via a signature-permission-protected
 * ContentProvider. See README "ContentProvider pairing decision".
 *
 * If the main player isn't installed (or hasn't yet shipped the
 * provider), [fetchDeviceCredentials] returns null and the caller
 * (the worker) treats that as a hard failure with a clear log line —
 * not an indefinite retry.
 *
 * TODO(verify): DEVICE_PAIRING_AUTHORITY and column names. The
 * authority below is the proposed value; confirm against the
 * follow-up PR on `simi-next-android` that adds the provider. If
 * the column names diverge, update [COL_*] constants here only.
 */
class DevicePairingClient(private val context: Context) {

    fun fetchDeviceCredentials(): DeviceCredentials? {
        val uri = Uri.parse("content://$AUTHORITY/$PATH")
        return try {
            context.contentResolver.query(
                uri,
                arrayOf(COL_DEVICE_ID, COL_DEVICE_ACCESS_KEY, COL_MAC_ADDRESS),
                null,
                null,
                null,
            )?.use { c ->
                if (!c.moveToFirst()) return null
                val deviceId = c.getString(c.getColumnIndexOrThrow(COL_DEVICE_ID))
                val key = c.getString(c.getColumnIndexOrThrow(COL_DEVICE_ACCESS_KEY))
                val mac = c.getString(c.getColumnIndexOrThrow(COL_MAC_ADDRESS))
                if (deviceId.isNullOrBlank() || key.isNullOrBlank() || mac.isNullOrBlank()) {
                    null
                } else {
                    DeviceCredentials(deviceId, key, mac)
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "no permission to read pairing provider — signature mismatch?")
            null
        } catch (e: IllegalArgumentException) {
            // Unknown authority — provider isn't installed.
            Log.w(TAG, "pairing provider not present at $AUTHORITY")
            null
        }
    }

    private companion object {
        const val TAG = "SimiSupportPairing"
        // TODO(verify): authority and column names.
        const val AUTHORITY = "com.simiconnect.next.devicepairing"
        const val PATH = "credentials"
        const val COL_DEVICE_ID = "device_id"
        const val COL_DEVICE_ACCESS_KEY = "device_access_key"
        const val COL_MAC_ADDRESS = "mac_address"
    }
}
