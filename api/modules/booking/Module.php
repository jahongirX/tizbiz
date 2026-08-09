<?php

namespace api\modules\booking;

use yii\base\BootstrapInterface;
use yii\rest\UrlRule;

/**
 * Booking module: staff, services, schedule, availability, appointments.
 */
class Module extends \yii\base\Module implements BootstrapInterface
{
    public $controllerNamespace = 'api\modules\booking\controllers';

    public function bootstrap($app): void
    {
        $app->getUrlManager()->addRules([
            [
                'class' => UrlRule::class,
                'controller' => ['v1/staff' => 'booking/staff'],
                'pluralize' => false,
            ],
            [
                'class' => UrlRule::class,
                'controller' => ['v1/service-categories' => 'booking/service-category'],
                'pluralize' => false,
            ],
            [
                'class' => UrlRule::class,
                'controller' => ['v1/services' => 'booking/service'],
                'pluralize' => false,
            ],

            // Online-booking settings for the active business.
            'GET v1/settings/booking' => 'booking/settings/view',
            'PUT v1/settings/booking' => 'booking/settings/update',

            // Staff availability (public).
            'GET v1/staff/<id:\d+>/availability' => 'booking/availability/index',

            // Staff schedule: weekly working hours.
            'GET v1/staff/<id:\d+>/working-hours' => 'booking/schedule/working-hours',
            'PUT v1/staff/<id:\d+>/working-hours' => 'booking/schedule/update-working-hours',

            // Staff schedule: time off.
            'GET v1/staff/<id:\d+>/time-off' => 'booking/schedule/time-off',
            'POST v1/staff/<id:\d+>/time-off' => 'booking/schedule/create-time-off',
            'DELETE v1/staff/<staffId:\d+>/time-off/<id:\d+>' => 'booking/schedule/delete-time-off',

            // Appointments.
            'GET v1/appointments' => 'booking/appointment/index',
            'POST v1/appointments' => 'booking/appointment/create',
            'PATCH v1/appointments/<id:\d+>' => 'booking/appointment/update',
            'GET v1/appointments/<id:\d+>' => 'booking/appointment/view',
        ], false);
    }
}
