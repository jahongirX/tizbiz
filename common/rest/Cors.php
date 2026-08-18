<?php

namespace common\rest;

use Yii;
use yii\base\Event;

/**
 * Handles CORS preflight globally. Verb-scoped REST URL rules don't match the
 * OPTIONS method, so a preflight would 404 before any controller (and its Cors
 * filter) runs. Wired via api/config 'on beforeRequest'. Actual (non-OPTIONS)
 * responses still get their CORS headers from the per-controller Cors filter.
 */
class Cors
{
    public static function preflight(Event $event): void
    {
        $request = Yii::$app->request;
        if (!$request->isOptions) {
            return;
        }

        $response = Yii::$app->response;
        $allowed = getenv('APP_ORIGINS') ?: '*';
        $origin = $request->headers->get('Origin');
        $response->headers->set('Access-Control-Allow-Origin', $allowed === '*' ? ($origin ?: '*') : $allowed);
        $response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
        $response->headers->set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Telegram-Init-Data, X-Api-Key');
        $response->headers->set('Access-Control-Max-Age', '3600');
        $response->statusCode = 204;
        $response->data = null;
        Yii::$app->end();
    }
}
