<?php
/**
 * Shared parameters. Secrets come from the environment.
 */
return [
    'jwt.issuer' => getenv('JWT_ISSUER') ?: 'navbat.uz',
    'jwt.secret' => getenv('JWT_SECRET') ?: 'dev-insecure-secret-change-me',
    'jwt.ttl' => 60 * 60 * 24 * 7, // 7 days, seconds
    'money.currency' => 'UZS', // amounts stored in tiyin (1/100 so'm)
    'timezone.display' => 'Asia/Tashkent',
    'api.base' => getenv('API_BASE') ?: 'http://127.0.0.1:8081', // REST base the SPAs call
    'root.domain' => getenv('ROOT_DOMAIN') ?: 'navbat.uz', // {slug}.{root.domain} for tenants
];
