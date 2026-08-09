<?php

use common\db\Migration;

/**
 * Refactor stage 4: add the pluggable `engine` (business vertical) to businesses.
 * Additive + nullable, then backfilled — existing rows become the current
 * behaviour ('slot' = online booking). Never NOT NULL directly (golden rule 4).
 */
class m260720_110000_add_engine_to_businesses extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%businesses}}', 'engine', $this->string(24)->null());
        // Backfill: everything currently built is the slot (booking) engine.
        $this->update('{{%businesses}}', ['engine' => 'slot'], ['engine' => null]);
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%businesses}}', 'engine');
    }
}
