<?php

use yii\db\Migration;

/**
 * Rental / wedding-hall engine: an appointment is a whole-day hall booking whose
 * price scales with the guest count (10 guests ≈ 1 table). Store that count so
 * the admin timetable and reports can show "500 mehmon · 50 stol".
 */
class m260917_120000_add_guests_to_appointments extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%appointments}}', 'guests', $this->integer()->null()->after('service_id'));
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%appointments}}', 'guests');
    }
}
