<?php
/**
 * SPA HTML shell. The built Vue app (apps/*) mounts on #app and reads
 * window.__TIZBIZ__. Until a build exists, the placeholder below is shown.
 *
 * @var string $appName
 * @var string $apiBase
 * @var string|null $tenantSlug
 */
?>
<!doctype html>
<html lang="uz">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/png" href="/logo.png">
    <title>TizBiz · <?= htmlspecialchars(ucfirst($appName), ENT_QUOTES) ?></title>
    <script>
        window.__TIZBIZ__ = {
            app: <?= json_encode($appName) ?>,
            apiBase: <?= json_encode($apiBase) ?>,
            tenantSlug: <?= json_encode($tenantSlug) ?>
        };
    </script>
    <!-- built CSS injected here after `pnpm build` -->
</head>
<body>
<div id="app">
    <main style="font-family:system-ui,sans-serif;max-width:640px;margin:14vh auto;padding:0 24px;text-align:center;color:#1f2937">
        <h1 style="margin:0 0 8px">TizBiz · <?= htmlspecialchars(ucfirst($appName), ENT_QUOTES) ?></h1>
        <p style="color:#6b7280">SPA shell ishlayapti. Vue app hali build qilinmagan.</p>
        <?php if ($tenantSlug !== null): ?>
            <p>Tenant: <b><?= htmlspecialchars($tenantSlug, ENT_QUOTES) ?></b></p>
        <?php endif; ?>
    </main>
</div>
<!-- built JS injected here after `pnpm build` -->
</body>
</html>
