<?php

namespace api\modules\booking\services;

use common\models\Appointment;
use common\models\Service;
use common\models\Staff;
use DateInterval;
use DateTimeImmutable;
use DateTimeZone;

/**
 * Computes bookable slots for a staff member on a given day.
 *
 * All timezone math uses DateTimeImmutable + DateTimeZone. Working hours and
 * time-off are stored in the business-local timezone; appointments are stored
 * in UTC and converted to local for subtraction. Emitted slot times are given
 * both in UTC (for booking) and local (for display).
 */
class AvailabilityService
{
    private const UTC_FORMAT = 'Y-m-d H:i:s';

    /**
     * @param int[] $extraServiceIds services booked in the same visit (soch +
     *                               soqol): the slot must fit their sum.
     * @return array{date:string, timezone:string, slots:array<int, array{start_utc:string, end_utc:string, start_local:string}>}
     */
    public function slots(Staff $staff, string $date, int $serviceId, array $extraServiceIds = []): array
    {
        $tzName = $this->resolveTimezone($staff);
        $tz = new DateTimeZone($tzName);
        $utc = new DateTimeZone('UTC');

        $empty = ['date' => $date, 'timezone' => $tzName, 'slots' => []];

        // The service must belong to the same business as the staff and be active.
        $service = Service::find()
            ->andWhere(['id' => $serviceId, 'business_id' => $staff->business_id])
            ->one();
        if ($service === null || (int) $service->duration_min <= 0) {
            return $empty;
        }
        $duration = (int) $service->duration_min + $this->extraDuration($staff, $extraServiceIds);

        if (!$staff->is_active) {
            return $empty;
        }

        // Validate the date and derive its ISO weekday (1=Mon..7=Sun).
        $dayStart = DateTimeImmutable::createFromFormat('!Y-m-d', $date, $tz);
        if ($dayStart === false) {
            return $empty;
        }
        $weekday = (int) $dayStart->format('N');

        // Booking window from the business: don't offer slots that start sooner
        // than now + lead time, nor on a date beyond today + horizon days.
        $business = $staff->business;
        $leadMin = $business !== null ? max(0, (int) $business->booking_lead_min) : 0;
        $horizonDays = $business !== null ? max(0, (int) $business->booking_horizon_days) : 0;
        $minStart = (new DateTimeImmutable('now', $utc))->add(new DateInterval('PT' . $leadMin . 'M'));
        $todayLocal = (new DateTimeImmutable('now', $tz))->setTime(0, 0, 0);
        $maxDay = $todayLocal->add(new DateInterval('P' . $horizonDays . 'D'));
        if ($dayStart->getTimestamp() > $maxDay->getTimestamp()) {
            return $empty;
        }

        // Base free intervals from the weekly template, as [startMin, endMin] in
        // minutes-from-midnight (local).
        $intervals = [];
        foreach ($staff->getWorkingHours()->andWhere(['weekday' => $weekday])->all() as $wh) {
            $start = $this->timeToMinutes($wh->start_time);
            $end = $this->timeToMinutes($wh->end_time);
            if ($start !== null && $end !== null && $end > $start) {
                $intervals[] = [$start, $end];
            }
        }
        if ($intervals === []) {
            return $empty;
        }

        // Subtract time-off for that date.
        $blocks = [];
        foreach ($staff->getTimeOff()->andWhere(['date' => $date])->all() as $off) {
            $start = $this->timeToMinutes($off->start_time);
            $end = $this->timeToMinutes($off->end_time);
            if ($start === null || $end === null) {
                // Whole day blocked.
                return $empty;
            }
            if ($end > $start) {
                $blocks[] = [$start, $end];
            }
        }

        // Subtract existing (non-released) appointments for this staff on this day.
        $dayEnd = $dayStart->modify('+1 day');
        $dayStartUtc = $dayStart->setTimezone($utc)->format(self::UTC_FORMAT);
        $dayEndUtc = $dayEnd->setTimezone($utc)->format(self::UTC_FORMAT);

        $appts = Appointment::find()
            ->andWhere(['staff_id' => $staff->id])
            ->andWhere(['not in', 'status', Appointment::RELEASED_STATUSES])
            ->andWhere(['<', 'starts_at', $dayEndUtc])
            ->andWhere(['>', 'ends_at', $dayStartUtc])
            ->all();

        foreach ($appts as $appt) {
            $s = $this->utcToLocalMinutes($appt->starts_at, $utc, $tz, $dayStart);
            $e = $this->utcToLocalMinutes($appt->ends_at, $utc, $tz, $dayStart);
            if ($s === null || $e === null) {
                continue;
            }
            // Clamp to the day window [0, 1440].
            $s = max(0, $s);
            $e = min(1440, $e);
            if ($e > $s) {
                $blocks[] = [$s, $e];
            }
        }

        $free = $this->subtract($intervals, $blocks);

        // Walk each free interval in steps of $duration.
        $slots = [];
        foreach ($free as [$start, $end]) {
            for ($t = $start; $t + $duration <= $end; $t += $duration) {
                $slotStart = $dayStart->add(new DateInterval('PT' . $t . 'M'));
                // Skip slots that start before the lead-time cutoff.
                if ($slotStart < $minStart) {
                    continue;
                }
                $slotEnd = $slotStart->add(new DateInterval('PT' . $duration . 'M'));
                $slots[] = [
                    'start_utc' => $slotStart->setTimezone($utc)->format(self::UTC_FORMAT),
                    'end_utc' => $slotEnd->setTimezone($utc)->format(self::UTC_FORMAT),
                    'start_local' => $slotStart->format('H:i'),
                ];
            }
        }

        return ['date' => $date, 'timezone' => $tzName, 'slots' => $slots];
    }

    /** Summed duration of the additional services, own-business only. */
    private function extraDuration(Staff $staff, array $extraServiceIds): int
    {
        $ids = array_values(array_unique(array_filter(array_map('intval', $extraServiceIds))));
        if ($ids === []) {
            return 0;
        }
        $rows = Service::find()
            ->andWhere(['id' => $ids, 'business_id' => $staff->business_id])
            ->all();

        $total = 0;
        foreach ($rows as $row) {
            $total += max(0, (int) $row->duration_min);
        }
        return $total;
    }

    private function resolveTimezone(Staff $staff): string
    {
        $business = $staff->business;
        $tz = $business !== null ? (string) $business->timezone : '';
        if ($tz === '') {
            return 'Asia/Tashkent';
        }
        // Guard against a bad stored value.
        try {
            new DateTimeZone($tz);
        } catch (\Throwable $e) {
            return 'Asia/Tashkent';
        }
        return $tz;
    }

    /** 'HH:MM[:SS]' -> minutes from midnight, or null. */
    private function timeToMinutes(?string $time): ?int
    {
        if ($time === null || $time === '') {
            return null;
        }
        $parts = explode(':', $time);
        if (count($parts) < 2) {
            return null;
        }
        $h = (int) $parts[0];
        $m = (int) $parts[1];
        return $h * 60 + $m;
    }

    /** UTC 'Y-m-d H:i:s' -> local minutes-from-midnight relative to $localDayStart. */
    private function utcToLocalMinutes(string $utcStr, DateTimeZone $utc, DateTimeZone $tz, DateTimeImmutable $localDayStart): ?int
    {
        $dt = DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $utcStr, $utc);
        if ($dt === false) {
            return null;
        }
        $local = $dt->setTimezone($tz);
        $diff = $local->getTimestamp() - $localDayStart->getTimestamp();
        return (int) round($diff / 60);
    }

    /**
     * Subtract a set of blocked intervals from base intervals.
     * @param array<int, array{0:int,1:int}> $base
     * @param array<int, array{0:int,1:int}> $blocks
     * @return array<int, array{0:int,1:int}>
     */
    private function subtract(array $base, array $blocks): array
    {
        $result = [];
        foreach ($base as [$bs, $be]) {
            $segments = [[$bs, $be]];
            foreach ($blocks as [$ks, $ke]) {
                $next = [];
                foreach ($segments as [$ss, $se]) {
                    if ($ke <= $ss || $ks >= $se) {
                        // No overlap.
                        $next[] = [$ss, $se];
                        continue;
                    }
                    if ($ks > $ss) {
                        $next[] = [$ss, min($ks, $se)];
                    }
                    if ($ke < $se) {
                        $next[] = [max($ke, $ss), $se];
                    }
                }
                $segments = $next;
            }
            foreach ($segments as $seg) {
                if ($seg[1] > $seg[0]) {
                    $result[] = $seg;
                }
            }
        }
        usort($result, static fn ($a, $b) => $a[0] <=> $b[0]);
        return $result;
    }
}
