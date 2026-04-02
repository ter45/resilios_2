# ══════════════════════════════════════════════════════════════════
#  ResiliOS — Crear Issues desde PowerShell
#  Uso: .\scripts\create_issues.ps1
# ══════════════════════════════════════════════════════════════════

$REPO = "ter45/resilios"

# Obtener milestones
$milestones = gh api repos/$REPO/milestones | ConvertFrom-Json
$M1 = ($milestones | Where-Object { $_.title -like "Fase 1*" }).number
$M2 = ($milestones | Where-Object { $_.title -like "Fase 2*" }).number
$M3 = ($milestones | Where-Object { $_.title -like "Fase 3*" }).number
$M4 = ($milestones | Where-Object { $_.title -like "Fase 4*" }).number
$M5 = ($milestones | Where-Object { $_.title -like "Fase 5*" }).number

Write-Host "Milestones: F1=$M1 F2=$M2 F3=$M3 F4=$M4 F5=$M5" -ForegroundColor Cyan

function New-Issue($title, $body, $labels, $milestone) {
    $existing = gh issue list --repo $REPO --search "`"$title`"" --json number | ConvertFrom-Json
    if ($existing.Count -gt 0) {
        Write-Host "[SKIP] Ya existe: $title" -ForegroundColor Yellow
        return
    }
    gh issue create --repo $REPO `
        --title $title `
        --body $body `
        --label $labels `
        --milestone $milestone | Out-Null
    Write-Host "[OK] $title" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

# ══ FASE 1 ══════════════════════════════════════════════════════
Write-Host "`n══ Fase 1 — Fundamentos ══" -ForegroundColor Magenta

New-Issue "[WP-1.2] Entorno Docker Edge local" `
"## Objetivo
Levantar el nodo Edge completo con un solo comando.

## Criterios de aceptacion
- [ ] docker compose up levanta: edge_api, sync_agent, edge_web, edge_kds
- [ ] Todos los servicios tienen healthcheck definido
- [ ] Stack levanta en menos de 60 segundos en Raspberry Pi 4
- [ ] .env.example documentado
- [ ] GET /health retorna 200" `
"type:story,priority:critical,epic:onboarding" $M1

New-Issue "[WP-1.3] Entorno Cloud (Rails 8 + PostgreSQL)" `
"## Objetivo
Setup del backend centralizado SaaS.

## Criterios de aceptacion
- [ ] Rails 8 API-only inicializado en cloud/
- [ ] PostgreSQL conectado y migraciones base
- [ ] Kamal 2 configurado para deploy a staging
- [ ] Variables de entorno en .env.example
- [ ] CI ejecuta tests contra PostgreSQL real" `
"type:story,priority:critical,epic:cloud" $M1

New-Issue "[WP-1.4] Autenticacion multi-tenant" `
"## Objetivo
Cada restaurante tiene su cuenta aislada. Nodos Edge vinculados via token.

## Criterios de aceptacion
- [ ] Modelo Restaurant/Tenant con aislamiento de datos
- [ ] Tokens de vinculacion Edge-Cloud (uso unico, expiran 24h)
- [ ] JWT para autenticacion de requests Edge al Cloud
- [ ] Rotacion de token despues del primer uso
- [ ] Test: un nodo no accede a datos de otro tenant" `
"type:story,priority:critical,epic:cloud" $M1

New-Issue "[WP-1.5] GitHub Projects — tablero Kanban y DoD" `
"## Objetivo
Sistema de gestion del proyecto operativo para el equipo.

## Criterios de aceptacion
- [ ] GitHub Project con columnas: Backlog / Ready / In Progress / In Review / Done
- [ ] Todos los Issues del WBS creados y asignados a milestone
- [ ] Labels configurados segun documento de gestion
- [ ] Definition of Done publicada en wiki
- [ ] Template de PR con checklist DoD" `
"type:story,priority:high" $M1

# ══ FASE 2 ══════════════════════════════════════════════════════
Write-Host "`n══ Fase 2 — Core Offline ══" -ForegroundColor Magenta

New-Issue "[WP-2.1] Modelo de datos Edge (SQLite + ULIDs)" `
"## Objetivo
Esquema de base de datos local con soporte completo para operacion offline.

## Criterios de aceptacion
- [ ] Entidades: Order, OrderItem, Table, Product, Category, SyncOperation
- [ ] Todos los IDs son ULIDs (no autoincrement)
- [ ] SQLite en WAL mode
- [ ] Migraciones Rails para schema completo
- [ ] Indices en sync_operations(synced_at, status)" `
"type:story,priority:critical,epic:offline,needs-chaos-test" $M2

New-Issue "[WP-2.2] API local REST (Rails API-only)" `
"## Objetivo
El corazon del nodo Edge. Opera sin internet, responde en menos de 200ms.

## Criterios de aceptacion
- [ ] Endpoints CRUD: /orders, /order_items, /tables, /products
- [ ] POST /orders genera SyncOperation en la misma transaccion
- [ ] Respuesta menor a 200ms en Raspberry Pi 4
- [ ] Funciona sin ninguna variable de red
- [ ] Tests unitarios con cobertura mayor al 80%
- [ ] Probado con red completamente desconectada" `
"type:story,priority:critical,epic:offline,offline-validated,needs-chaos-test" $M2

New-Issue "[WP-2.3] Interfaz POS — React PWA" `
"## Objetivo
Interfaz principal del mesero. Instalable en tablet. Funciona sin internet.

## Criterios de aceptacion
- [ ] Service Worker con estrategia offline-first
- [ ] Pantalla de mesas: libre / ocupada / con pedido
- [ ] Flujo completo: mesa -> productos -> confirmacion -> KDS
- [ ] Indicador de conectividad: verde / amarillo / rojo
- [ ] Instalable como PWA en Android e iOS
- [ ] Compatible con tablets Android 8+, 2GB RAM" `
"type:story,priority:critical,epic:offline" $M2

New-Issue "[WP-2.4] KDS — Kitchen Display System" `
"## Objetivo
Pantalla de cocina en LAN. Recibe pedidos sin internet.

## Criterios de aceptacion
- [ ] Pedidos en tiempo real via WebSocket local (LAN)
- [ ] Pedido llega al KDS en menos de 2 segundos
- [ ] Boton Listo marca el plato como preparado
- [ ] Funciona completamente sin internet
- [ ] Optimizado para pantalla tactil de cocina" `
"type:story,priority:critical,epic:offline,offline-validated" $M2

New-Issue "[WP-2.5] Dashboard de estado de conectividad" `
"## Objetivo
Visibilidad del estado del sistema para el administrador del local.

## Criterios de aceptacion
- [ ] Indicador en tiempo real: online / offline / sincronizando
- [ ] Contador de pedidos pendientes de sincronizacion
- [ ] Timestamp del ultimo sync exitoso
- [ ] Visible desde la pantalla principal del POS
- [ ] Notificacion cuando la conexion se restaura" `
"type:story,priority:high,epic:offline" $M2

New-Issue "[WP-2.6] Impresion local en LAN" `
"## Objetivo
Impresion de tickets sin internet.

## Criterios de aceptacion
- [ ] Integracion con impresoras termicas via ESC/POS en LAN
- [ ] Impresion en menos de 3 segundos
- [ ] No requiere internet en ningun paso
- [ ] Compatible con Epson TM-T20, Star TSP100, genericas ESC/POS
- [ ] Manejo de error si la impresora no esta disponible" `
"type:story,priority:medium,epic:offline" $M2

# ══ FASE 3 ══════════════════════════════════════════════════════
Write-Host "`n══ Fase 3 — Motor de Sincronizacion ══" -ForegroundColor Magenta

New-Issue "[WP-3.1] Outbox Pattern — Operation Log" `
"## Objetivo
Cola de operaciones inmutable que garantiza zero data loss.

## Criterios de aceptacion
- [ ] Tabla sync_operations: id ULID, operation_type, entity_type, entity_id, payload JSON, status, created_at
- [ ] Toda mutacion crea SyncOperation en la MISMA transaccion
- [ ] Log es append-only (solo se marca synced)
- [ ] Test de caos: corte de red durante pedido sin perdida de datos
- [ ] Insertar SyncOperation agrega menos de 5ms por operacion" `
"type:story,priority:critical,epic:sync,needs-chaos-test" $M3

New-Issue "[WP-3.2] Sync Agent — cliente Edge" `
"## Objetivo
Proceso en background que sincroniza automaticamente al restaurarse internet.

## Criterios de aceptacion
- [ ] Detecta restauracion de conexion en menos de 10 segundos
- [ ] Procesa cola SyncOperations en orden cronologico (ULID ordering)
- [ ] Retry con exponential backoff en error de red
- [ ] Idempotente: reenviar la misma operacion no crea duplicados
- [ ] Test: sync despues de 2h offline con 500 pedidos acumulados" `
"type:story,priority:critical,epic:sync,needs-chaos-test" $M3

New-Issue "[WP-3.3] Sync Engine — servidor Cloud" `
"## Objetivo
Endpoint en Cloud que recibe operaciones del Sync Agent con garantia de idempotencia.

## Criterios de aceptacion
- [ ] POST /api/v1/sync/operations acepta batch de operaciones
- [ ] Idempotencia garantizada por ULID
- [ ] Aplica operaciones en orden de ULID timestamp
- [ ] Responde con lista de operaciones rechazadas y razon
- [ ] Rate limiting: 1000 operaciones por request, 10 req/min por nodo" `
"type:story,priority:critical,epic:sync" $M3

New-Issue "[WP-3.4] Politicas de resolucion de conflictos" `
"## Objetivo
Resolucion automatica cuando dos nodos modifican el mismo dato offline.

## Politicas por entidad
- Orders: last-write-wins (basado en updated_at del ULID)
- OrderItems: merge (union de items de ambas versiones)
- Payments: server-authoritative (Cloud siempre gana)
- Products/Menu: server-authoritative

## Criterios de aceptacion
- [ ] Cada politica implementada y documentada
- [ ] Log de conflictos resueltos en panel admin
- [ ] Test para cada politica con escenario real
- [ ] Sin perdida silenciosa de datos" `
"type:story,priority:critical,epic:sync" $M3

New-Issue "[WP-3.5] Chaos Engineering — test suite offline" `
"## Objetivo
Suite de tests que simula fallas de red durante operaciones criticas.

## Escenarios
- [ ] Corte de red durante creacion de pedido
- [ ] Corte durante sincronizacion en curso
- [ ] Reconexion despues de 2h offline con 500 operaciones en cola
- [ ] Fallo intermitente cada 5 segundos
- [ ] Reinicio del nodo Edge durante sync
- [ ] Conflicto de 50 operaciones simultaneas

## Criterios de aceptacion
- [ ] Todos los escenarios pasan: zero data loss
- [ ] Tests corren en CI en ci-edge.yml" `
"type:story,priority:critical,epic:sync,needs-chaos-test" $M3

New-Issue "[WP-3.6] Monitoreo de sincronizacion (Cloud Dashboard)" `
"## Objetivo
Visibilidad completa del estado de todos los nodos Edge desde la nube.

## Criterios de aceptacion
- [ ] Lista de nodos: estado, ultimo sync, operaciones en cola, errores
- [ ] Alerta por email si un nodo lleva mas de 2h sin sincronizar
- [ ] Grafico de latencia de sync por nodo (ultimas 24h)
- [ ] Log de conflictos resueltos por restaurante
- [ ] API endpoint para que el Sync Agent reporte su estado" `
"type:story,priority:high,epic:sync" $M3

# ══ FASE 4 ══════════════════════════════════════════════════════
Write-Host "`n══ Fase 4 — Cloud SaaS y Pagos ══" -ForegroundColor Magenta

New-Issue "[WP-4.1] Portal web de administracion" `
"## Objetivo
Dashboard completo para que el dueno gestione su negocio desde la nube.

## Criterios de aceptacion
- [ ] Login multi-tenant con sesion persistente
- [ ] Dashboard: ventas del dia, top productos, grafico por hora
- [ ] Historial de pedidos con filtros por fecha, mesa, mesero
- [ ] Estado de conectividad del nodo Edge en tiempo real
- [ ] Reportes exportables a CSV" `
"type:story,priority:high,epic:cloud" $M4

New-Issue "[WP-4.2] Integracion Stripe — Facturacion SaaS" `
"## Objetivo
El cobro del SaaS es completamente automatizado.

## Criterios de aceptacion
- [ ] Planes de suscripcion por volumen de pedidos/mes
- [ ] Checkout de Stripe Billing integrado
- [ ] Webhook: pago exitoso activa licencia del nodo
- [ ] Webhook: pago fallido notifica con periodo de gracia 7 dias
- [ ] Portal Stripe para gestion de factura y tarjeta
- [ ] Tests en sandbox con todos los escenarios de pago" `
"type:story,priority:high,epic:cloud" $M4

New-Issue "[WP-4.3] Onboarding automatizado" `
"## Objetivo
Un nuevo restaurante opera el mismo dia de pago, sin soporte manual.

## Flujo objetivo
1. Dueno paga en Stripe
2. Recibe email con credenciales y docker-compose.yml pre-configurado
3. Tecnico ejecuta docker compose up
4. Escanea QR, nodo vinculado en menos de 5 minutos
5. Carga menu basico, sistema operativo

## Criterios de aceptacion
- [ ] Flujo completo sin intervencion humana de ResiliOS
- [ ] Email en menos de 2 minutos post-pago
- [ ] QR expira en 24h y es de un solo uso
- [ ] Tiempo total de onboarding menor a 30 minutos" `
"type:story,priority:high,epic:onboarding" $M4

New-Issue "[WP-4.4] Gestion de menu desde la nube" `
"## Objetivo
El dueno actualiza el menu en la nube y se sincroniza a todos sus nodos Edge.

## Criterios de aceptacion
- [ ] CRUD de categorias y productos en portal Cloud
- [ ] Precios, nombres e imagenes editables
- [ ] Sincronizacion descendente Cloud a Edge en menos de 5 minutos
- [ ] Edge opera con menu anterior mientras no hay internet
- [ ] Soporte para marcar productos como no disponibles" `
"type:story,priority:medium,epic:cloud" $M4

New-Issue "[WP-4.5] Reportes y analytics" `
"## Objetivo
El dueno toma decisiones basadas en datos de sus ventas.

## Criterios de aceptacion
- [ ] Ventas por hora del dia (heatmap)
- [ ] Top 10 productos por periodo
- [ ] Comparativa ventas: periodos online vs offline
- [ ] Exportacion a CSV de cualquier reporte
- [ ] Datos actualizados con cada ciclo de sincronizacion" `
"type:story,priority:medium,epic:cloud" $M4

# ══ FASE 5 ══════════════════════════════════════════════════════
Write-Host "`n══ Fase 5 — Go-to-Market ══" -ForegroundColor Magenta

New-Issue "[WP-5.1] Agente de soporte con IA (Claude API)" `
"## Objetivo
El soporte de primer nivel es automatico via Claude API.

## Criterios de aceptacion
- [ ] Nodo Edge envia telemetria: errores, latencia, estado sync, version
- [ ] Agente analiza logs via Claude API y genera diagnostico en espanol
- [ ] Casos cubiertos: nodo offline mas de 2h, sync fallando, disco lleno, error auth
- [ ] Diagnostico enviado en menos de 5 minutos del problema
- [ ] Escala a humano si confianza es menor al 85%" `
"type:story,priority:high,epic:cloud" $M5

New-Issue "[WP-5.2] Bot de soporte WhatsApp Business" `
"## Objetivo
Soporte accesible en el canal preferido de LATAM, disponible 24/7.

## Criterios de aceptacion
- [ ] WhatsApp Business API configurado
- [ ] Bot responde consultas comunes: estado del sistema, ultimo sync, reiniciar nodo
- [ ] Escalado a humano con transcripcion del historial
- [ ] Tiempo de respuesta del bot menor a 30 segundos
- [ ] Disponible solo en espanol" `
"type:story,priority:medium,epic:cloud" $M5

New-Issue "[WP-5.3] Documentacion tecnica de instalacion" `
"## Objetivo
Cualquier tecnico puede instalar ResiliOS sin llamar a soporte.

## Entregables
- [ ] Guia de instalacion paso a paso (markdown + video)
- [ ] Requisitos minimos de hardware documentados
- [ ] Troubleshooting de los 10 errores mas comunes
- [ ] Guia de actualizacion del nodo Edge
- [ ] FAQ para duenos sin tecnicismos" `
"type:story,priority:high,epic:onboarding" $M5

New-Issue "[WP-5.4] Programa piloto — Bundle ISP + ResiliOS" `
"## Objetivo
Validar el canal de distribucion ISP con restaurantes clientes reales.

## Criterios de aceptacion
- [ ] 3 restaurantes clientes del ISP instalados en produccion
- [ ] Feedback recopilado: encuesta post-instalacion y entrevistas
- [ ] Issues criticos documentados y resueltos
- [ ] Metricas: uptime del nodo, ciclos sync, pedidos procesados offline
- [ ] Pricing validado con los pilotos" `
"type:story,priority:critical,epic:onboarding" $M5

New-Issue "[WP-5.5] Lanzamiento MVP y primer MRR" `
"## Objetivo
ResiliOS en produccion con al menos 1 cliente de pago activo.

## Criterios de aceptacion
- [ ] Landing page publicada con propuesta de valor clara
- [ ] Pricing definido con al menos 2 planes
- [ ] Al menos 1 restaurante con suscripcion Stripe activa
- [ ] MRR mayor a cero al cierre del mes de lanzamiento
- [ ] Retrospectiva de proyecto documentada" `
"type:story,priority:critical" $M5

# ══ RESUMEN ══════════════════════════════════════════════════════
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║   Issues creados exitosamente            ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Issues     https://github.com/$REPO/issues" -ForegroundColor Green
Write-Host "  Milestones https://github.com/$REPO/milestones" -ForegroundColor Green
Write-Host ""
