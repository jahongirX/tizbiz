<?php

namespace api\modules\consumer\services;

use api\modules\notify\services\SmsSender;
use common\helpers\DbLock;
use common\helpers\Phone;
use common\models\ConsumerOtpCode;
use Yii;
use yii\web\HttpException;
use yii\web\TooManyRequestsHttpException;

/**
 * Consumer OTP: issue (with SMS + rate limits) and verify.
 *
 * Only hash_hmac('sha256', phone|code, jwt.secret) is stored. Every issued non-demo
 * row — failed sends included — counts toward the rate limits (checked under
 * per-IP and per-phone GET_LOCK locks):
 *  - resend: one code per phone per `consumer.otp.resend_after` seconds (429 + Retry-After)
 *  - hourly: `max_per_hour_phone` per phone, `max_per_hour_ip` per IP (429)
 * Demo phones (`consumer.otp.demo_phones`) get the fixed `demo_code`, no SMS and
 * no rate limit; their rows store no IP, so they never count toward an IP's budget.
 */
final class OtpService
{
    public static function ttl(): int
    {
        return (int) (Yii::$app->params['consumer.otp.ttl'] ?? 120);
    }

    public static function resendAfter(): int
    {
        return (int) (Yii::$app->params['consumer.otp.resend_after'] ?? 60);
    }

    /** @return string[] normalized demo phones */
    public static function demoPhones(): array
    {
        $out = [];
        foreach ((array) (Yii::$app->params['consumer.otp.demo_phones'] ?? []) as $demo) {
            $n = Phone::normalize((string) $demo);
            if ($n !== null) {
                $out[] = $n;
            }
        }
        return array_values(array_unique($out));
    }

    public static function isDemoPhone(string $phone): bool
    {
        return in_array($phone, self::demoPhones(), true);
    }

    public static function hash(string $phone, string $code): string
    {
        return hash_hmac('sha256', $phone . '|' . $code, (string) Yii::$app->params['jwt.secret']);
    }

    /** "+998900000001" -> "+99890*****01" (for logs). */
    public static function mask(string $phone): string
    {
        $len = strlen($phone);
        if ($len <= 6) {
            return str_repeat('*', $len);
        }
        return substr($phone, 0, 6) . str_repeat('*', $len - 8) . substr($phone, -2);
    }

    /**
     * Issue a code for a normalized phone.
     *
     * @return array{sent: bool, ttl_sec: int, retry_after_sec: int}
     * @throws TooManyRequestsHttpException|HttpException 429 / 503
     */
    public function issue(string $phone, ?string $ip): array
    {
        $demo = self::isDemoPhone($phone);
        $ip = $ip !== null && $ip !== '' ? mb_substr($ip, 0, 45) : null;

        // Limits are check-then-insert: serialize them per IP and per phone with
        // named DB locks (IP first, then phone: one fixed order, no deadlock), so
        // parallel requests cannot all pass the checks before any row exists.
        $locks = [];
        try {
            if (!$demo) {
                $keys = $ip !== null ? ['otp-ip:' . $ip, 'otp:' . $phone] : ['otp:' . $phone];
                foreach ($keys as $key) {
                    if (!DbLock::acquire($key, 5)) {
                        throw new TooManyRequestsHttpException('Juda ko\'p urinish. Keyinroq urinib ko\'ring.');
                    }
                    $locks[] = $key;
                }
            }
            $now = time();
            if (!$demo) {
                $this->enforceLimits($phone, $ip, $now); // re-check under the locks
            }

            // Any earlier live code for this phone stops working.
            ConsumerOtpCode::updateAll(
                ['consumed_at' => $now],
                ['and', ['phone' => $phone], ['consumed_at' => null]]
            );

            $code = $demo
                ? (string) (Yii::$app->params['consumer.otp.demo_code'] ?? '1111')
                : (string) random_int(100000, 999999);

            $row = new ConsumerOtpCode();
            $row->phone = $phone;
            $row->code_hash = self::hash($phone, $code);
            $row->attempts = 0;
            $row->expires_at = $now + self::ttl();
            // Demo rows are unlimited and must not eat the shared per-IP budget.
            $row->ip = $demo ? null : $ip;
            $row->save(false);
        } finally {
            foreach (array_reverse($locks) as $key) {
                DbLock::release($key);
            }
        }

        // The row already counts toward the limits, so the send runs unlocked.
        if (!$demo) {
            $ok = SmsSender::send($phone, "Bizcat: tasdiqlash kodi {$code}. Uni hech kimga bermang.");
            if (!$ok) {
                Yii::warning('Consumer OTP SMS failed for ' . self::mask($phone), 'consumer');
                $row->consumed_at = time();
                $row->save(false, ['consumed_at']);
                throw new HttpException(503, 'SMS yuborib bo\'lmadi. Keyinroq urinib ko\'ring.');
            }
        }

        return [
            'sent' => true,
            'ttl_sec' => self::ttl(),
            'retry_after_sec' => self::resendAfter(),
        ];
    }

    private function enforceLimits(string $phone, ?string $ip, int $now): void
    {
        $latest = ConsumerOtpCode::find()
            ->select(['created_at'])
            ->where(['phone' => $phone])
            ->orderBy(['created_at' => SORT_DESC, 'id' => SORT_DESC])
            ->scalar();
        if ($latest !== false && $latest !== null) {
            $wait = self::resendAfter() - ($now - (int) $latest);
            if ($wait > 0) {
                Yii::$app->response->headers->set('Retry-After', (string) $wait);
                throw new TooManyRequestsHttpException("Kodni qayta yuborish uchun {$wait} soniya kuting.");
            }
        }

        $since = $now - 3600;
        $perPhone = (int) ConsumerOtpCode::find()
            ->where(['phone' => $phone])
            ->andWhere(['>=', 'created_at', $since])
            ->count();
        $maxPhone = (int) (Yii::$app->params['consumer.otp.max_per_hour_phone'] ?? 5);
        $tooMany = $perPhone >= $maxPhone;

        if (!$tooMany && $ip !== null && $ip !== '') {
            // Demo rows never count (new ones store no IP; this also skips older ones).
            $perIpQuery = ConsumerOtpCode::find()
                ->where(['ip' => $ip])
                ->andWhere(['>=', 'created_at', $since]);
            $demoPhones = self::demoPhones();
            if ($demoPhones !== []) {
                $perIpQuery->andWhere(['not in', 'phone', $demoPhones]);
            }
            $perIp = (int) $perIpQuery->count();
            $maxIp = (int) (Yii::$app->params['consumer.otp.max_per_hour_ip'] ?? 20);
            $tooMany = $perIp >= $maxIp;
        }
        if ($tooMany) {
            throw new TooManyRequestsHttpException('Juda ko\'p urinish. Keyinroq urinib ko\'ring.');
        }
    }

    /**
     * Check a code against the latest live (unconsumed, unexpired) code of the
     * phone. A wrong code counts an attempt; at max_attempts the code is burned.
     *
     * Every step is a conditional UPDATE checked by its affected-row count, so
     * parallel guesses cannot lose attempt increments and one code yields at
     * most one success.
     */
    public function verify(string $phone, string $code): bool
    {
        $now = time();
        $max = max(1, (int) (Yii::$app->params['consumer.otp.max_attempts'] ?? 5));
        $row = ConsumerOtpCode::find()
            ->where(['phone' => $phone, 'consumed_at' => null])
            ->andWhere(['>', 'expires_at', $now])
            ->orderBy(['id' => SORT_DESC])
            ->one();
        if ($row === null) {
            return false;
        }
        $id = (int) $row->id;

        // Reserve one attempt atomically (fails once the code is used, burned or expired).
        $reserved = ConsumerOtpCode::updateAllCounters(['attempts' => 1], ['and',
            ['id' => $id],
            ['consumed_at' => null],
            ['>', 'expires_at', $now],
            ['<', 'attempts', $max],
        ]);
        if ($reserved !== 1) {
            return false;
        }

        if ($code !== '' && hash_equals((string) $row->code_hash, self::hash($phone, $code))) {
            // Single use: only the request that consumes the row wins.
            return ConsumerOtpCode::updateAll(
                ['consumed_at' => $now],
                ['and', ['id' => $id], ['consumed_at' => null]]
            ) === 1;
        }

        // Wrong code: burn it once the attempt budget is spent.
        ConsumerOtpCode::updateAll(
            ['consumed_at' => $now],
            ['and', ['id' => $id], ['consumed_at' => null], ['>=', 'attempts', $max]]
        );
        return false;
    }
}
