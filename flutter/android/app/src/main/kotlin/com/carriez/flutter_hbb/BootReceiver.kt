package com.carriez.flutter_hbb

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

const val DEBUG_BOOT_COMPLETED = "com.carriez.flutter_hbb.DEBUG_BOOT_COMPLETED"

/** SharedPreferences file written by MainActivity.stamp_support_credentials. */
const val SIMI_SUPPORT_CREDS_PREFS = "simi_support_credentials"
const val SIMI_KEY_PERMANENT_PASSWORD = "permanent_password"

/**
 * True once the Flutter UI has run at least once and provisioned this panel:
 * it sets approve-mode=password and verification-method=use-permanent-password,
 * generates a strong permanent password, and reports it to the backend.
 *
 * Starting the service before that happens would put the panel on the public
 * relay carrying RustDesk's upstream defaults - a six-character auto-generated
 * temporary password and approve-mode=both - which nobody could answer and
 * which no operator would hold. So an unprovisioned panel simply does not join.
 */
fun supportCredentialsStamped(context: Context): Boolean {
    val prefs = context.getSharedPreferences(SIMI_SUPPORT_CREDS_PREFS, Context.MODE_PRIVATE)
    return !prefs.getString(SIMI_KEY_PERMANENT_PASSWORD, null).isNullOrBlank()
}

/** The intent both unattended start sites use. EXT_INIT_FROM_BOOT is what makes
 *  MainService call FFI.startService() (relay registration) and suppress the
 *  screen-capture consent dialog. */
fun unattendedServiceIntent(context: Context): Intent =
    Intent(context, MainService::class.java).apply {
        action = ACT_INIT_MEDIA_PROJECTION_AND_SERVICE
        putExtra(EXT_INIT_FROM_BOOT, true)
    }

class BootReceiver : BroadcastReceiver() {
    private val logTag = "tagBootReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(logTag, "onReceive ${intent.action}")

        if (Intent.ACTION_BOOT_COMPLETED == intent.action || DEBUG_BOOT_COMPLETED == intent.action) {
            // These panels are unattended, so the upstream KEY_START_ON_BOOT_OPT
            // preference and the battery/overlay permission gate can never be
            // satisfied - there is nobody at the screen to grant them.
            if (!supportCredentialsStamped(context)) {
                Log.i(logTag, "support credentials not stamped yet; not joining the relay")
                return
            }
            // BOOT_COMPLETED receivers are exempt from the background
            // foreground-service-start restriction, so this is allowed here.
            val svc = unattendedServiceIntent(context)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(svc)
            } else {
                context.startService(svc)
            }
        }
    }
}
