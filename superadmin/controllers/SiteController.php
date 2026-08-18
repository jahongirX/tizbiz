<?php

namespace superadmin\controllers;

use common\web\SpaController;

/**
 * Platform superadmin panel → superadmin.tizbiz.uz. Serves the apps/superadmin
 * Vue SPA; the REST API lives in api/modules/superadmin on api.tizbiz.uz.
 */
class SiteController extends SpaController
{
    protected string $appName = 'superadmin';
}
