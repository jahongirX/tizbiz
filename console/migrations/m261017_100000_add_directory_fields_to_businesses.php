<?php

use common\db\Migration;

/**
 * Directory (Bizcat consumer app) fields on businesses: location (city,
 * district, lat/lng), a long description, a listing opt-out flag, cached rating
 * aggregates (recomputed from reviews) and a paid "featured" window.
 */
class m261017_100000_add_directory_fields_to_businesses extends Migration
{
    public function safeUp(): void
    {
        $t = '{{%businesses}}';
        $this->addColumn($t, 'city', $this->string(64)->null()->after('map_url'));
        $this->addColumn($t, 'district', $this->string(64)->null()->after('city'));
        $this->addColumn($t, 'lat', $this->decimal(10, 7)->null()->after('district'));
        $this->addColumn($t, 'lng', $this->decimal(10, 7)->null()->after('lat'));
        $this->addColumn($t, 'description', $this->text()->null()->after('tagline'));
        $this->addColumn($t, 'is_listed', $this->boolean()->notNull()->defaultValue(true)->after('status'));
        $this->addColumn($t, 'rating_avg', $this->decimal(3, 2)->notNull()->defaultValue(0)->after('is_listed'));
        $this->addColumn($t, 'rating_count', $this->integer()->notNull()->defaultValue(0)->after('rating_avg'));
        $this->addColumn($t, 'featured_until', $this->integer()->null()->after('rating_count'));

        $this->createIndex('idx-businesses-directory', $t, ['status', 'is_listed', 'category']);
        $this->createIndex('idx-businesses-city', $t, ['city']);
        $this->createIndex('idx-businesses-rating', $t, ['rating_avg']);
    }

    public function safeDown(): void
    {
        $t = '{{%businesses}}';
        $this->dropIndex('idx-businesses-rating', $t);
        $this->dropIndex('idx-businesses-city', $t);
        $this->dropIndex('idx-businesses-directory', $t);

        $this->dropColumn($t, 'featured_until');
        $this->dropColumn($t, 'rating_count');
        $this->dropColumn($t, 'rating_avg');
        $this->dropColumn($t, 'is_listed');
        $this->dropColumn($t, 'description');
        $this->dropColumn($t, 'lng');
        $this->dropColumn($t, 'lat');
        $this->dropColumn($t, 'district');
        $this->dropColumn($t, 'city');
    }
}
