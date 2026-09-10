package me.capcom.smsgateway.modules.gateway

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import me.capcom.smsgateway.modules.notifications.NotificationsService
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Handles the "Approve"/"Reject" buttons on the pairing notification. Confirms
 * (or declines) the operator's request to attach this phone; on approval the
 * backend finally links the phone to that account.
 */
class ClaimActionReceiver : BroadcastReceiver(), KoinComponent {

    private val settings: GatewaySettings by inject()
    private val notificationsSvc: NotificationsService by inject()

    override fun onReceive(context: Context, intent: Intent) {
        val approve = intent.action == NotificationsService.ACTION_CLAIM_APPROVE
        val deviceId = intent.getStringExtra(NotificationsService.EXTRA_DEVICE_ID) ?: return
        val token = settings.privateToken.orEmpty()

        notificationsSvc.cancelClaimRequest()

        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                TizBizAnnounce.confirmClaim(token, deviceId, approve)
            } finally {
                pending.finish()
            }
        }
    }
}
