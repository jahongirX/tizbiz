<?php

use common\db\Migration;

/**
 * Photos for menu items / services and their categories (catalog vertical, but
 * useful for any). Stores an absolute URL returned by the upload endpoint.
 * Nullable/additive.
 */
class m260810_120000_add_image_to_catalog extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%services}}', 'image', $this->string(500)->null());
        $this->addColumn('{{%service_categories}}', 'image', $this->string(500)->null());
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%service_categories}}', 'image');
        $this->dropColumn('{{%services}}', 'image');
    }
}
