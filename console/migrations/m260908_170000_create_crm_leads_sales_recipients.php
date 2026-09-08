<?php

use common\db\Migration;

/**
 * SMS-product CRM for the superadmin cabinet:
 *   sms_leads       applications left from the landing form (no login needed)
 *   sms_sales       manual subscription sales (a lead/account -> tariff + amount)
 *   sms_recipients  every phone number the platform's accounts send to, collected
 *                   centrally (dedup by normalized digits, with counts + last seen)
 */
class m260908_170000_create_crm_leads_sales_recipients extends Migration
{
    public function safeUp(): void
    {
        $this->createTable('{{%sms_leads}}', [
            'id' => $this->primaryKey(),
            'name' => $this->string(120)->null(),
            'phone' => $this->string(32)->notNull(),
            'business' => $this->string(160)->null(),
            'tariff' => $this->string(20)->null(),
            'note' => $this->string(500)->null(),
            'status' => $this->string(16)->notNull()->defaultValue('new'), // new|contacted|won|lost
            'source' => $this->string(40)->null()->defaultValue('landing'),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);
        $this->createIndex('idx-sms_leads-status', '{{%sms_leads}}', 'status');
        $this->createIndex('idx-sms_leads-created', '{{%sms_leads}}', 'created_at');

        $this->createTable('{{%sms_sales}}', [
            'id' => $this->primaryKey(),
            'lead_id' => $this->integer()->null(),
            'account_id' => $this->integer()->null(),   // {{%sms_accounts}}.id
            'name' => $this->string(160)->null(),
            'phone' => $this->string(32)->null(),
            'tariff' => $this->string(20)->null(),       // start|pro|expert
            'amount' => $this->integer()->notNull()->defaultValue(0), // so'm
            'period_months' => $this->integer()->notNull()->defaultValue(12),
            'starts_at' => $this->integer()->null(),
            'ends_at' => $this->integer()->null(),
            'note' => $this->string(500)->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);
        $this->createIndex('idx-sms_sales-created', '{{%sms_sales}}', 'created_at');
        $this->createIndex('idx-sms_sales-account', '{{%sms_sales}}', 'account_id');

        $this->createTable('{{%sms_recipients}}', [
            'id' => $this->primaryKey(),
            'phone' => $this->string(32)->notNull(),     // normalized digits
            'send_count' => $this->integer()->notNull()->defaultValue(0),
            'last_user_id' => $this->integer()->null(),
            'first_seen_at' => $this->integer()->notNull(),
            'last_seen_at' => $this->integer()->notNull(),
        ]);
        $this->createIndex('idx-sms_recipients-phone', '{{%sms_recipients}}', 'phone', true);
        $this->createIndex('idx-sms_recipients-last_seen', '{{%sms_recipients}}', 'last_seen_at');
    }

    public function safeDown(): void
    {
        $this->dropTable('{{%sms_recipients}}');
        $this->dropTable('{{%sms_sales}}');
        $this->dropTable('{{%sms_leads}}');
    }
}
