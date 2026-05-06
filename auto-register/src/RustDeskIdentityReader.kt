package com.simiconnect.next.support.autoregister

import android.content.Context
import android.util.Log
import java.io.File

data class RustDeskIdentity(
    val rustdeskId: String,
    val passwordPlaintext: String,
)

/**
 * Reads RustDesk's locally-generated 9-digit ID and permanent password
 * from the Android client's on-disk config.
 *
 * TODO(verify): RUSTDESK_PREFS_CANDIDATES.
 *
 * RustDesk's Android client persists its config via the Rust core,
 * not via Android SharedPreferences. The config file is typically a
 * TOML/JSON-ish key=value file under the app's private data directory.
 * Candidate locations to verify against the upstream source we fork
 * from:
 *
 *   1. ${dataDir}/files/RustDesk.toml
 *   2. ${dataDir}/files/config/RustDesk.toml
 *   3. ${dataDir}/files/config/RustDesk2.toml      (peer/options split)
 *   4. ${dataDir}/files/.config/RustDesk/RustDesk.toml
 *
 * Keys observed in upstream `libs/hbb_common/src/config.rs`:
 *   - `id = "<9 digits>"`            (the rendezvous id)
 *   - `password = "<permanent>"`     (only present when the user has
 *                                     set a permanent password — by
 *                                     default RustDesk uses one-time
 *                                     codes; the support fork MUST
 *                                     force a permanent password at
 *                                     first run, that is the
 *                                     fork-bootstrap agent's job)
 *
 * If neither candidate yields both fields, return null and log a
 * warning. The worker treats null as Result.retry() — RustDesk may
 * simply not have generated the ID yet on a brand-new install.
 *
 * Do NOT invent a fake-looking path. The operator must replace the
 * candidate list with the real one once the upstream version is
 * pinned.
 */
object RustDeskIdentityReader {

    private const val TAG = "SimiSupportRdRead"

    suspend fun read(context: Context): RustDeskIdentity? {
        val dataDir = context.applicationInfo.dataDir
        val candidates = listOf(
            File(dataDir, "files/RustDesk.toml"),
            File(dataDir, "files/config/RustDesk.toml"),
            File(dataDir, "files/config/RustDesk2.toml"),
            File(dataDir, "files/.config/RustDesk/RustDesk.toml"),
        )
        var idFromAny: String? = null
        for (f in candidates) {
            if (!f.isFile) continue
            val parsed = parseSimpleKv(f.readText())
            val id = parsed["id"]?.takeIf { it.matches(Regex("^[0-9]{9}$")) }
            val pwd = parsed["password"]?.takeIf { it.isNotBlank() }
            if (id != null) idFromAny = id
            if (id != null && pwd != null) {
                return RustDeskIdentity(rustdeskId = id, passwordPlaintext = pwd)
            }
        }
        if (idFromAny != null) {
            Log.w(TAG, "rustdesk id present but permanent password not set yet; retrying later")
        } else {
            Log.w(TAG, "no rustdesk config found in any candidate path; retrying later")
        }
        return null
    }

    /**
     * Minimal `key = "value"` extractor. Tolerates surrounding quotes
     * and trailing comments. Not a full TOML parser — only the two
     * fields we need.
     */
    private fun parseSimpleKv(text: String): Map<String, String> {
        val out = mutableMapOf<String, String>()
        for (rawLine in text.lineSequence()) {
            val line = rawLine.trim()
            if (line.isEmpty() || line.startsWith("#") || line.startsWith("[")) continue
            val eq = line.indexOf('=')
            if (eq <= 0) continue
            val k = line.substring(0, eq).trim()
            var v = line.substring(eq + 1).trim()
            val hash = v.indexOf('#')
            if (hash >= 0) v = v.substring(0, hash).trim()
            if (v.length >= 2 && v.first() == '"' && v.last() == '"') {
                v = v.substring(1, v.length - 1)
            }
            out[k] = v
        }
        return out
    }
}
