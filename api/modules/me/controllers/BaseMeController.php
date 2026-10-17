<?php

namespace api\modules\me\controllers;

use common\models\Business;
use common\models\Staff;
use common\rest\Controller;
use DateTimeImmutable;
use DateTimeZone;
use Yii;
use yii\web\BadRequestHttpException;
use yii\web\NotFoundHttpException;
use yii\web\UnauthorizedHttpException;

/**
 * Base for /v1/me/* (staff-self): a business token with an active tenant whose
 * user is linked to an active staff row of that tenant. Any role qualifies as
 * long as the link exists. Local dates use the business timezone.
 */
abstract class BaseMeController extends Controller
{
    protected const UTC_FORMAT = 'Y-m-d H:i:s';
    protected const DATE_FORMAT = 'Y-m-d';
    protected const DEFAULT_TZ = 'Asia/Tashkent';

    private ?Staff $staffRow = null;
    private ?Business $businessRow = null;
    private ?DateTimeZone $tzCache = null;

    /** The caller's own active staff row in the active tenant (404 if not linked). */
    protected function staff(): Staff
    {
        if ($this->staffRow !== null) {
            return $this->staffRow;
        }
        Yii::$app->tenant->require();
        $user = $this->currentUser();
        if ($user === null) {
            throw new UnauthorizedHttpException();
        }
        // Tenant-scoped by Staff::find().
        $staff = Staff::find()
            ->andWhere(['user_id' => $user->getId(), 'is_active' => 1])
            ->orderBy(['id' => SORT_ASC])
            ->one();
        if ($staff === null) {
            throw new NotFoundHttpException('Hisobingiz xodim profiliga bog\'lanmagan.');
        }
        return $this->staffRow = $staff;
    }

    /** The active business. */
    protected function business(): Business
    {
        if ($this->businessRow !== null) {
            return $this->businessRow;
        }
        $business = Business::findOne(['id' => Yii::$app->tenant->require()]);
        if ($business === null) {
            throw new NotFoundHttpException('Biznes topilmadi.');
        }
        return $this->businessRow = $business;
    }

    /** Business timezone (fallback Asia/Tashkent). */
    protected function tz(): DateTimeZone
    {
        if ($this->tzCache !== null) {
            return $this->tzCache;
        }
        $name = (string) ($this->business()->timezone ?: self::DEFAULT_TZ);
        try {
            $tz = new DateTimeZone($name);
        } catch (\Throwable $e) {
            $tz = new DateTimeZone(self::DEFAULT_TZ);
        }
        return $this->tzCache = $tz;
    }

    /** Today in the business timezone, 'Y-m-d'. */
    protected function todayLocal(): string
    {
        return (new DateTimeImmutable('now', $this->tz()))->format(self::DATE_FORMAT);
    }

    /**
     * Parse a business-local 'YYYY-MM-DD' query param; missing/empty => $default.
     * Malformed => 400.
     */
    protected function localDateParam(string $name, string $default): string
    {
        $raw = Yii::$app->request->get($name);
        if ($raw === null || $raw === '') {
            return $default;
        }
        if (!is_string($raw) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $raw)) {
            throw new BadRequestHttpException('Yaroqli sana (YYYY-MM-DD) talab qilinadi.');
        }
        $d = DateTimeImmutable::createFromFormat('!' . self::DATE_FORMAT, $raw, $this->tz());
        if ($d === false || $d->format(self::DATE_FORMAT) !== $raw) {
            throw new BadRequestHttpException('Yaroqli sana (YYYY-MM-DD) talab qilinadi.');
        }
        return $raw;
    }

    /**
     * Read and validate the [from, to] local date range (inclusive).
     *
     * @return array{0:string,1:string}
     */
    protected function localRange(string $defaultFrom, string $defaultTo, int $maxDays): array
    {
        $from = $this->localDateParam('from', $defaultFrom);
        $to = $this->localDateParam('to', $defaultTo);
        if ($from > $to) {
            throw new BadRequestHttpException('Sana oralig\'i noto\'g\'ri: from to dan katta.');
        }
        $days = $this->daysBetween($from, $to) + 1;
        if ($days > $maxDays) {
            throw new BadRequestHttpException("Sana oralig'i {$maxDays} kundan oshmasligi kerak.");
        }
        return [$from, $to];
    }

    /**
     * UTC 'Y-m-d H:i:s' bounds of [from 00:00:00 local, to 23:59:59 local].
     *
     * @return array{0:string,1:string}
     */
    protected function utcBounds(string $fromLocal, string $toLocal): array
    {
        $utc = new DateTimeZone('UTC');
        $start = new DateTimeImmutable($fromLocal . ' 00:00:00', $this->tz());
        $end = new DateTimeImmutable($toLocal . ' 23:59:59', $this->tz());
        return [
            $start->setTimezone($utc)->format(self::UTC_FORMAT),
            $end->setTimezone($utc)->format(self::UTC_FORMAT),
        ];
    }

    /** Business-local 'Y-m-d' of a UTC 'Y-m-d H:i:s' string. */
    protected function localDateOf(string $utcDateTime): string
    {
        return (new DateTimeImmutable($utcDateTime, new DateTimeZone('UTC')))
            ->setTimezone($this->tz())
            ->format(self::DATE_FORMAT);
    }

    /** Whole days from $a to $b ('Y-m-d'). */
    protected function daysBetween(string $a, string $b): int
    {
        $utc = new DateTimeZone('UTC');
        $da = new DateTimeImmutable($a, $utc);
        $db = new DateTimeImmutable($b, $utc);
        return (int) $da->diff($db)->format('%r%a');
    }

    /** $date ('Y-m-d') shifted by $days. */
    protected function addDays(string $date, int $days): string
    {
        return (new DateTimeImmutable($date, new DateTimeZone('UTC')))
            ->modify(($days >= 0 ? '+' : '') . $days . ' days')
            ->format(self::DATE_FORMAT);
    }
}
