<?php

use common\db\Migration;

/**
 * Onboarding wizard fields: how many staff / branches the business has. Both
 * nullable (additive) — collected during the multi-step registration to tailor
 * the vertical and tariff, but never required for existing rows.
 */
class m260721_090000_add_onboarding_fields_to_businesses extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%businesses}}', 'staff_count', $this->integer()->null());
        $this->addColumn('{{%businesses}}', 'branches_count', $this->integer()->null());
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%businesses}}', 'branches_count');
        $this->dropColumn('{{%businesses}}', 'staff_count');
    }
}
