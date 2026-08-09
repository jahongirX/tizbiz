<?php

use common\db\Migration;

/**
 * Days off / breaks that override the weekly template. A null start/end means
 * the whole day is blocked.
 */
class m260718_100080_create_time_off extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%time_off}}', [
            'id' => $this->bigPrimaryKey(),
            'staff_id' => $this->bigInteger()->notNull(),
            'date' => $this->date()->notNull(),
            'start_time' => $this->time()->null(),
            'end_time' => $this->time()->null(),
            'reason' => $this->string(160)->null(),
        ], $opts);

        $this->createIndex('idx-time_off-staff-date', '{{%time_off}}', ['staff_id', 'date']);
        $this->addForeignKey('fk-time_off-staff', '{{%time_off}}', 'staff_id', '{{%staff}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%time_off}}');
    }
}
