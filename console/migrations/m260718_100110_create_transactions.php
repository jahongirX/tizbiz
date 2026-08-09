<?php

use common\db\Migration;

/**
 * Payment records (deposits, refunds, platform float). amount_tiyin in tiyin.
 * provider: payme/click; type: deposit/refund/float;
 * status: created/pending/paid/canceled/refunded.
 * idempotency_key guards against duplicate init/webhook processing.
 */
class m260718_100110_create_transactions extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%transactions}}', [
            'id' => $this->bigPrimaryKey(),
            'business_id' => $this->bigInteger()->notNull(),
            'appointment_id' => $this->bigInteger()->null(),
            'provider' => $this->string(16)->notNull(),
            'amount_tiyin' => $this->bigInteger()->notNull(),
            'type' => $this->string(16)->notNull(),
            'status' => $this->string(16)->notNull()->defaultValue('created'),
            'external_id' => $this->string(128)->null(),
            'idempotency_key' => $this->string(64)->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('uq-transactions-idem', '{{%transactions}}', 'idempotency_key', true);
        $this->createIndex('idx-transactions-business', '{{%transactions}}', 'business_id');
        $this->createIndex('idx-transactions-appointment', '{{%transactions}}', 'appointment_id');
        $this->createIndex('idx-transactions-external', '{{%transactions}}', ['provider', 'external_id']);
        $this->addForeignKey('fk-transactions-business', '{{%transactions}}', 'business_id', '{{%businesses}}', 'id', 'CASCADE', 'CASCADE');
        $this->addForeignKey('fk-transactions-appointment', '{{%transactions}}', 'appointment_id', '{{%appointments}}', 'id', 'SET NULL', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%transactions}}');
    }
}
