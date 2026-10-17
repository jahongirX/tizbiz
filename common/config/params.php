<?php
/**
 * Shared parameters. Secrets come from the environment.
 */
return [
    'jwt.issuer' => getenv('JWT_ISSUER') ?: 'tizbiz.uz',
    'jwt.secret' => getenv('JWT_SECRET') ?: 'dev-insecure-secret-change-me',
    'jwt.ttl' => 60 * 60 * 24 * 7, // 7 days, seconds
    'money.currency' => 'UZS', // amounts stored in tiyin (1/100 so'm)
    'timezone.display' => 'Asia/Tashkent',
    'api.base' => getenv('API_BASE') ?: 'http://127.0.0.1:8081', // REST base the SPAs call
    'root.domain' => getenv('ROOT_DOMAIN') ?: 'tizbiz.uz', // {slug}.{root.domain} for tenants
    // Public storefront URL template. Empty -> SPA builds https://{slug}.{root.domain}.
    // Locally set this to a query-param form, e.g. http://t.startup/?slug={slug}.
    'public.base' => getenv('PUBLIC_BASE') ?: '',
    // SMS gateway: the 3rd-party send base a claimed phone defaults to, and the
    // shared token the TizBiz SMS app presents when it announces itself.
    'sms.gateway.base' => getenv('SMS_GATEWAY_BASE') ?: 'https://gate.tizbiz.uz/api/3rdparty/v1',
    'sms.announce.token' => getenv('SMS_ANNOUNCE_TOKEN') ?: '',
    // Contract-expiry reminders (superadmin/contract-reminders cron): the SMS
    // account used to send and the phone that receives them. Empty = dashboard-only.
    'sms.admin.notify_user_id' => (int) (getenv('SMS_ADMIN_NOTIFY_USER_ID') ?: 0),
    'sms.admin.notify_phone' => getenv('SMS_ADMIN_NOTIFY_PHONE') ?: '',
    // Platform SMS (consumer OTP, reminders): when set, SmsSender sends through
    // this sms.tizbiz.uz account's phone (logged + counted in its dashboard).
    'sms.platform.user_id' => (int) (getenv('SMS_PLATFORM_USER_ID') ?: 0),
    // Bizcat consumer app: phone + OTP login, long-lived consumer JWT (typ=consumer).
    'consumer.jwt.ttl' => 60 * 60 * 24 * 30, // 30 days, no refresh token
    'consumer.otp.ttl' => 120, // seconds a code stays valid
    'consumer.otp.resend_after' => 60, // seconds between sends per phone
    'consumer.otp.max_per_hour_phone' => 5,
    'consumer.otp.max_per_hour_ip' => 20,
    'consumer.otp.max_attempts' => 5,
    // Demo phones log in with a fixed code, no SMS, no rate limit (store review / QA).
    'consumer.otp.demo_phones' => array_values(array_filter(array_map('trim', explode(',',
        getenv('CONSUMER_DEMO_PHONES') ?: '+998900000001,+998900000002,+998900000003')))),
    'consumer.otp.demo_code' => getenv('CONSUMER_DEMO_OTP_CODE') ?: '1111',
    // Reverse proxies (e.g. Cloudflare / nginx CIDRs, comma-separated in
    // TRUSTED_PROXIES) whose client-IP headers the API trusts. Empty = use
    // REMOTE_ADDR as is. Applied to the web request by the consumer module's
    // bootstrap (per-IP OTP limits need the real client IP).
    'request.trustedHosts' => array_values(array_filter(array_map('trim', explode(',', getenv('TRUSTED_PROXIES') ?: '')))),
    'request.ipHeaders' => ['CF-Connecting-IP', 'X-Forwarded-For'],
];
