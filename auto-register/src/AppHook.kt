// HOW TO WIRE: Simi Next Support — auto-register integration point
// ----------------------------------------------------------------
// This file is **comment-only**. Do not compile it as part of the APK
// (the fork-bootstrap agent should exclude `AppHook.kt` from its
// overlay copy, or rename to `.kt.txt`). Its purpose is to document
// exactly where to add the single integration call once the upstream
// RustDesk Android Application/Activity class name is pinned.
//
// ── Option A: upstream has a custom Application class ─────────────
// File (upstream): flutter/android/app/src/main/kotlin/.../MyApp.kt
//
//   class MyApp : FlutterApplication() {
//       override fun onCreate() {
//           super.onCreate()
//           // ... existing upstream init ...
//
//           // >>> ADD THIS LINE (and the matching import) <<<
//           com.simiconnect.next.support.autoregister
//               .SupportAutoRegister(this).maybeEnqueue()
//       }
//   }
//
// ── Option B: upstream has no custom Application ──────────────────
// Add one in the overlay (the fork-bootstrap agent's territory) and
// register it in AndroidManifest.xml via android:name=".SimiSupportApp".
//
//   class SimiSupportApp : android.app.Application() {
//       override fun onCreate() {
//           super.onCreate()
//           com.simiconnect.next.support.autoregister
//               .SupportAutoRegister(this).maybeEnqueue()
//       }
//   }
//
// ── Notes ─────────────────────────────────────────────────────────
//  * Calling maybeEnqueue() on every onCreate is intentional and safe
//    (ExistingWorkPolicy.KEEP + DataStore fingerprint guard).
//  * Do NOT call this from MainActivity.onCreate if a custom
//    Application exists — Application.onCreate is the canonical seam.
//  * Do NOT pass anything other than `applicationContext`; the worker
//    is started by WorkManager which binds to the Application context
//    on its own.
package com.simiconnect.next.support.autoregister.appwiring
