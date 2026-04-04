// ══════════════════════════════════════════════════════════════════
//  src/api/client.js
//  Cliente HTTP que consume el Edge API local.
//  Opera sin internet — todo es localhost:3000 vía LAN.
// ══════════════════════════════════════════════════════════════════

const BASE_URL = '/api/v1'
const TOKEN    = import.meta.env.VITE_DEVICE_TOKEN || 'dev-token-change-in-production'

async function request(method, path, body) {
  const opts = {
    method,
    headers: {
      'Authorization': `Bearer ${TOKEN}`,
      'Content-Type':  'application/json',
    },
  }
  if (body) opts.body = JSON.stringify(body)

  const res = await fetch(`${BASE_URL}${path}`, opts)
  const data = await res.json()

  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`)
  return data
}

export const api = {
  // ── Status ──────────────────────────────────────────────────
  getStatus:  ()           => request('GET',   '/status'),
  getHealth:  ()           => fetch('/health').then(r => r.json()),

  // ── Mesas ───────────────────────────────────────────────────
  getTables:  ()           => request('GET',   '/tables'),
  getTable:   (id)         => request('GET',   `/tables/${id}`),

  // ── Menú ────────────────────────────────────────────────────
  getMenu:    ()           => request('GET',   '/menu'),

  // ── Pedidos ─────────────────────────────────────────────────
  getOrders:  ()           => request('GET',   '/orders'),
  getOrder:   (id)         => request('GET',   `/orders/${id}`),
  createOrder:(data)       => request('POST',  '/orders',        { order: data }),
  updateOrder:(id, data)   => request('PATCH', `/orders/${id}`,  { order: data }),
  closeOrder: (id)         => request('POST',  `/orders/${id}/close`),
  cancelOrder:(id)         => request('DELETE',`/orders/${id}`),

  // ── Items ───────────────────────────────────────────────────
  addItem:    (orderId, data) => request('POST',  `/orders/${orderId}/items`, { item: data }),
  updateItem: (orderId, id, data) => request('PATCH', `/orders/${orderId}/items/${id}`, { item: data }),
  removeItem: (orderId, id)   => request('DELETE', `/orders/${orderId}/items/${id}`),
  updateItemStatus: (orderId, id, status) =>
    request('PATCH', `/orders/${orderId}/items/${id}/status`, { status }),

  // ── KDS ─────────────────────────────────────────────────────
  getKdsQueue:   ()    => request('GET',  '/kds/queue'),
  getKdsOrders:  ()    => request('GET',  '/kds/orders'),
  markItemReady: (id)  => request('POST', `/kds/items/${id}/ready`),
  markOrderReady:(id)  => request('POST', `/kds/orders/${id}/ready`),
}
