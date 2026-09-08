<?php

namespace api\modules\sms\controllers;

use common\models\SmsContact;
use Yii;
use yii\web\NotFoundHttpException;

/**
 * Saved recipients (name + phone) for the account. CRUD + search by name/phone.
 */
class ContactController extends BaseController
{
    public function actionIndex(): array
    {
        $q = SmsContact::find()->where(['user_id' => $this->uid()]);

        if (($term = trim((string) Yii::$app->request->get('q', ''))) !== '') {
            $q->andWhere(['or', ['like', 'name', $term], ['like', 'phone', $term]]);
        }

        if (($cat = trim((string) Yii::$app->request->get('category', ''))) !== '') {
            $q->andWhere(['category' => $cat]);
        }

        return $q->orderBy(['name' => SORT_ASC])->all();
    }

    /** Distinct non-empty category labels for the account (for filters/datalist). */
    public function actionCategories(): array
    {
        return SmsContact::find()
            ->select('category')
            ->distinct()
            ->where(['user_id' => $this->uid()])
            ->andWhere(['not', ['category' => null]])
            ->andWhere(['<>', 'category', ''])
            ->orderBy(['category' => SORT_ASC])
            ->column();
    }

    public function actionCreate()
    {
        $model = new SmsContact();
        $model->user_id = $this->uid();
        $this->assign($model);
        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $this->created($model);
    }

    public function actionUpdate(int $id)
    {
        $model = $this->find($id);
        $this->assign($model);
        if (!$model->save()) {
            return $this->fail422($model);
        }
        return $model;
    }

    public function actionDelete(int $id): array
    {
        $this->find($id)->delete();
        return ['deleted' => true];
    }

    /**
     * Bulk import: body { contacts: [ {name?, phone, note?}, ... ] }.
     * Existing phones (per account) are skipped, not duplicated.
     */
    public function actionImport(): array
    {
        $rows = $this->body('contacts');
        if (!is_array($rows)) {
            return ['imported' => 0, 'skipped' => 0, 'errors' => ['contacts massiv bo\'lishi kerak']];
        }

        $existing = SmsContact::find()
            ->select('phone')
            ->where(['user_id' => $this->uid()])
            ->column();
        $existing = array_flip($existing);

        $imported = 0;
        $skipped = 0;
        $errors = [];
        foreach ($rows as $row) {
            if (!is_array($row)) {
                $skipped++;
                continue;
            }
            $phone = trim((string) ($row['phone'] ?? ''));
            if ($phone === '' || isset($existing[$phone])) {
                $skipped++;
                continue;
            }
            $name = trim((string) ($row['name'] ?? ''));
            $note = trim((string) ($row['note'] ?? ''));
            $category = trim((string) ($row['category'] ?? ''));

            $model = new SmsContact();
            $model->user_id = $this->uid();
            $model->name = mb_substr($name !== '' ? $name : $phone, 0, 120);
            $model->phone = mb_substr($phone, 0, 32);
            $model->note = $note !== '' ? mb_substr($note, 0, 255) : null;
            $model->category = $category !== '' ? mb_substr($category, 0, 60) : null;

            if ($model->save()) {
                $existing[$phone] = true;
                $imported++;
            } else {
                $skipped++;
                $errors[] = $phone . ': ' . implode(', ', $model->getFirstErrors());
            }
        }

        return ['imported' => $imported, 'skipped' => $skipped, 'errors' => $errors];
    }

    private function assign(SmsContact $model): void
    {
        if (($v = $this->body('name')) !== null) {
            $model->name = trim((string) $v);
        }
        if (($v = $this->body('phone')) !== null) {
            $model->phone = trim((string) $v);
        }
        if (array_key_exists('note', $this->body())) {
            $v = $this->body('note');
            $model->note = ($v === null || trim((string) $v) === '') ? null : trim((string) $v);
        }
        if (array_key_exists('category', $this->body())) {
            $v = $this->body('category');
            $model->category = ($v === null || trim((string) $v) === '') ? null : trim((string) $v);
        }
    }

    private function find(int $id): SmsContact
    {
        $model = SmsContact::findOne(['id' => $id, 'user_id' => $this->uid()]);
        if ($model === null) {
            throw new NotFoundHttpException('Kontakt topilmadi.');
        }
        return $model;
    }
}
