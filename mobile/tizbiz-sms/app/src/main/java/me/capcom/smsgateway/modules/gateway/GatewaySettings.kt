package me.capcom.smsgateway.modules.gateway

import me.capcom.smsgateway.modules.settings.Exporter
import me.capcom.smsgateway.modules.settings.Importer
import me.capcom.smsgateway.modules.settings.KeyValueStorage
import me.capcom.smsgateway.modules.settings.get

class GatewaySettings(
    private val storage: KeyValueStorage,
) : Exporter, Importer {
    enum class NotificationChannel {
        AUTO,
        SSE_ONLY,
    }

    var enabled: Boolean
        // TizBiz: cloud server on by default so a fresh install just taps Start.
        get() = storage.get<Boolean>(ENABLED) ?: true
        set(value) = storage.set(ENABLED, value)

    val deviceId: String?
        get() = registrationInfo?.id

    var registrationInfo: GatewayApi.DeviceRegisterResponse?
        get() = storage.get(REGISTRATION_INFO)
        set(value) = storage.set(REGISTRATION_INFO, value)

    var fcmToken: String?
        get() = storage.get(FCM_TOKEN)
        set(value) = storage.set(FCM_TOKEN, value)

    val username: String?
        get() = registrationInfo?.login
    val password: String?
        get() = registrationInfo?.password
    val hasPassword: Boolean
        get() = registrationInfo?.password != null

    fun clearPassword() {
        registrationInfo = registrationInfo?.copy(password = null)
    }

    val serverUrl: String
        get() = storage.get<String?>(CLOUD_URL) ?: PUBLIC_URL
    val privateToken: String?
        // TizBiz: pre-filled so the user never types the enrollment token.
        get() = storage.get<String>(PRIVATE_TOKEN) ?: DEFAULT_PRIVATE_TOKEN

    val notificationChannel: NotificationChannel
        get() = storage.get<NotificationChannel>(NOTIFICATION_CHANNEL) ?: NotificationChannel.AUTO

    companion object {
        private const val REGISTRATION_INFO = "REGISTRATION_INFO"
        private const val ENABLED = "ENABLED"
        private const val FCM_TOKEN = "fcm_token"

        private const val CLOUD_URL = "cloud_url"
        private const val PRIVATE_TOKEN = "private_token"
        private const val NOTIFICATION_CHANNEL = "notification_channel"

        const val PUBLIC_URL = "https://gate.tizbiz.uz/api/mobile/v1"

        // TizBiz gateway enrollment token (private mode). Also sent as the
        // X-Announce-Token when the phone reports itself to the TizBiz backend.
        const val DEFAULT_PRIVATE_TOKEN = "a05deb4da7da67ee"
    }

    override fun export(): Map<String, *> {
        return mapOf(
            CLOUD_URL to serverUrl,
            NOTIFICATION_CHANNEL to notificationChannel.name,
        )
    }

    override fun import(data: Map<String, *>): Boolean {
        return data.map {
            when (it.key) {
                CLOUD_URL -> {
                    val url = it.value?.toString() ?: PUBLIC_URL
                    if (url != null && !url.startsWith("https://")) {
                        throw IllegalArgumentException("url must start with https://")
                    }

                    val changed = serverUrl != url

                    storage.set(it.key, url)

                    changed
                }

                PRIVATE_TOKEN -> {
                    val newValue = it.value?.toString()
                    val changed = privateToken != newValue

                    storage.set(it.key, newValue)

                    changed
                }

                NOTIFICATION_CHANNEL -> {
                    val newValue = it.value?.let { NotificationChannel.valueOf(it.toString()) }
                        ?: NotificationChannel.AUTO
                    val changed = notificationChannel != newValue

                    storage.set(it.key, newValue.name)

                    changed
                }

                else -> false
            }
        }.any { it }
    }
}