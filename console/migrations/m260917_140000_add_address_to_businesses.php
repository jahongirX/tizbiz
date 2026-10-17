<?php

use yii\db\Migration;

/**
 * Location for the public booking site: a human address shown on the success
 * screen and an optional map link ("Xaritada ochish"). Both nullable — a
 * business without them simply shows no location card.
 */
class m260917_140000_add_address_to_businesses extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%businesses}}', 'address', $this->string(255)->null()->after('phone'));
        $this->addColumn('{{%businesses}}', 'map_url', $this->string(500)->null()->after('address'));
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%businesses}}', 'map_url');
        $this->dropColumn('{{%businesses}}', 'address');
    }
}
