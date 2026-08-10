<?php

namespace common\engines;

use common\models\Business;
use common\models\Service;
use common\models\ServiceCategory;

/**
 * Catalog vertical (cafe / restaurant / cakes / sweets). The public page is a
 * menu (categories -> items) + cart + checkout (see OrderController), not a
 * booking wizard, so it builds its own payload: the business profile plus the
 * menu grouped by category. Every active service is a menu item.
 */
class CatalogEngine extends SlotEngine
{
    public static function key(): string
    {
        return 'catalog';
    }

    public function label(): string
    {
        return 'Kafe / Restoran / Shirinliklar';
    }

    public function publicData(Business $business): array
    {
        $items = $this->offerings($business);

        // Group items under their category (uncategorised -> "Boshqa").
        $catNames = ServiceCategory::find()
            ->where(['business_id' => $business->id])
            ->orderBy(['sort' => SORT_ASC, 'id' => SORT_ASC])
            ->all();
        $order = [];
        $img = [];
        $groups = [];
        foreach ($catNames as $c) {
            $order[(int) $c->id] = $c->name;
            $img[(int) $c->id] = $c->image;
            $groups[(int) $c->id] = [];
        }
        $groups[0] = [];
        $order[0] = 'Boshqa';
        $img[0] = null;

        foreach ($items as $it) {
            $cid = (int) ($it->category_id ?? 0);
            if (!isset($groups[$cid])) {
                $cid = 0;
            }
            $groups[$cid][] = $it;
        }

        $categories = [];
        foreach ($order as $cid => $name) {
            if (!empty($groups[$cid])) {
                $categories[] = ['id' => $cid, 'name' => $name, 'image' => $img[$cid], 'items' => $groups[$cid]];
            }
        }

        return [
            'engine' => static::key(),
            'business' => $this->businessPayload($business),
            'categories' => $categories,
            'items' => $items,
        ];
    }

    /** For a catalog, every active service is a menu item (booking flag ignored). */
    public function offerings(Business $business): array
    {
        return Service::find()
            ->where(['business_id' => $business->id, 'is_active' => 1])
            ->orderBy(['category_id' => SORT_ASC, 'id' => SORT_ASC])
            ->all();
    }
}
