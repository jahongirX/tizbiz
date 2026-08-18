<?php

namespace api\modules\superadmin\controllers;

use common\rest\Controller;
use yii\web\ForbiddenHttpException;

/**
 * Base for superadmin controllers: authenticated AND is_superadmin, otherwise
 * 403. (parent::beforeAction runs the Bearer authenticator first.)
 */
abstract class BaseController extends Controller
{
    public function beforeAction($action): bool
    {
        if (!parent::beforeAction($action)) {
            return false;
        }
        $user = $this->currentUser();
        if ($user === null || !$user->is_superadmin) {
            throw new ForbiddenHttpException('Faqat superadmin uchun.');
        }
        return true;
    }
}
