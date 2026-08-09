<?php

use common\db\Migration;

/**
 * Line items sold on an appointment (extra services and/or products), plus a
 * free-text comment on the appointment. Products decrement inventory stock.
 */
class m260719_170000_create_appointment_items extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%appointments}}', 'notes', $this->text()->null());

        $this->createTable('{{%appointment_items}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'appointment_id' => $this->bigInteger()->notNull(),
            'kind' => $this->string(12)->notNull(),        // service | product
            'ref_id' => $this->bigInteger()->notNull(),    // service or product id
            'name' => $this->string(160)->notNull(),       // snapshot name
            'qty' => $this->integer()->notNull()->defaultValue(1),
            'price_tiyin' => $this->bigInteger()->notNull()->defaultValue(0), // unit price snapshot
            'created_at' => $this->integer()->notNull(),
        ], $this->tableOptions());

        $this->createIndex('idx-appointment_items-appointment', '{{%appointment_items}}', 'appointment_id');
        $this->createIndex('idx-appointment_items-business', '{{%appointment_items}}', 'business_id');
        $this->addForeignKey('fk-appointment_items-appointment', '{{%appointment_items}}', 'appointment_id', '{{%appointments}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-appointment_items-business', '{{%appointment_items}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%appointment_items}}');
        $this->dropColumn('{{%appointments}}', 'notes');
    }
}
