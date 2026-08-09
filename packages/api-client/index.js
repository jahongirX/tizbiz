// Framework-agnostic REST client for the TizBiz API.
// Reads bootstrap config injected by the server (window.__TIZBIZ__) with dev
// fallbacks, attaches the JWT, and unwraps the {data|errors} envelope.

const boot = (typeof window !== 'undefined' && window.__TIZBIZ__) || {}

export const config = {
  app: boot.app || 'app',
  apiBase: (boot.apiBase || 'http://127.0.0.1:8899').replace(/\/$/, ''),
  tenantSlug: boot.tenantSlug ?? null,
}

const TOKEN_KEY = 'tizbiz_token'

export const auth = {
  get token() {
    return typeof localStorage !== 'undefined' ? localStorage.getItem(TOKEN_KEY) : null
  },
  set(token) {
    if (typeof localStorage === 'undefined') return
    if (token) localStorage.setItem(TOKEN_KEY, token)
    else localStorage.removeItem(TOKEN_KEY)
  },
  clear() {
    if (typeof localStorage !== 'undefined') localStorage.removeItem(TOKEN_KEY)
  },
  get isAuthed() {
    return !!this.token
  },
}

/** Error thrown for non-2xx responses; carries status + parsed envelope errors. */
export class ApiError extends Error {
  constructor(message, status, errors) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.errors = errors || []
  }
}

async function request(method, path, body) {
  const headers = { 'Content-Type': 'application/json' }
  const token = auth.token
  if (token) headers.Authorization = 'Bearer ' + token

  const res = await fetch(config.apiBase + path, {
    method,
    headers,
    body: body != null ? JSON.stringify(body) : undefined,
  })

  let json = null
  try {
    json = await res.json()
  } catch (_) {
    /* empty / non-JSON body */
  }

  if (!res.ok) {
    const first = json && json.errors && json.errors[0]
    const message = (first && (first.detail || first.title)) || 'HTTP ' + res.status
    throw new ApiError(message, res.status, json && json.errors)
  }

  return json && json.data !== undefined ? json.data : json
}

export const api = {
  get: (path) => request('GET', path),
  post: (path, body) => request('POST', path, body),
  patch: (path, body) => request('PATCH', path, body),
  put: (path, body) => request('PUT', path, body),
  del: (path) => request('DELETE', path),
}

export default api
