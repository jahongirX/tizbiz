package me.capcom.smsgateway.modules.gateway

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import me.capcom.smsgateway.modules.notifications.NotificationsService
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject
import java.util.concurrent.TimeUnit

/**
 * While the gateway is enabled and registered, poll the TizBiz backend for a
 * pending pairing request (an operator asked to attach this phone from the
 * dashboard). When one appears, raise a heads-up notification so the owner can
 * confirm. Self-reschedules every {@link #POLL_INTERVAL_SECONDS}; stops itself
 * once the gateway is turned off. No Firebase needed.
 */
class ClaimPollWorker(appContext: Context, params: WorkerParameters) :
    CoroutineWorker(appContext, params), KoinComponent {

    private val settings: GatewaySettings by inject()
    private val notificationsSvc: NotificationsService by inject()

    override suspend fun doWork(): Result {
        val deviceId = settings.deviceId
        val token = settings.privateToken.orEmpty()
        if (!settings.enabled || deviceId == null || token.isBlank()) {
            return Result.success() // stop the loop
        }

        val request = TizBizAnnounce.checkClaimRequest(token, deviceId)
        if (request != null) {
            notificationsSvc.notifyClaimRequest(applicationContext, deviceId, request.account)
        }

        schedule(applicationContext, POLL_INTERVAL_SECONDS)
        return Result.success()
    }

    companion object {
        private const val NAME = "TizBizClaimPoll"
        private const val POLL_INTERVAL_SECONDS = 20L

        /** Begin (or restart) the polling loop. */
        fun start(context: Context) = schedule(context, 0)

        fun stop(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(NAME)
        }

        private fun schedule(context: Context, delaySeconds: Long) {
            val work = OneTimeWorkRequestBuilder<ClaimPollWorker>()
                .setInitialDelay(delaySeconds, TimeUnit.SECONDS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .build()
            WorkManager.getInstance(context)
                .enqueueUniqueWork(NAME, ExistingWorkPolicy.REPLACE, work)
        }
    }
}
