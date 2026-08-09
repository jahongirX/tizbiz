<?php

namespace common\rest;

use yii\base\Event;
use yii\web\Response;

/**
 * Wraps every JSON response in the platform envelope:
 *   success -> { "data": <payload>, "meta"?: {...} }
 *   error   -> { "errors": [ { "status", "title", "detail", "code"?, "source"? } ] }  (RFC-7807 flavored)
 *
 * A controller may return an already-enveloped array (containing `data` or
 * `errors`) to pass through, e.g. to attach `meta` pagination.
 * Wired via api/config response component: 'on beforeSend'.
 */
class Envelope
{
    public static function onBeforeSend(Event $event): void
    {
        /** @var Response $response */
        $response = $event->sender;
        if ($response->format !== Response::FORMAT_JSON) {
            return;
        }
        $data = $response->data;
        if ($data === null) {
            return;
        }

        if ($response->isSuccessful) {
            if (is_array($data) && (array_key_exists('data', $data) || array_key_exists('errors', $data))) {
                return; // already enveloped
            }
            $response->data = ['data' => $data];
            return;
        }

        // Validation failures (422): Yii returns a list of {field, message}.
        if ($response->statusCode === 422 && is_array($data) && isset($data[0]['field'])) {
            $errors = [];
            foreach ($data as $item) {
                $errors[] = [
                    'status' => '422',
                    'title' => 'Validation error',
                    'detail' => $item['message'] ?? '',
                    'source' => ['pointer' => $item['field'] ?? ''],
                ];
            }
            $response->data = ['errors' => $errors];
            return;
        }

        $error = [
            'status' => (string) ($data['status'] ?? $response->statusCode),
            'title' => $data['name'] ?? 'Error',
            'detail' => $data['message'] ?? '',
        ];
        if (!empty($data['code'])) {
            $error['code'] = (string) $data['code'];
        }
        $response->data = ['errors' => [$error]];
    }
}
