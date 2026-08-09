<?php

namespace tenant\controllers;

use common\web\SpaController;
use Yii;

/**
 * Per-business branded site served on {slug}.tizbiz.uz (wildcard subdomain).
 * The business slug is taken from the Host header; the SPA/API resolve the rest.
 */
class SiteController extends SpaController
{
    protected string $appName = 'booking';

    protected function getTenantSlug(): ?string
    {
        $host = strtolower((string) Yii::$app->request->hostName);
        $root = strtolower((string) (Yii::$app->params['root.domain'] ?? ''));
        if ($host === '' || $root === '') {
            return null;
        }

        $suffix = '.' . $root;
        if (!str_ends_with($host, $suffix)) {
            return null;
        }

        $slug = substr($host, 0, -strlen($suffix));
        // Reserved subdomains are not tenants.
        if ($slug === '' || in_array($slug, ['www', 'api', 'admin', 'app'], true)) {
            return null;
        }

        return $slug;
    }
}
