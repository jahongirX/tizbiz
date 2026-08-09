<?php

namespace common\components;

use yii\base\Component;
use yii\web\ForbiddenHttpException;

/**
 * Holds the active tenant (business) id for the current request, resolved from
 * the JWT after authentication. {@see \common\db\ActiveRecord} uses it to scope
 * tenant-owned queries automatically.
 */
class TenantContext extends Component
{
    private ?int $id = null;

    public function setId(?int $id): void
    {
        $this->id = $id;
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    /** Return the active tenant id or fail with 403 if none is set. */
    public function require(): int
    {
        if ($this->id === null) {
            throw new ForbiddenHttpException('No active business selected.');
        }
        return $this->id;
    }
}
