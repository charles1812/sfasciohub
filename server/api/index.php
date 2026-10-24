<?php
// SfascioHub API · punto d'ingresso unico.
// Le rotte si passano in ?r=/percorso, così funziona su qualsiasi hosting
// anche senza riscrittura degli URL.
declare(strict_types=1);

require __DIR__ . '/lib/bootstrap.php';
require __DIR__ . '/lib/auth.php';
require __DIR__ . '/lib/handlers.php';

try {
    cors();
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
    $path = '/' . trim((string) ($_GET['r'] ?? ''), '/');

    $routes = [
        ['GET', '/', fn() => ['name' => 'SfascioHub API', 'version' => API_VERSION]],
        ['GET', '/vehicles', fn() => public_vehicles()],
        ['GET', '/vehicles/{id}', fn($id) => public_vehicle($id)],
        ['GET', '/yards', fn() => public_yards()],
        ['GET', '/yards/{id}', fn($id) => public_yard($id)],
        ['GET', '/counts', fn() => public_counts()],

        ['POST', '/auth/signup', fn() => auth_signup()],
        ['POST', '/auth/login', fn() => auth_login()],
        ['POST', '/auth/logout', fn() => auth_logout()],
        ['GET', '/auth/me', fn() => auth_me()],

        ['GET', '/me/yard', fn() => ['yard' => my_yard()]],
        ['POST', '/me/yard', fn() => create_my_yard()],
        ['PUT', '/me/yard', fn() => update_my_yard()],
        ['GET', '/me/vehicles', fn() => my_vehicles()],
        ['PUT', '/me/vehicles/{id}', fn($id) => save_my_vehicle($id)],
        ['DELETE', '/me/vehicles/{id}', fn($id) => delete_my_vehicle($id)],
        ['POST', '/me/vehicles/{id}/photos', fn($id) => add_photo($id)],
        ['PUT', '/me/vehicles/{id}/photos/order', fn($id) => reorder_photos($id)],
        ['DELETE', '/me/photos/{id}', fn($id) => delete_photo($id)],
    ];

    $knownPath = false;
    foreach ($routes as [$m, $pattern, $handler]) {
        $re = '#^' . preg_replace('#\{id\}#', '([A-Za-z0-9-]{1,64})', $pattern) . '$#';
        if (preg_match($re, $path, $args)) {
            $knownPath = true;
            if ($m === $method) {
                send_json($handler(...array_slice($args, 1)));
            }
        }
    }
    throw new HttpError($knownPath ? 405 : 404, $knownPath ? 'Metodo non consentito.' : "Rotta $path non trovata.");
} catch (HttpError $e) {
    send_json(['error' => $e->getMessage()], $e->status);
} catch (Throwable $e) {
    error_log('[sfasciohub] ' . $e);
    $debug = is_file(__DIR__ . '/config.php') && (config()['debug'] ?? false);
    send_json(['error' => 'Errore del server.' . ($debug ? ' ' . $e->getMessage() : '')], 500);
}
