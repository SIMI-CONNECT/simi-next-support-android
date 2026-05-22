// Copyright (c) Simi Connect — Next Support fork.
// Original work: RustDesk, GPL-3.0. This file is GPL-3.0.
// Modifications: see git history of SIMI-CONNECT/simi-next-support-android.
//
// build.gradle.simi.kts — Simi Next Support overrides applied on top of
// upstream RustDesk's flutter/android/app/build.gradle.kts.
//
// Wiring:
//   This snippet is included from the upstream build.gradle.kts via a
//   line added by patches/0001-applicationId-build-arg.patch:
//
//       apply(from = "build.gradle.simi.kts")
//
//   That patch also rewrites the upstream `applicationId = "..."` line
//   to read from the Gradle property `simi.applicationId` (with a
//   default that matches what we set below), so everything funnels
//   through one place.
//
// Build-arg contract (passed by CI via -P, defaulted here for local
// smoke builds — never commit real values):
//   simi.applicationId       Android applicationId (default below)
//   simi.versionName         human version, e.g. "0.1.0"
//   simi.versionCode         monotonic int, e.g. 1
//   simi.rendezvousServer    e.g. help.simiconnect.com
//   simi.rsPubKey            base64 ed25519 pubkey from server/data/id_ed25519.pub
//   simi.apiServer           usually empty (we don't run RustDesk Pro)
//   simi.backendBaseUrl      Simi backend, e.g. https://api.simiconnect.com
//
// All four runtime values are exposed two ways:
//   1. BuildConfig.<NAME>            — for Kotlin / Java code
//   2. resValue("string", ...)       — for code that reads
//                                       R.string.simi_* (and for the
//                                       Dart layer when it does the same
//                                       via the Android resource bridge).
//
// History note (2026-05-13): we used to ALSO write these into
// `manifestPlaceholders[…]` with the assumption that those substitute
// `${simi*}` tokens inside `res/values/simi-config.xml`. They don't —
// manifest placeholders are scoped to `AndroidManifest.xml` only.
// Result: v0.1.0 / v0.1.1-pre shipped with `${simiRsPubKey}` literally
// stored in the string resource, and the runtime pairing flow couldn't
// find a usable key. Replacing those calls with `resValue` is the fix.
// `simi-config.xml` was deleted in the same commit because it would
// conflict with the synthetic resources `resValue` generates.

import com.android.build.gradle.AppExtension

fun prop(key: String, default: String): String =
    (project.findProperty(key) as String?) ?: default

val simiApplicationId    = prop("simi.applicationId",    "com.simiconnect.next.support")
val simiVersionName      = prop("simi.versionName",      "0.1.0-dev")
val simiVersionCode      = prop("simi.versionCode",      "1").toInt()
val simiRendezvousServer = prop("simi.rendezvousServer", "help.simiconnect.com")
val simiRsPubKey         = prop("simi.rsPubKey",         "PLACEHOLDER_RS_PUB_KEY")
val simiApiServer        = prop("simi.apiServer",        "")
val simiBackendBaseUrl   = prop("simi.backendBaseUrl",   "https://api.simiconnect.example")

extensions.configure<AppExtension>("android") {
    defaultConfig {
        applicationId = simiApplicationId
        versionName   = simiVersionName
        versionCode   = simiVersionCode

        // BuildConfig fields — referenced from Kotlin / Java glue and
        // (via patches/0002-rendezvous-key-from-buildconfig.patch) from
        // the Dart bridge layer through --dart-define mirrors injected
        // by the Flutter wrapper.
        //
        // Field naming: stay UN-prefixed (`BACKEND_BASE_URL`, not
        // `SIMI_BACKEND_BASE_URL`) so the existing auto-register Kotlin
        // call site `BuildConfig.BACKEND_BASE_URL` resolves without an
        // import-rename across the support code.
        buildConfigField("String", "RENDEZVOUS_SERVER", "\"$simiRendezvousServer\"")
        buildConfigField("String", "RS_PUB_KEY",        "\"$simiRsPubKey\"")
        buildConfigField("String", "API_SERVER",        "\"$simiApiServer\"")
        buildConfigField("String", "BACKEND_BASE_URL",  "\"$simiBackendBaseUrl\"")

        // String resources — populated via resValue so anything that
        // reads `R.string.simi_*` (notably the Dart layer's resource
        // bridge in the rendezvous-key bake-in patch) gets a real
        // value, not a literal `${simiRsPubKey}` placeholder. This
        // replaces the prior `manifestPlaceholders` approach, which
        // ONLY substitutes tokens inside AndroidManifest.xml — not
        // inside res/values/*.xml.
        resValue("string", "simi_rendezvous_server", simiRendezvousServer)
        resValue("string", "simi_rs_pub_key",        simiRsPubKey)
        resValue("string", "simi_api_server",        simiApiServer)
        resValue("string", "simi_backend_base_url",  simiBackendBaseUrl)

        // AndroidManifest.xml still uses ${simi*} for any <meta-data>
        // entries, so we keep these for the manifest path.
        manifestPlaceholders["simiRendezvousServer"] = simiRendezvousServer
        manifestPlaceholders["simiRsPubKey"]         = simiRsPubKey
        manifestPlaceholders["simiApiServer"]        = simiApiServer
        manifestPlaceholders["simiBackendBaseUrl"]   = simiBackendBaseUrl
    }

    buildFeatures {
        buildConfig = true
    }
}

// Mirror Gradle props into --dart-define so Flutter sees the same values.
// The Flutter Gradle plugin reads `dart-defines` from extra properties.
project.extensions.extraProperties.set(
    "dart-defines",
    listOf(
        "SIMI_RENDEZVOUS_SERVER=$simiRendezvousServer",
        "SIMI_RS_PUB_KEY=$simiRsPubKey",
        "SIMI_API_SERVER=$simiApiServer",
        "SIMI_BACKEND_BASE_URL=$simiBackendBaseUrl",
    ).joinToString(",")
)

// Fail-fast if a release build is being made with placeholder values
// (would re-introduce the v0.1.0 / v0.1.1-pre runtime-pairing breakage).
// Local debug builds keep the placeholders so contributors can compile
// without secrets; only `assembleRelease` / `bundleRelease` enforces.
gradle.taskGraph.whenReady {
    val isRelease = allTasks.any { it.name.contains("Release", ignoreCase = true) }
    if (isRelease) {
        val bad = mutableListOf<String>()
        if (simiRsPubKey == "PLACEHOLDER_RS_PUB_KEY")       bad += "simi.rsPubKey"
        if (simiBackendBaseUrl == "https://api.simiconnect.example") bad += "simi.backendBaseUrl"
        if (bad.isNotEmpty()) {
            throw GradleException(
                "Refusing to build release with placeholder values for: ${bad.joinToString()}. " +
                "Pass them via gradle.properties or `-P` (release.yml writes them from secrets)."
            )
        }
    }
}
