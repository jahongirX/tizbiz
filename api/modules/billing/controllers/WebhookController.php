<?php

namespace api\modules\billing\controllers;

use api\modules\billing\services\ClickGateway;
use api\modules\billing\services\PaymeGateway;
use common\rest\Controller;
use Yii;
use yii\web\Response;

/**
 * PSP webhook receivers. Called server-to-server by Payme / Click, so both
 * actions are public (no Bearer JWT); each protocol carries its own auth.
 *
 * Responses are emitted as raw JSON (not wrapped in the platform envelope) so
 * the PSP receives the exact protocol shape it expects.
 */
class WebhookController extends Controller
{
    protected function authOptional(): array
    {
        return ['payme', 'click'];
    }

    /** Payme Merchant JSON-RPC endpoint. */
    public function actionPayme()
    {
        $gateway = new PaymeGateway();
        $request = Yii::$app->request->getBodyParams();
        $rpcId = $request['id'] ?? null;

        $authHeader = Yii::$app->request->headers->get('Authorization');
        if (!$gateway->verifyAuth($authHeader)) {
            return $this->rawJson([
                'error' => [
                    'code' => PaymeGateway::ERR_AUTH,
                    'message' => 'Merchant avtorizatsiyasi noto\'g\'ri.',
                ],
                'id' => $rpcId,
            ]);
        }

        $method = (string) ($request['method'] ?? '');
        $params = $request['params'] ?? [];
        if (!is_array($params)) {
            $params = [];
        }

        $response = $gateway->handle($method, $params);
        $response['id'] = $rpcId;

        return $this->rawJson($response);
    }

    /** Click Prepare/Complete endpoint. */
    public function actionClick()
    {
        $gateway = new ClickGateway();
        $request = Yii::$app->request->getBodyParams();

        return $this->rawJson($gateway->handle($request));
    }

    /**
     * Emit an array as raw JSON, bypassing the platform response envelope
     * (which would otherwise wrap it in {"data": ...}).
     */
    private function rawJson(array $payload): string
    {
        $response = Yii::$app->response;
        $response->format = Response::FORMAT_RAW;
        $response->headers->set('Content-Type', 'application/json; charset=UTF-8');
        return json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }
}
