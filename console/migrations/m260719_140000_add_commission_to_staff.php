<?php

use common\db\Migration;

/**
 * Per-staff commission percent (0..100), used by payroll: a staff member earns
 * this share of the price of the services they complete.
 */
class m260719_140000_add_commission_to_staff extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%staff}}', 'commission_percent', $this->integer()->notNull()->defaultValue(0));
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%staff}}', 'commission_percent');
    }
}
