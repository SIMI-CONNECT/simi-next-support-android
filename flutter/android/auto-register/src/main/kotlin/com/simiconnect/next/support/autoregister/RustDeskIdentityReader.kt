package com.simiconnect.next.support.autoregister

import android.content.Context
import android.util.Log

data class RustDeskIdentity(
    val rustdeskId: String,
    val passwordPlaintext: String,
)

/**
 * Reads the device's RustDesk identity (9-digit ID + permanent
 * password) that the Dart side stamps into a small SharedPreferences
 * file at every HomePage tick.
 *
 * Why SharedPreferences and not RustDesk's own config files: upstream
 * RustDesk's Android build writes its TOML to a path that varies
 * between Flutter releases (`app_flutter/Logs/...`,
 * `files/.config/RustDesk/...`, etc.) and is not part of any
 * stable contract. Bridging via SharedPreferences keeps the worker
 * decoupled from RustDesk's on-disk layout — Dart's
 * `bind.mainGetMyId()` / `bind.mainGetPermanentPassword()` are the
 * authoritative source on the Flutter side, and we just stamp them
 * here.
 *
 * The Dart writer lives in `flutter/lib/simi_branding/`.
 */
object RustDeskIdentityReader {

    private const val TAG = "SimiSupportRdRead"
    private const val PREFS_NAME = "simi_support_credentials"
    private const val KEY_RUSTDESK_ID = "rustdesk_id"
    private const val KEY_PERMANENT_PASSWORD = "permanent_password"

    @Suppress("RedundantSuspendModifier") // suspend kept to preserve worker call signature
    suspend fun read(context: Context): RustDeskIdentity? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        // Accept 9 or 10 digits — RustDesk historically issued 9-digit
        // numeric IDs, but the help.simiconnect.com rendezvous server is
        // assigning 10-digit values. The backend DTO is currently
        // `^[0-9]{9}$`; if it 422s, the fix is on the backend not here.
        val id = prefs.getString(KEY_RUSTDESK_ID, null)?.takeIf {
            it.matches(Regex("^[0-9]{9,10}$"))
        }
        val pwd = prefs.getString(KEY_PERMANENT_PASSWORD, null)?.takeIf { it.isNotBlank() }
        if (id == null) {
            Log.w(TAG, "rustdesk id not yet stamped by Dart side; retrying later")
            return null
        }
        if (pwd == null) {
            Log.w(TAG, "permanent password not yet stamped by Dart side; retrying later")
            return null
        }
        return RustDeskIdentity(rustdeskId = id, passwordPlaintext = pwd)
    }
}
