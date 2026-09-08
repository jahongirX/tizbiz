<?php

use common\db\Migration;

/**
 * Optional grouping of SMS contacts into categories (a freeform label per
 * account), so recipients can be filtered and bulk-selected by group.
 * Additive and nullable — existing contacts stay uncategorized.
 */
class m260908_150000_add_category_to_sms_contacts extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%sms_contacts}}', 'category', $this->string(60)->null());
        $this->createIndex('idx-sms_contacts-user-category', '{{%sms_contacts}}', ['user_id', 'category']);
    }

    public function safeDown(): void
    {
        $this->dropIndex('idx-sms_contacts-user-category', '{{%sms_contacts}}');
        $this->dropColumn('{{%sms_contacts}}', 'category');
    }
}
