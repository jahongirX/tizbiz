<?php

use common\db\Migration;

/**
 * Adds an optional email to CRM clients (shown in the client base like YClients).
 */
class m260719_120000_add_email_to_clients extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%clients}}', 'email', $this->string(128)->null());
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%clients}}', 'email');
    }
}
