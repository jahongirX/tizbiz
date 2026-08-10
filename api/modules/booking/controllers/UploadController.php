<?php

namespace api\modules\booking\controllers;

use common\rest\Controller;
use Yii;
use yii\helpers\FileHelper;
use yii\web\BadRequestHttpException;
use yii\web\ServerErrorHttpException;
use yii\web\UploadedFile;

/**
 * Image uploads for the catalog (menu items, categories) and elsewhere. Saves
 * under the API web root (served statically) and returns an absolute URL that
 * is stored on the referencing model.
 */
class UploadController extends Controller
{
    private const ALLOWED = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
    private const MAX_BYTES = 5 * 1024 * 1024; // 5 MB

    /**
     * POST v1/uploads  (multipart, field "file") -> { url }
     */
    public function actionCreate(): array
    {
        $this->requireRole('business_owner', 'business_admin', 'staff');

        $file = UploadedFile::getInstanceByName('file');
        if ($file === null || $file->error !== UPLOAD_ERR_OK) {
            throw new BadRequestHttpException('Fayl yuklanmadi.');
        }
        if ($file->size > self::MAX_BYTES) {
            throw new BadRequestHttpException('Rasm hajmi 5MB dan oshmasin.');
        }
        $ext = strtolower((string) $file->extension);
        if (!in_array($ext, self::ALLOWED, true) || strncmp((string) $file->type, 'image/', 6) !== 0) {
            throw new BadRequestHttpException('Faqat rasm yuklang (jpg, png, webp, gif).');
        }

        $sub = date('Ym');
        $dir = Yii::getAlias('@api/web/uploads/' . $sub);
        try {
            FileHelper::createDirectory($dir, 0775);
        } catch (\Throwable $e) {
            throw new ServerErrorHttpException('Yuklash papkasini yaratib bo\'lmadi.');
        }

        $name = bin2hex(random_bytes(8)) . '.' . $ext;
        if (!$file->saveAs($dir . '/' . $name)) {
            throw new ServerErrorHttpException('Faylni saqlab bo\'lmadi (ruxsatlarni tekshiring).');
        }

        return ['url' => Yii::$app->request->hostInfo . '/uploads/' . $sub . '/' . $name];
    }
}
