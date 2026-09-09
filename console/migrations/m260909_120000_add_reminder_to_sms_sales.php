<?php

use common\db\Migration;

/**
 * A sale is a *contract* (shartnoma): it has a term (starts_at..ends_at) and we
 * must warn ourselves before it lapses so we can renew/collect. These columns
 * track how far the expiry reminder has already advanced so the cron never
 * double-sends a threshold (30 -> 15 -> 5 -> 1 -> expired).
 */
class m260909_120000_add_reminder_to_sms_sales extends Migration
{
    public function safeUp(): void
    {
        // Last reminder threshold (days) already fired: 30/15/5/1, or 0 = "expired"
        // notice sent. NULL = nothing sent yet. Monotonically decreases.
        $this->addColumn('{{%sms_sales}}', 'reminder_stage', $this->integer()->null());
        $this->addColumn('{{%sms_sales}}', 'last_reminded_at', $this->integer()->null());
        $this->createIndex('idx-sms_sales-ends', '{{%sms_sales}}', 'ends_at');
    }

    public function safeDown(): void
    {
        $this->dropIndex('idx-sms_sales-ends', '{{%sms_sales}}');
        $this->dropColumn('{{%sms_sales}}', 'last_reminded_at');
        $this->dropColumn('{{%sms_sales}}', 'reminder_stage');
    }
}
