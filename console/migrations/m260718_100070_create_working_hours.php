<?php

use common\db\Migration;

/**
 * Weekly availability template per staff member.
 * weekday: ISO-8601, 1 = Monday … 7 = Sunday. Times are local (business tz).
 */
class m260718_100070_create_working_hours extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%working_hours}}', [
            'id' => $this->bigPrimaryKey(),
            'staff_id' => $this->bigInteger()->notNull(),
            'weekday' => $this->tinyInteger()->notNull(),
            'start_time' => $this->time()->notNull(),
            'end_time' => $this->time()->notNull(),
        ], $opts);

        $this->createIndex('idx-working_hours-staff', '{{%working_hours}}', ['staff_id', 'weekday']);
        $this->addForeignKey('fk-working_hours-staff', '{{%working_hours}}', 'staff_id', '{{%staff}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%working_hours}}');
    }
}
