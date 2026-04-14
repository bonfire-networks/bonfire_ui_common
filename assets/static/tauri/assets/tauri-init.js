// Global error handler — catches unhandled JS errors and shows a recovery UI.
// Runs before any module scripts so crashes during module load are caught too.
(function () {
    var errors = [];
    var overlayShown = false;

    function showErrorOverlay(msg, isDbCorruption) {
        if (overlayShown) return;
        overlayShown = true;
        // Use native Rust dialog (works even when the page is broken)
        var invoke = window.__TAURI__ && window.__TAURI__.core && window.__TAURI__.core.invoke;
        if (invoke) {
            invoke('show_crash_dialog', { message: msg, isDbCorruption: !!isDbCorruption }).catch(function () {
                alert('Something went wrong:\n\n' + msg);
            });
        } else {
            alert('Something went wrong:\n\n' + msg);
        }
    }

    window.addEventListener('error', function (e) {
        var msg = e.error && e.error.stack ? e.error.stack : ((e.message || 'Unknown error') + '\n' + (e.filename || '') + ':' + e.lineno);
        var isDb = e.error && e.error.isDbCorruption;
        errors.push(msg);
        showErrorOverlay(errors.join('\n\n---\n\n'), isDb);
    });

    window.addEventListener('unhandledrejection', function (e) {
        var msg = e.reason && e.reason.stack ? e.reason.stack : String(e.reason);
        var isDb = e.reason && e.reason.isDbCorruption;
        errors.push('Unhandled promise rejection: ' + msg);
        showErrorOverlay(errors.join('\n\n---\n\n'), isDb);
    });
})();

// Forward console.log/warn/error to Rust logs when JS debug mode is active
// (set automatically after an unclean shutdown via window.__BONFIRE_JS_DEBUG__).
(function () {
    if (!window.__TAURI__ || !window.__BONFIRE_JS_DEBUG__) return;
    var _invoke = null; // lazily resolved after Tauri is ready
    function fwd(level, args) {
        try {
            var msg = Array.from(args).map(function (a) {
                return (typeof a === 'object') ? JSON.stringify(a) : String(a);
            }).join(' ');
            if (!_invoke) _invoke = window.__TAURI__.core && window.__TAURI__.core.invoke;
            if (_invoke) _invoke('js_log', { level: level, msg: msg }).catch(function () {});
        } catch (e) {}
    }
    var _log = console.log, _warn = console.warn, _error = console.error;
    console.log   = function () { _log.apply(console, arguments);   fwd('info',  arguments); };
    console.warn  = function () { _warn.apply(console, arguments);  fwd('warn',  arguments); };
    console.error = function () { _error.apply(console, arguments); fwd('error', arguments); };
    console.warn('[tauri-init] JS debug mode active — console forwarded to Rust logs');
})();

// Shadow DOM query helper for tests: shadowQ('selector >>> inner >>> deepest')
// Splits on >>> and traverses shadow roots at each step.
// Falls back to a recursive shadow-tree search when the selector isn't found at the current level.
window.shadowQ = function(selector) {
    var parts = selector.split('>>>').map(function(s) { return s.trim(); });
    function find(root, parts) {
        var el = root.querySelector(parts[0]);
        if (!el) {
            // search inside all shadow roots at this level
            var hosts = root.querySelectorAll('*');
            for (var i = 0; i < hosts.length; i++) {
                if (hosts[i].shadowRoot) {
                    el = find(hosts[i].shadowRoot, parts);
                    if (el) return el;
                }
            }
            return null;
        }
        if (parts.length === 1) return el;
        var sr = el.shadowRoot;
        if (!sr) return null;
        return find(sr, parts.slice(1));
    }
    return find(document, parts);
};

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
