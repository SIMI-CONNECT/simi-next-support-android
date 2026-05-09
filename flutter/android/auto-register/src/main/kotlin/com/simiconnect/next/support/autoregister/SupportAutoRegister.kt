package com.simiconnect.next.support.autoregister

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * Public entry point for the Next Support auto-registration flow.
 *
 * Wire from the upstream RustDesk Android `Application.onCreate` (see
 * AppHook.kt for the exact placement comment). Internally idempotent:
 *  - Uses [ExistingWorkPolicy.KEEP] so calling [maybeEnqueue] on every
 *    launch does NOT replace an in-flight or pending registration.
 *  - The worker itself short-circuits if the (rustdesk_id, password
 *    fingerprint) marker matches the last successful POST.
 */
class SupportAutoRegister(private val context: Context) {

    fun maybeEnqueue() = enqueue(ExistingWorkPolicy.KEEP)

    /**
     * Force-replace whatever's currently in WorkManager (typically a
     * pending exponential-backoff retry) and run immediately. Use after
     * the Dart side has stamped fresh credentials — otherwise the
     * worker may not pick them up for many minutes.
     */
    fun forceEnqueue() = enqueue(ExistingWorkPolicy.REPLACE)

    private fun enqueue(policy: ExistingWorkPolicy) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val request = OneTimeWorkRequestBuilder<SupportAutoRegisterWorker>()
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                INITIAL_BACKOFF_SECONDS,
                TimeUnit.SECONDS,
            )
            .addTag(WORK_TAG)
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            UNIQUE_WORK_NAME,
            policy,
            request,
        )
    }

    companion object {
        const val WORK_TAG = "simi-support-auto-register"
        const val UNIQUE_WORK_NAME = "simi-support-auto-register"
        private const val INITIAL_BACKOFF_SECONDS = 30L
    }
}
