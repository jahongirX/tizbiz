<?php

use common\db\Migration;

/**
 * Bookings. Times stored as UTC DATETIME, shown in the business timezone.
 * status: pending/confirmed/arrived/completed/no_show/canceled
 * source: admin/link/telegram
 */
class m260718_100100_create_appointments extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%appointments}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'client_id' => $this->bigInteger()->null(),
            'staff_id' => $this->bigInteger()->notNull(),
            'service_id' => $this->bigInteger()->notNull(),
            'starts_at' => $this->dateTime()->notNull(),
            'ends_at' => $this->dateTime()->notNull(),
            'status' => $this->string(16)->notNull()->defaultValue('pending'),
            'source' => $this->string(16)->notNull()->defaultValue('admin'),
            'deposit_tiyin' => $this->bigInteger()->null(),
            'paid' => $this->boolean()->notNull()->defaultValue(false),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('idx-appointments-business-starts', '{{%appointments}}', ['business_id', 'starts_at']);
        $this->createIndex('idx-appointments-staff-starts', '{{%appointments}}', ['staff_id', 'starts_at']);
        $this->createIndex('idx-appointments-client', '{{%appointments}}', 'client_id');
        $this->createIndex('idx-appointments-status', '{{%appointments}}', 'status');
        $this->addForeignKey('fk-appointments-business', '{{%appointments}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-appointments-client', '{{%appointments}}', 'client_id', '{{%clients}}', 'id', 'SET NULL', 'CASCADE');
        $this->addForeignKey('fk-appointments-staff', '{{%appointments}}', 'staff_id', '{{%staff}}', 'id', 'RESTRICT', 'CASCADE');
        $this->addForeignKey('fk-appointments-service', '{{%appointments}}', 'service_id', '{{%services}}', 'id', 'RESTRICT', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%appointments}}');
    }
}
