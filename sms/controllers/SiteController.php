<?php

namespace sms\controllers;

use common\web\SpaController;

/**
 * SMS gateway dashboard → sms.tizbiz.uz. Serves the apps/sms Vue SPA; the SMS
 * REST API lives in api/modules/sms on api.tizbiz.uz.
 */
class SiteController extends SpaController
{
    protected string $appName = 'sms';
}
