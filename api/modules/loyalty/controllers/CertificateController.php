<?php

namespace api\modules\loyalty\controllers;

use common\models\Certificate;
use common\rest\Controller;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * CRUD for gift certificates. Reads are open to any authed tenant user; writes
 * require owner/admin. All rows are tenant-scoped automatically via the active
 * business JWT.
 */
class CertificateController extends Controller
{
    /** GET /v1/certificates — newest first. */
    public function actionIndex(): array
    {
        return Certificate::find()
            ->orderBy(['id' => SORT_DESC])
            ->all();
    }

    /** GET /v1/certificates/<id> */
    public function actionView(int $id): Certificate
    {
        return $this->findCertificate($id);
    }

    /** POST /v1/certificates */
    public function actionCreate()
    {
        $this->requireRole('business_owner', 'business_admin');

        $cert = new Certificate();
        $cert->business_id = Yii::$app->tenant->require();
        $cert->load($this->body(), '');

        // Default the balance to the full nominal when not supplied.
        if ($this->body('balance_tiyin') === null) {
            $cert->balance_tiyin = (int) $cert->value_tiyin;
        }

        if (!$cert->save()) {
            return $this->fail422($cert);
        }
        return $this->created($cert);
    }

    /** PATCH /v1/certificates/<id> */
    public function actionUpdate(int $id)
    {
        $this->requireRole('business_owner', 'business_admin');

        $cert = $this->findCertificate($id);
        $cert->load($this->body(), '');
        // business_id is tenant-owned; never accept it from the body.
        $cert->business_id = Yii::$app->tenant->require();
        if (!$cert->save()) {
            return $this->fail422($cert);
        }
        return $cert;
    }

    /** DELETE /v1/certificates/<id> */
    public function actionDelete(int $id): void
    {
        $this->requireRole('business_owner', 'business_admin');

        $cert = $this->findCertificate($id);
        $cert->delete();
        Yii::$app->response->statusCode = 204;
    }

    /** Load a certificate scoped to the active business (auto tenant filter) or 404. */
    private function findCertificate(int $id): Certificate
    {
        Yii::$app->tenant->require();

        $cert = Certificate::findOne(['id' => $id]);
        if ($cert === null) {
            throw new NotFoundHttpException('Sertifikat topilmadi.');
        }
        return $cert;
    }
}
