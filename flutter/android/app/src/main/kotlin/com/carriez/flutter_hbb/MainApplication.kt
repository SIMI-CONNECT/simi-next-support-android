package com.carriez.flutter_hbb

import android.app.Application
import android.util.Log
import com.simiconnect.next.support.autoregister.SupportAutoRegister
import ffi.FFI

class MainApplication : Application() {
    companion object {
        private const val TAG = "MainApplication"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "App start")
        FFI.onAppStart(applicationContext)
        // Enqueue the support-registration worker. Idempotent — uses
        // ExistingWorkPolicy.KEEP and a (rustdesk_id, password
        // fingerprint) marker, so calling on every onCreate is a no-op
        // unless the credentials actually changed.
        SupportAutoRegister(applicationContext).maybeEnqueue()
    }
}
