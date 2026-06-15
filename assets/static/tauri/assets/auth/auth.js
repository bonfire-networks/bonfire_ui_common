// auth.js
// OAuth, Webfinger, and token management helpers for the Tauri login shell.
//
// VENDORED from ap_c2s_client (js/activitypub/auth.js) so the shell's login flow
// does NOT depend on the chat-client repo being present — the iOS build ships
// without it. Keep this in sync if the chat client's auth.js changes; the only
// local edit is the oauth4webapi import below (relative path, not a bare module).
// oauth4webapi.js is the vendored npm package (v3.8.5, zero-dependency ESM).

import * as oauth from './oauth4webapi.js'


export const WEBFINGER_REGEXP =
    /^(?:acct:)?(?<username>[^@]+)@(?<domain>(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(?:\.(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?))*)$/


export async function handleLogin({ clientId, redirectUri, successUri } = {}) {
    // Support both options object and legacy `this`-based calling (via .call(component))
    clientId = clientId || this?.clientId
    redirectUri = redirectUri || this?.redirectUri
    successUri = successUri || this?.successUri

    const origin_url = localStorage.getItem('actor_id') || localStorage.getItem('appUrl')

    const authorizationServer = {
        issuer: URL.parse(origin_url)?.origin || origin_url,
        authorization_endpoint: localStorage.getItem('authorization_endpoint'),
        token_endpoint: localStorage.getItem('token_endpoint'),
        code_challenge_methods_supported: ['S256'],
        scopes_supported: ['read', 'write'],
        response_types_supported: ['code'],
        grant_types_supported: ['authorization_code', 'refresh_token']
    }
    const clientAuth = oauth.None()
    const client = {
        client_id: clientId
    }

    const state = sessionStorage.getItem('state')
    const codeVerifier = sessionStorage.getItem('code_verifier')
    const paramsObj = Object.fromEntries(new URLSearchParams(window.location.search).entries());
    console.log('[handleLogin] Starting token exchange with:', {
        client_id: clientId,
        redirect_uri: redirectUri,
        state,
        codeVerifier,
        params: paramsObj,
        authorizationServer
    });

    const params = oauth.validateAuthResponse(
        authorizationServer,
        client,
        new URLSearchParams(window.location.search),
        state
    )

    console.log('[handleLogin] validateAuthResponse params:', params);

    const response = await oauth.authorizationCodeGrantRequest(
        authorizationServer,
        client,
        clientAuth,
        params,
        redirectUri,
        codeVerifier
    )

    console.log('[handleLogin] authorizationCodeGrantRequest response:', response);

    const result = await oauth.processAuthorizationCodeResponse(
        authorizationServer,
        client,
        response
    )

    console.log('[handleLogin] processAuthorizationCodeResponse result:', result);

    saveResult(result, clientId)

    sessionStorage.removeItem('state')
    sessionStorage.removeItem('code_verifier')

    return { result, successUri }
}


export async function getActorId(id) {
    const m = WEBFINGER_REGEXP.exec(id)
    if (!m) throw new Error('bad Webfinger format for id: ' + id)
    const username = m.groups.username
    const domain = m.groups.domain
    const wfUrl = `https://${domain}/.well-known/webfinger?resource=acct:${username}%40${domain}`
    console.log('[getActorId] Fetching WebFinger:', wfUrl)
    let res
    try {
        res = await fetch(wfUrl, {
            headers: { Accept: 'application/jrd+json,application/json' }
        })
    } catch (err) {
        console.error('[getActorId] WebFinger fetch failed:', err.name, err.message, err)
        throw err
    }
    console.log('[getActorId] WebFinger response:', res.status, res.statusText)
    if (!res.ok) throw new Error(`Could not load webfinger (${res.status} ${res.statusText})`)
    const json = await res.json()
    if (!json.links) throw new Error('No links in webfinger json')
    const actorLink = json.links.find(
        (obj) =>
            obj.rel == 'self' &&
            [
                'application/activity+json',
                'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
            ].includes(obj.type)
    )
    if (!actorLink) throw new Error('No ActivityPub actor ID in Webfinger')
    console.log('[getActorId] Resolved actor ID:', actorLink.href)
    return actorLink.href
}

export async function getActor(actorId) {
    console.log('[getActor] Fetching actor:', actorId)
    let res
    try {
        res = await fetch(actorId, {
            cache: 'no-store',
            headers: {
                Accept:
                    'application/activity+json,application/lrd+json,application/json',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache'
            }
        })
    } catch (err) {
        console.error('[getActor] Actor fetch failed:', err.name, err.message, err)
        throw err
    }
    console.log('[getActor] Actor response:', res.status, res.statusText)
    if (!res.ok) throw new Error(`Failure fetching actor (${res.status} ${res.statusText})`)
    return await res.json()
}

export async function getCurrentActor() {
    const actorJSON = localStorage.getItem('actor')
    if (actorJSON) {
        return JSON.parse(actorJSON)
    } else {
        const actorId = localStorage.getItem('actor_id')
        if (!actorId || !URL.canParse(actorId)) {
            throw new Error(`Invalid actor_id in localStorage: ${JSON.stringify(actorId)}`)
        }
        // Actor profile endpoint requires HTTP signatures, not Bearer tokens — use plain fetch
        const res = await fetch(actorId, {
            headers: {
                Accept: 'application/activity+json,application/lrd+json,application/json',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
            }
        })
        if (!res.ok) {
            throw new Error(`Failure fetching actor (${res.status} ${res.statusText})`)
        }
        const actor = await res.json()
        localStorage.setItem('actor', JSON.stringify(actor))
        return actor
    }
}


export function getAuthorizationEndpoint(actor) {
    return actor.endpoints?.oauthAuthorizationEndpoint
}

export function getTokenEndpoint(actor) {
    return actor.endpoints?.oauthTokenEndpoint
}

export function getProxyUrl(actor) {
    return actor.endpoints?.proxyUrl
}

/**
 * Shared login flow: resolve actor via webfinger, discover OAuth endpoints,
 * generate PKCE challenge, and redirect to the authorization endpoint.
 *
 * @param {string} webfingerId  - user@domain (with or without leading @)
 * @param {string} clientId     - OAuth client_id URL
 * @param {string} redirectUri  - OAuth redirect_uri
 * @returns {string} the authorization URL to redirect to
 */
export async function startLogin(webfingerId, clientId, redirectUri) {
    const id = webfingerId.replace(/^@/, '')
    console.log('[startLogin] Starting login for:', id, 'clientId:', clientId, 'redirectUri:', redirectUri)

    // 1. Webfinger → actor
    console.log('[startLogin] Step 1: WebFinger lookup...')
    const actorId = await getActorId(id)
    localStorage.setItem('actor_id', actorId)
    console.log('[startLogin] Step 2: Fetching actor...')
    const actor = await getActor(actorId)
    localStorage.setItem('actor', JSON.stringify(actor))

    const domain = id.split('@').slice(-1)[0]
    localStorage.setItem('appUrl', domain)
    localStorage.setItem('appUsername', id)

    // 2. Discover OAuth endpoints (prefer actor endpoints, fall back to well-known)
    let authorizationUrl = getAuthorizationEndpoint(actor)
    let tokenUrl = getTokenEndpoint(actor)
    const proxyUrl = getProxyUrl(actor)
    console.log('[startLogin] Step 3: OAuth discovery. From actor:', { authorizationUrl, tokenUrl, proxyUrl })

    if (!authorizationUrl || !tokenUrl) {
        const wkUrl = `https://${domain}/.well-known/oauth-authorization-server`
        console.log('[startLogin] Falling back to well-known:', wkUrl)
        let res
        try {
            res = await fetch(wkUrl)
        } catch (err) {
            console.error('[startLogin] OAuth well-known fetch failed:', err.name, err.message, err)
            throw err
        }
        console.log('[startLogin] OAuth well-known response:', res.status, res.statusText)
        const meta = await res.json()
        console.log('[startLogin] OAuth metadata:', meta)
        authorizationUrl = authorizationUrl || meta?.authorization_endpoint
        tokenUrl = tokenUrl || meta?.token_endpoint
    }

    if (!authorizationUrl) throw new Error('No OAuth authorization endpoint.')
    if (!tokenUrl) throw new Error('No OAuth token endpoint.')

    localStorage.setItem('authorization_endpoint', authorizationUrl)
    localStorage.setItem('token_endpoint', tokenUrl)
    if (proxyUrl) localStorage.setItem('proxy_url', proxyUrl)

    // 3. PKCE + state
    const code_verifier = oauth.generateRandomCodeVerifier()
    const code_challenge = await oauth.calculatePKCECodeChallenge(code_verifier)
    const state = crypto.randomUUID()

    sessionStorage.setItem('code_verifier', code_verifier)
    sessionStorage.setItem('state', state)

    // 4. Build authorization URL
    return buildAuthorizationUrl({
        authorizationUrl,
        clientId,
        redirectUri,
        codeChallenge: code_challenge,
        state,
        loginHint: id
    })
}

export function buildAuthorizationUrl({
    authorizationUrl,
    clientId,
    redirectUri,
    codeChallenge,
    state,
    loginHint
}) {
    const url = new URL(authorizationUrl)
    url.searchParams.set('client_id', clientId)
    url.searchParams.set('redirect_uri', redirectUri)
    url.searchParams.set('response_type', 'code')
    url.searchParams.set('scope', 'read write')
    url.searchParams.set('code_challenge', codeChallenge)
    url.searchParams.set('code_challenge_method', 'S256')
    url.searchParams.set('state', state)
    if (loginHint) url.searchParams.set('login_hint', loginHint)
    return url.toString()
}

export function saveResult(result, clientId) {
  localStorage.setItem('access_token', result.access_token)
  localStorage.setItem('refresh_token', result.refresh_token)
  localStorage.setItem('expires_in', result.expires_in)
  localStorage.setItem(
    'expires',
    Date.now() + result.expires_in * 1000
  )
  if (clientId) {
    localStorage.setItem('client_id', clientId)
  }
}

/**
 * Dispatch an auth error event to notify the UI that re-login is needed.
 * Components can listen for this event to show a login prompt.
 */
function dispatchAuthError(reason) {
  console.error('[Auth] Authentication failed:', reason)
  window.dispatchEvent(new CustomEvent('auth-error', { detail: { reason } }))
}

/**
 * Log out: clear server session (HttpOnly cookie) and local storage.
 */
export async function logout() {
  try {
    const actorId = localStorage.getItem('actor_id')
    if (actorId) {
      const origin = new URL(actorId).origin
      await fetch(`${origin}/logout`, { credentials: 'include' })
    }
  } catch (_) { /* best-effort */ }
  localStorage.clear()
  sessionStorage.clear()
}

export async function ensureFreshToken(clientId) {
  const expires = parseInt(localStorage.getItem('expires'))
  // If expires is absent/NaN the token was injected directly (e.g. E2E) — skip refresh.
  if (isNaN(expires)) return
  if (Date.now() > expires) {
    clientId = clientId || localStorage.getItem('client_id')
    if (!clientId) {
      dispatchAuthError('Missing client_id - please re-login')
      return
    }
    const actorId = localStorage.getItem('actor_id')
    if (!actorId) {
      dispatchAuthError('Missing actor_id - please re-login')
      return
    }
    const refreshToken = localStorage.getItem('refresh_token')
    if (!refreshToken) {
      dispatchAuthError('Missing refresh_token - please re-login')
      return
    }
    const authorizationServer = {
      issuer: (new URL(actorId)).origin,
      authorization_endpoint: localStorage.getItem('authorization_endpoint'),
      token_endpoint: localStorage.getItem('token_endpoint'),
      code_challenge_methods_supported: ['S256'],
      scopes_supported: ['read', 'write'],
      response_types_supported: ['code'],
      grant_types_supported: ['authorization_code', 'refresh_token']
    }
    const clientAuth = oauth.None()
    const client = {
      client_id: clientId
    }
    try {
      const response = await oauth.refreshTokenGrantRequest(
        authorizationServer,
        client,
        clientAuth,
        refreshToken
      )
      if (!response.ok) {
        dispatchAuthError('Token refresh failed - please re-login')
        return
      }
      const result = await oauth.processRefreshTokenResponse(
        authorizationServer,
        client,
        response
      )
      saveResult(result, clientId)
    } catch (error) {
      console.error('[Auth] Token refresh error:', error)
      dispatchAuthError('Token refresh failed - please re-login')
    }
  }
}

/**
 * Make a protected fetch with a Bearer token.
 * oauth4webapi's protectedResourceRequest rejects non-https URLs, so for
 * http:// targets (local dev / E2E) we fall back to plain fetch with an
 * Authorization header — behaviour is identical.
 */
async function bearerFetch(accessToken, method, urlObj, headers, body) {
    if (urlObj.protocol === 'https:') {
        return oauth.protectedResourceRequest(accessToken, method, urlObj, headers, body)
    }
    return fetch(urlObj, {
        method: method || 'GET',
        headers: { ...headers, 'Authorization': `Bearer ${accessToken}` },
        body
    })
}

export async function apFetch(url, options = {}) {
    await ensureFreshToken()
    const accessToken = localStorage.getItem('access_token')
    if (!accessToken) {
      dispatchAuthError('No access token - please re-login')
      throw new Error('Not authenticated')
    }
     const origin_url = localStorage.getItem('actor_id') || localStorage.getItem('appUrl')
     if (!origin_url) {
         dispatchAuthError('No origin URL - please re-login')
         throw new Error('No origin URL - cannot determine same-origin for fetch')
      }
    const urlObj = (typeof url === 'string')
        ? new URL(url)
        : url
     if (urlObj.origin == URL.parse(origin_url)?.origin) {
        const response = await bearerFetch(
            accessToken,
            options.method || 'GET',
            urlObj,
            options.headers,
            options.body
        )
        if (response.status === 401 || response.status === 403) {
          console.warn('[apFetch] Server returned', response.status, 'for', urlObj.toString())
        }
        return response
    } else {
        const proxyUrl = localStorage.getItem('proxy_url')
        // In Tauri, fetch is already routed through Rust (no CORS), so fall back
        // to a direct bearer fetch when no server-side proxy is configured.
        if (!proxyUrl || window.__TAURI__) {
            const response = await bearerFetch(accessToken, options.method || 'GET', urlObj, options.headers, options.body)
            if (response.status === 401 || response.status === 403) {
                console.warn('[apFetch] Direct cross-origin returned', response.status, 'for', urlObj.toString())
            }
            return response
        }
        const response = await bearerFetch(
            accessToken,
            'POST',
            new URL(proxyUrl),
            { 'Content-Type': 'application/x-www-form-urlencoded' },
            new URLSearchParams({ id: urlObj.toString() })
        )
        if (response.status === 401 || response.status === 403) {
          console.warn('[apFetch] Proxy returned', response.status, 'for', urlObj.toString())
        }
        return response
    }
}

