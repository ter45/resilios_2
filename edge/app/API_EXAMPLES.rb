# ══════════════════════════════════════════════════════════════════
#  ResiliOS Edge API — Ejemplos de requests y responses
#  Base URL local: http://localhost:3000
#  Header requerido: Authorization: Bearer <EDGE_DEVICE_TOKEN>
# ══════════════════════════════════════════════════════════════════


# ── GET /health ───────────────────────────────────────────────────
# curl http://localhost:3000/health

# Response 200:
# {
#   "status": "ok",
#   "version": "1.0.0",
#   "time": "2026-04-01T14:30:00.000Z"
# }


# ── GET /api/v1/status ────────────────────────────────────────────
# curl http://localhost:3000/api/v1/status \
#   -H "Authorization: Bearer mi-token-de-dispositivo"

# Response 200:
# {
#   "data": {
#     "node_id": "01HX5Y...",
#     "version": "1.0.0",
#     "restaurant": { "id": "01HX5Z...", "name": "La Fogata" },
#     "connectivity": {
#       "status": "synced",
#       "last_sync_at": "2026-04-01T14:25:00.000Z",
#       "lag_seconds": 0,
#       "lag_human": "Al día"
#     },
#     "queue": {
#       "pending_count": 0,
#       "oldest_pending_at": null
#     },
#     "system": { "db_size_mb": 12.4, "uptime_seconds": 86400 }
#   }
# }


# ── GET /api/v1/tables ────────────────────────────────────────────
# curl http://localhost:3000/api/v1/tables \
#   -H "Authorization: Bearer mi-token"

# Response 200:
# {
#   "data": [
#     { "id": "01HX6D...", "number": "1", "label": "Ventana", "capacity": 4, "status": "available" },
#     { "id": "01HX6E...", "number": "2", "label": null,      "capacity": 2, "status": "occupied"  },
#     { "id": "01HX6F...", "number": "3", "label": "Terraza", "capacity": 6, "status": "available" }
#   ]
# }


# ── GET /api/v1/menu ──────────────────────────────────────────────
# curl http://localhost:3000/api/v1/menu \
#   -H "Authorization: Bearer mi-token"

# Response 200:
# {
#   "data": [
#     {
#       "id": "01HX6G...",
#       "name": "Platos principales",
#       "position": 1,
#       "products": [
#         {
#           "id": "01HX6F...",
#           "name": "Bandeja Paisa",
#           "description": "Fríjoles, chicharrón, chorizo...",
#           "price": "28000.00",
#           "available": true
#         }
#       ]
#     }
#   ],
#   "meta": { "total_products": 24, "last_synced_at": "2026-04-01T10:00:00.000Z" }
# }


# ── POST /api/v1/orders ───────────────────────────────────────────
# curl -X POST http://localhost:3000/api/v1/orders \
#   -H "Authorization: Bearer mi-token" \
#   -H "Content-Type: application/json" \
#   -d '{
#     "order": {
#       "table_id": "01HX6D...",
#       "waiter_name": "Carlos",
#       "items": [
#         { "product_id": "01HX6F...", "quantity": 2, "notes": "Sin chicharrón" },
#         { "product_id": "01HX6H...", "quantity": 1, "notes": null }
#       ]
#     }
#   }'

# Response 201:
# {
#   "data": {
#     "id": "01HX6B...",
#     "table": { "id": "01HX6D...", "number": "1", "label": "Ventana" },
#     "status": "open",
#     "waiter_name": "Carlos",
#     "subtotal": "84000.00",
#     "tax": "15960.00",
#     "total": "99960.00",
#     "notes": null,
#     "opened_at": "2026-04-01T14:30:00.000Z",
#     "closed_at": null,
#     "synced": false,
#     "sync_status": "pending",
#     "items": [
#       {
#         "id": "01HX6E...",
#         "product_name": "Bandeja Paisa",
#         "unit_price": "28000.00",
#         "quantity": 2,
#         "subtotal": "56000.00",
#         "notes": "Sin chicharrón",
#         "status": "pending"
#       }
#     ]
#   }
# }


# ── POST /api/v1/orders/:id/close ────────────────────────────────
# curl -X POST http://localhost:3000/api/v1/orders/01HX6B.../close \
#   -H "Authorization: Bearer mi-token" \
#   -H "Content-Type: application/json" \
#   -d '{ "payment_method": "cash" }'

# Response 200:
# {
#   "data": {
#     "id": "01HX6B...",
#     "status": "closed",
#     "total": "99960.00",
#     "closed_at": "2026-04-01T15:10:00.000Z",
#     "synced": false,
#     "sync_status": "pending"
#   }
# }


# ── GET /api/v1/kds/queue ─────────────────────────────────────────
# curl http://localhost:3000/api/v1/kds/queue \
#   -H "Authorization: Bearer mi-token"

# Response 200:
# {
#   "data": [
#     {
#       "id": "01HX6E...",
#       "order_id": "01HX6B...",
#       "table_number": "1",
#       "product_name": "Bandeja Paisa",
#       "quantity": 2,
#       "notes": "Sin chicharrón",
#       "status": "pending",
#       "waiting_since": "2026-04-01T14:30:00.000Z",
#       "waiting_minutes": 8
#     }
#   ]
# }


# ── POST /api/v1/kds/items/:id/ready ─────────────────────────────
# curl -X POST http://localhost:3000/api/v1/kds/items/01HX6E.../ready \
#   -H "Authorization: Bearer mi-token"

# Response 200:
# { "data": { "id": "01HX6E...", "status": "ready" } }


# ── PATCH /api/v1/orders/:order_id/items/:id/status ──────────────
# curl -X PATCH \
#   http://localhost:3000/api/v1/orders/01HX6B.../items/01HX6E.../status \
#   -H "Authorization: Bearer mi-token" \
#   -H "Content-Type: application/json" \
#   -d '{ "status": "served" }'

# Response 200:
# { "data": { "id": "01HX6E...", "status": "served", ... } }
