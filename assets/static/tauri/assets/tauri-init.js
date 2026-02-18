// Shared Tauri initialization: override window.fetch to bypass WKWebView
// network restrictions on cross-origin requests.
// Two strategies available — switch USE_INVOKE below to toggle.
// Include this script (non-module) before any module scripts that use fetch.
(function () {
    if (!window.__TAURI__) return;

    // Toggle: true = use invoke('fetch_url'), false = use Tauri HTTP plugin
    var USE_INVOKE = false;

    var invoke = window.__TAURI__.core?.invoke;
    var httpFetch = window.__TAURI__.http?.fetch;
    var _nativeFetch = window.fetch;

    // Strategy 1: Single invoke() round-trip via Rust reqwest
    function fetchViaInvoke(url, options) {
        var hdrs = {};
        if (options && options.headers) {
            var h = options.headers instanceof Headers
                ? options.headers
                : new Headers(options.headers);
            h.forEach(function (v, k) { hdrs[k] = v; });
        }
        var method = (options && options.method) ? options.method.toUpperCase() : 'GET';
        var body = null;
        if (options && options.body != null) {
            body = typeof options.body === 'string'
                ? options.body
                : options.body.toString();
        }
        return invoke('fetch_url', { url: url, method: method, headers: hdrs, body: body })
            .then(function (res) {
                return new Response(res.body, {
                    status: res.status,
                    headers: res.headers
                });
            });
    }

    // Strategy 2: Tauri HTTP plugin (multi-step IPC)
    function fetchViaPlugin(url, options) {
        return httpFetch(url, options);
    }

    var strategy = USE_INVOKE && invoke ? 'invoke' : httpFetch ? 'plugin' : null;

    if (!strategy) {
        console.warn('[tauri-init] No fetch override available, using native fetch');
        return;
    }

    // Warmup: trigger a no-op invoke to force IPC custom protocol → postMessage
    // fallback BEFORE the user interacts (avoids mid-request page reload).
    if (invoke) {
        invoke('get_layout_mode').catch(function () {});
    }

    var doFetch = strategy === 'invoke' ? fetchViaInvoke : fetchViaPlugin;

    window.fetch = function (url, options) {
        if (typeof url === 'string' && url.startsWith('https://')) {
            return doFetch(url, options).catch(function (err) {
                console.error('[tauri-init] Tauri fetch (' + strategy + ') failed:', err);
                return _nativeFetch.call(window, url, options);
            });
        }
        return _nativeFetch.call(window, url, options);
    };
    console.log('[tauri-init] Overrode window.fetch using strategy: ' + strategy);

    // Request notification permission early so it's granted when needed
    var notif = window.__TAURI__.notification;
    if (notif && notif.isPermissionGranted) {
        notif.isPermissionGranted().then(function (granted) {
            if (!granted) notif.requestPermission();
        }).catch(function () {});
    }
})();
