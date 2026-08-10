<?php

use common\db\Migration;

/**
 * Product detail fields for the catalog: a description and an image gallery
 * (JSON array of URLs) shown in the storefront product modal. Nullable/additive.
 */
class m260810_140000_add_details_to_services extends Migration
{
    public function safeUp(): void
    {
        $this->addColumn('{{%services}}', 'description', $this->text()->null());
        $this->addColumn('{{%services}}', 'gallery', $this->text()->null());
    }

    public function safeDown(): void
    {
        $this->dropColumn('{{%services}}', 'gallery');
        $this->dropColumn('{{%services}}', 'description');
    }
}
