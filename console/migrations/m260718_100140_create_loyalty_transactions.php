<?php

use common\db\Migration;

/**
 * Immutable ledger of loyalty balance changes.
 * reason: earn/redeem/gift/referral/adjust; ref: free-form pointer e.g. "appointment:123".
 */
class m260718_100140_create_loyalty_transactions extends Migration
{
    public function safeUp(): void
    {
        $opts = $this->db->driverName === 'mysql'
            ? 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB' : null;

        $this->createTable('{{%loyalty_transactions}}', [
            'id' => $this->bigPrimaryKey(),
            'account_id' => $this->bigInteger()->notNull(),
            'delta_points' => $this->integer()->notNull()->defaultValue(0),
            'delta_cashback_tiyin' => $this->bigInteger()->notNull()->defaultValue(0),
            'reason' => $this->string(48)->notNull(),
            'ref' => $this->string(64)->null(),
            'created_at' => $this->integer()->notNull(),
        ], $opts);

        $this->createIndex('idx-loyalty_transactions-account', '{{%loyalty_transactions}}', 'account_id');
        $this->addForeignKey('fk-loyalty_transactions-account', '{{%loyalty_transactions}}', 'account_id', '{{%loyalty_accounts}}', 'id', 'CASCADE', 'CASCADE');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%loyalty_transactions}}');
    }
}
