<?php

use common\db\Migration;

/**
 * Photo for a staff member. A barbershop client picks their master by face, and
 * the booking site currently shows only initials. Stores an absolute URL
 * returned by the upload endpoint. Nullable/additive: every vertical keeps
 * working without it.
 */
class m260817_100000_add_avatar_to_staff extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%staff}}', 'avatar', $this->string(500)->null());
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%staff}}', 'avatar');
    }
}
