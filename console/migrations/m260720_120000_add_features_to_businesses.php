<?php

use common\db\Migration;

/**
 * Refactor stage 7: per-business feature flags stored as JSON. Additive +
 * nullable, NO backfill needed — a null/absent key falls back to the caller's
 * default (see Business::hasFeature), so every existing business keeps its
 * current behaviour until a flag is explicitly set (golden rule 5).
 */
class m260720_120000_add_features_to_businesses extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%businesses}}', 'features', $this->text()->null());
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%businesses}}', 'features');
    }
}
