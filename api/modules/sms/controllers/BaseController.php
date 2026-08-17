<?php

namespace api\modules\sms\controllers;

use common\rest\Controller;

/**
 * Base for SMS dashboard controllers: everything is scoped to the authenticated
 * account (user_id). All actions require a Bearer token (no public actions).
 */
abstract class BaseController extends Controller
{
    /** Authenticated account id. */
    protected function uid(): int
    {
        $user = $this->currentUser();
        return $user ? (int) $user->id : 0;
    }
}
