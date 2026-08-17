<?php

namespace console\controllers;

use Yii;
use yii\console\Controller;
use yii\console\ExitCode;
use yii\helpers\Console;

/**
 * One-off maintenance tasks.
 *
 * rebase-assets rewrites stored absolute asset URLs from one host to another —
 * needed because seeded demo images bake an absolute base (e.g. api.startup)
 * into the DB, which then shows the wrong host in production.
 */
class MaintenanceController extends Controller
{
    /** Apply changes. Without it the command only reports what it would change. */
    public $apply = false;

    public function options($actionID): array
    {
        return $actionID === 'rebase-assets' ? ['apply'] : [];
    }

    public function optionAliases(): array
    {
        return ['a' => 'apply'];
    }

    /** Columns that may hold an absolute asset URL. */
    private const TARGETS = [
        'businesses' => ['logo', 'cover'],
        'services' => ['image', 'gallery'],
        'service_categories' => ['image'],
    ];

    /**
     * Rewrite the asset host in stored URLs, e.g.
     *   php yii maintenance/rebase-assets api.startup api.tizbiz.uz --apply
     *
     * Matches only the host substring, so the scheme (http/https) is preserved.
     * Without --apply it is a dry run (counts + a sample per column).
     */
    public function actionRebaseAssets(string $from = 'api.startup', string $to = 'api.tizbiz.uz'): int
    {
        if ($from === '' || $to === '' || $from === $to) {
            $this->stderr("Provide distinct <from> and <to> hosts.\n", Console::FG_RED);
            return ExitCode::USAGE;
        }

        $db = Yii::$app->db;
        $like = '%' . $from . '%';
        $total = 0;

        $this->stdout(($this->apply ? 'APPLYING' : 'DRY RUN') . ": '$from' -> '$to'\n\n", Console::BOLD);

        $tx = $this->apply ? $db->beginTransaction() : null;
        try {
            foreach (self::TARGETS as $table => $columns) {
                $tbl = "{{%$table}}";
                foreach ($columns as $col) {
                    $count = (int) $db->createCommand(
                        "SELECT COUNT(*) FROM $tbl WHERE [[$col]] LIKE :like",
                        [':like' => $like]
                    )->queryScalar();

                    if ($count === 0) {
                        continue;
                    }
                    $total += $count;

                    if ($this->apply) {
                        $db->createCommand(
                            "UPDATE $tbl SET [[$col]] = REPLACE([[$col]], :from, :to) WHERE [[$col]] LIKE :like",
                            [':from' => $from, ':to' => $to, ':like' => $like]
                        )->execute();
                        $this->stdout("  ✓ $table.$col  $count row(s) updated\n", Console::FG_GREEN);
                    } else {
                        $sample = (string) $db->createCommand(
                            "SELECT [[$col]] FROM $tbl WHERE [[$col]] LIKE :like LIMIT 1",
                            [':like' => $like]
                        )->queryScalar();
                        $this->stdout("  • $table.$col  $count row(s)\n");
                        $this->stdout("      e.g. " . mb_strimwidth($sample, 0, 90, '…') . "\n", Console::FG_GREY);
                    }
                }
            }
            $tx?->commit();
        } catch (\Throwable $e) {
            $tx?->rollBack();
            $this->stderr("\nFailed: {$e->getMessage()}\n", Console::FG_RED);
            return ExitCode::UNSPECIFIED_ERROR;
        }

        if ($total === 0) {
            $this->stdout("\nNothing to rewrite — no rows contain '$from'.\n", Console::FG_YELLOW);
        } elseif ($this->apply) {
            $this->stdout("\nDone. $total value(s) rewritten to '$to'.\n", Console::FG_GREEN);
        } else {
            $this->stdout("\n$total value(s) would change. Re-run with --apply to write.\n", Console::FG_YELLOW);
        }
        return ExitCode::OK;
    }
}
