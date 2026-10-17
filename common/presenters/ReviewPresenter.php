<?php

namespace common\presenters;

use common\models\Business;
use common\models\Review;

/**
 * Views of a {@see Review}. Load relations `staff`, `service` (and `business`
 * for mine()) with ->with() when presenting a list.
 */
final class ReviewPresenter
{
    /** Public item (directory). Never exposes consumer_id. */
    public static function public(Review $r): array
    {
        return [
            'id' => (int) $r->id,
            'rating' => (int) $r->rating,
            'comment' => $r->comment,
            'author_name' => (string) $r->author_name,
            'service_name' => $r->service?->name,
            'staff_name' => $r->staff?->name,
            'reply' => $r->reply,
            'replied_at' => $r->replied_at !== null ? (int) $r->replied_at : null,
            'created_at' => (int) $r->created_at,
        ];
    }

    /** The consumer's own review: public fields + business, ids and status. */
    public static function mine(Review $r): array
    {
        $b = $r->business;
        return self::public($r) + [
            'business' => $b instanceof Business ? BusinessPresenter::mini($b) : null,
            'appointment_id' => $r->appointment_id !== null ? (int) $r->appointment_id : null,
            'order_id' => $r->order_id !== null ? (int) $r->order_id : null,
            'status' => (string) $r->status,
        ];
    }

    /** Business-side item (GET /v1/reviews). */
    public static function business(Review $r): array
    {
        return [
            'id' => (int) $r->id,
            'rating' => (int) $r->rating,
            'comment' => $r->comment,
            'author_name' => (string) $r->author_name,
            'status' => (string) $r->status,
            'appointment_id' => $r->appointment_id !== null ? (int) $r->appointment_id : null,
            'order_id' => $r->order_id !== null ? (int) $r->order_id : null,
            'staff_id' => $r->staff_id !== null ? (int) $r->staff_id : null,
            'staff_name' => $r->staff?->name,
            'service_id' => $r->service_id !== null ? (int) $r->service_id : null,
            'service_name' => $r->service?->name,
            'reply' => $r->reply,
            'replied_at' => $r->replied_at !== null ? (int) $r->replied_at : null,
            'created_at' => (int) $r->created_at,
        ];
    }
}
