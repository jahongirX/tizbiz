<?php

namespace common\web;

use Yii;
use yii\helpers\Json;
use yii\web\Controller;
use yii\web\Response;

/**
 * Serves a single-page app. Every non-file request in a web tier
 * (frontend/backend/tenant) lands here so client-side routing works and the
 * server can inject bootstrap data (api base, active tenant) into the page.
 *
 * If the Vue app has been built into this tier's web/app/ (Vite base '/app/'),
 * that index.html is served with the bootstrap script injected; otherwise a
 * placeholder shell is shown.
 */
class SpaController extends Controller
{
    public $enableCsrfValidation = false;

    /** Which Vue app this tier hosts (corporate/admin/booking). */
    protected string $appName = 'app';

    public function actionIndex(): string
    {
        Yii::$app->response->format = Response::FORMAT_HTML;

        $boot = '<script>window.__TIZBIZ__=' . Json::htmlEncode([
            'app' => $this->appName,
            'apiBase' => (string) (Yii::$app->params['api.base'] ?? ''),
            'tenantSlug' => $this->getTenantSlug(),
        ]) . ';</script>';

        $built = Yii::$app->basePath . '/web/app/index.html';
        if (is_file($built)) {
            $html = file_get_contents($built);
            // Inject bootstrap just before the app's own scripts run.
            return str_replace('</head>', $boot . '</head>', $html);
        }

        return $this->renderFile('@common/web/spa-shell.php', [
            'appName' => $this->appName,
            'apiBase' => (string) (Yii::$app->params['api.base'] ?? ''),
            'tenantSlug' => $this->getTenantSlug(),
            'boot' => $boot,
        ]);
    }

    /** Overridden by the tenant tier to resolve the business from the subdomain. */
    protected function getTenantSlug(): ?string
    {
        return null;
    }
}
