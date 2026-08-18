# TizBiz SMS API

Public REST API that lets a third-party system (CRM, e-shop, OTP flow, booking
engine…) send SMS through a TizBiz SMS account — no dashboard login, just an API
key. The key maps to one SMS account and inherits its **devices**, **monthly
quota** and **blacklist**; every message counts against the account's usage.

- **Base URL (prod):** `https://api.tizbiz.uz`
- **Auth:** API key (per account). Get/rotate it in the SMS dashboard → **API**,
  or a superadmin issues it from the superadmin panel.
- **Envelope:** success → `{ "data": … }`, error → `{ "errors": [ { "status", "title", "detail" } ] }`.
- **Encoding:** request bodies are JSON (`Content-Type: application/json`).

## Authentication

Send the key one of three ways (first match wins):

| Method | Example |
|---|---|
| Header (preferred) | `X-Api-Key: tzb_…` |
| Bearer | `Authorization: Bearer tzb_…` |
| Query / body | `?key=tzb_…` |

A missing/unknown key → **401**. A blocked account → **422**.

## Endpoints

### `POST /v1/sms/api/send`
Send to one or many recipients.

**Body**

| Field | Type | Notes |
|---|---|---|
| `to` | string \| string[] | Recipient(s), E.164 (`+998…`). Aliases: `phone`, `phones`, `number`, `numbers`. |
| `text` | string | Message body. Alias: `message`. |
| `device_id` | int (optional) | Specific sending device; default = the account's first active device. |

```jsonc
// request
{ "to": ["+998901234567", "+998907654321"], "text": "Salom, TizBiz!" }
```
```jsonc
// 200 response (data)
{
  "sent": 2, "failed": 0,
  "blocked": 0,          // dropped: on the account blacklist
  "quota_blocked": 0,    // dropped: over the monthly quota
  "device_id": 5,
  "messages": [
    { "id": 61, "phone": "+998901234567", "status": "sent",
      "external_id": "abc123", "error": null, "sent_at": 1787040000, "created_at": 1787040000 }
  ]
}
```
Blacklisted recipients are silently dropped (`blocked`). If the batch exceeds the
remaining quota, the surplus is trimmed (`quota_blocked`) and the rest is sent.
An exhausted quota or no active device → **422**.

### `GET /v1/sms/api/balance`
```jsonc
{ "quota_monthly": 1000, "used_this_month": 240, "remaining": 760, "unlimited": false }
```
`quota_monthly: 0` / `remaining: null` / `unlimited: true` means no limit.

### `GET /v1/sms/api/messages`
Outbound log, newest first. Query: `status` (`pending|sent|failed`), `phone`
(substring), `limit` (≤200, default 50), `offset`.
```jsonc
{ "items": [ { "id": 61, "phone": "+998…", "text": "…", "status": "sent", … } ],
  "total": 128, "limit": 50, "offset": 0 }
```

### `GET /v1/sms/api/messages/{id}`
One message's current status (404 if not yours).

### `GET /v1/sms/api/devices`
```jsonc
{ "items": [ { "id": 5, "name": "Redmi note 8", "status": "online", "is_active": true } ] }
```

## Examples

**cURL**
```bash
curl -X POST "https://api.tizbiz.uz/v1/sms/api/send" \
  -H "X-Api-Key: tzb_xxx" \
  -H "Content-Type: application/json" \
  -d '{"to": "+998901234567", "text": "Salom, TizBiz!"}'
```

**PHP**
```php
$ch = curl_init("https://api.tizbiz.uz/v1/sms/api/send");
curl_setopt_array($ch, [
  CURLOPT_POST => true,
  CURLOPT_RETURNTRANSFER => true,
  CURLOPT_HTTPHEADER => ["X-Api-Key: tzb_xxx", "Content-Type: application/json"],
  CURLOPT_POSTFIELDS => json_encode(["to" => "+998901234567", "text" => "Salom!"]),
]);
$res = json_decode(curl_exec($ch), true);   // $res["data"]["sent"] …
curl_close($ch);
```

## Notes / limits

- **One key per account.** Rotating it (dashboard → API → *Yangi kalit*, or the
  superadmin panel) immediately invalidates the old key.
- **Sending is synchronous** and delivered through the account's Android SMS
  Gateway phone(s); actual carrier delivery still depends on the SIM.
- Money/OTP flows: send `to` as a single string; the response `messages[0].status`
  tells you `sent` vs `failed` right away.

## Internals (for maintainers)

- Routes: [api/modules/sms/Module.php](../api/modules/sms/Module.php)
- Auth: [api/modules/sms/controllers/ApiBaseController.php](../api/modules/sms/controllers/ApiBaseController.php)
- Endpoints: [api/modules/sms/controllers/ApiController.php](../api/modules/sms/controllers/ApiController.php)
- Shared send pipeline (also used by the dashboard): [api/modules/sms/services/SmsDispatcher.php](../api/modules/sms/services/SmsDispatcher.php)
- Key storage + rotation: `api_key` on [common/models/SmsAccount.php](../common/models/SmsAccount.php) (migration `m260818_120000_sms_api_keys`).
