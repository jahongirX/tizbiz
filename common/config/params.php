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
];
