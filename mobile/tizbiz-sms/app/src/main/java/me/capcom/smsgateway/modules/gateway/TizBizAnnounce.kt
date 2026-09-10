package me.capcom.smsgateway.modules.gateway

import android.annotation.SuppressLint
import android.content.Context
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * After the phone registers on the gateway, report its gateway-issued credentials
 * to the TizBiz backend so an operator can attach the phone from the dashboard by
 * selecting it — no manual typing of login/password. Best-effort and
 * fire-and-forget: never blocks or breaks device registration.
 */
object TizBizAnnounce {
    private const val ANNOUNCE_URL = "https://api.tizbiz.uz/v1/sms/devices/announce"

    private val client = OkHttpClient.Builder()
        .callTimeout(15, TimeUnit.SECONDS)
        .build()

    /** gate.tizbiz.uz/api/mobile/v1 -> gate.tizbiz.uz/api/3rdparty/v1 (the send base). */
    fun deriveThirdPartyBase(mobileUrl: String): String =
        mobileUrl.trimEnd('/').replace("/api/mobile/v1", "/api/3rdparty/v1")

    /** Best-effort own MSISDN; empty is the common case (carrier didn't store it). */
    @SuppressLint("MissingPermission")
    fun readSimNumber(context: Context): String {
        return try {
            if (Build.VERSION.SDK_INT >= 33) {
                val sm = context.getSystemService(SubscriptionManager::class.java)
                val subs = sm?.activeSubscriptionInfoList
                if (subs != null) {
                    for (info in subs) {
                        val n = sm.getPhoneNumber(info.subscriptionId)
                        if (!n.isNullOrBlank()) return n
                    }
                }
                ""
            } else {
                @Suppress("DEPRECATION")
                val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                @Suppress("DEPRECATION")
                tm?.line1Number.orEmpty()
            }
        } catch (_: Throwable) {
            ""
        }
    }

    /** Fire-and-forget announce on a background thread. */
    fun announce(
        context: Context,
        token: String,
        deviceId: String,
        login: String?,
        password: String?,
        name: String,
        serverBase: String,
        ownerNumber: String? = null,
    ) {
        if (token.isBlank() || deviceId.isBlank()) return
        val appContext = context.applicationContext
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Prefer the SIM auto-read; fall back to the number the user typed
                // under "This phone's number". This value binds the phone to the
                // matching TizBiz account and hides it from every other account.
                val number = readSimNumber(appContext).ifBlank { ownerNumber.orEmpty() }
                val body = JSONObject()
                    .put("device_id", deviceId)
                    .put("login", login ?: "")
                    .put("password", password ?: "")
                    .put("name", name)
                    .put("sim_number", number)
                    .put("server", serverBase)
                    .toString()
                val req = Request.Builder()
                    .url(ANNOUNCE_URL)
                    .header("X-Announce-Token", token)
                    .post(body.toRequestBody("application/json".toMediaType()))
                    .build()
                client.newCall(req).execute().use { /* ignore response */ }
            } catch (_: Throwable) {
                // best-effort; never break registration
            }
        }
    }
}
