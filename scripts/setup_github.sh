#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
#  ResiliOS — GitHub Projects Setup Script
#  Crea el repositorio, labels, milestones, Issues y el tablero
#  Kanban completo via GitHub API y GitHub CLI.
#
#  Requisitos:
#    - GitHub CLI (gh) instalado y autenticado: gh auth login
#    - jq instalado: sudo apt install jq / brew install jq
#
#  Uso:
#    chmod +x scripts/setup_github.sh
#    ./scripts/setup_github.sh
#
#  Variables de entorno opcionales:
#    GITHUB_ORG   — organización (default: tu usuario)
#    REPO_NAME    — nombre del repo (default: resilios)
#    REPO_PRIVATE — true/false (default: true)
# ══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colores para output ────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()    { echo -e "\n${PURPLE}══ $1 ══${NC}"; }

# ── Verificar dependencias ─────────────────────────────────────────
command -v gh  >/dev/null 2>&1 || error "GitHub CLI no encontrado. Instala: https://cli.github.com"
command -v jq  >/dev/null 2>&1 || error "jq no encontrado. Instala: sudo apt install jq"
gh auth status >/dev/null 2>&1 || error "No autenticado en GitHub CLI. Ejecuta: gh auth login"

# ── Configuración ──────────────────────────────────────────────────
GITHUB_USER=$(gh api user --jq '.login')
GITHUB_ORG="${GITHUB_ORG:-$GITHUB_USER}"
REPO_NAME="${REPO_NAME:-resilios}"
REPO_PRIVATE="${REPO_PRIVATE:-true}"
REPO_FULL="$GITHUB_ORG/$REPO_NAME"

echo -e "\n${PURPLE}╔══════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║   ResiliOS — GitHub Projects Setup       ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════╝${NC}"
echo -e "  Repositorio : ${GREEN}$REPO_FULL${NC}"
echo -e "  Privado     : $REPO_PRIVATE"
echo -e "  Usuario GH  : $GITHUB_USER"
echo ""
read -p "¿Continuar? (s/N) " confirm
[[ "$confirm" =~ ^[sS]$ ]] || { echo "Abortado."; exit 0; }

# ══════════════════════════════════════════════════════════════════
# PASO 1 — Crear repositorio
# ══════════════════════════════════════════════════════════════════
step "1/6 — Repositorio"

if gh repo view "$REPO_FULL" >/dev/null 2>&1; then
  warn "El repositorio $REPO_FULL ya existe. Omitiendo creación."
else
  VISIBILITY_FLAG="--private"
  [[ "$REPO_PRIVATE" == "false" ]] && VISIBILITY_FLAG="--public"

  gh repo create "$REPO_FULL" \
    $VISIBILITY_FLAG \
    --description "ResiliOS POS — Sistema SaaS de gestión de pedidos offline-first para restaurantes" \
    --gitignore Rails \
    --license MIT
  success "Repositorio $REPO_FULL creado."
fi

# ── Clonar y subir estructura base ────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "$REPO_ROOT/.git/config" ]]; then
  warn "Repositorio git ya inicializado. Omitiendo push inicial."
else
  cd "$REPO_ROOT"
  git init
  git add .
  git commit -m "chore: initial monorepo structure

- edge/: Nodo Edge local (Docker + Rails API + SQLite)
- cloud/: Backend SaaS centralizado (Rails + PostgreSQL)
- .github/: CI/CD workflows, PR template, Issue templates
- scripts/: Automatización de setup"

  git branch -M main
  git remote add origin "https://github.com/$REPO_FULL.git"
  git push -u origin main
  success "Estructura base del monorepo subida a GitHub."
fi

# ══════════════════════════════════════════════════════════════════
# PASO 2 — Labels
# ══════════════════════════════════════════════════════════════════
step "2/6 — Labels"

# Eliminar labels por defecto de GitHub
DEFAULT_LABELS=("bug" "documentation" "duplicate" "enhancement" "good first issue" "help wanted" "invalid" "question" "wontfix")
for label in "${DEFAULT_LABELS[@]}"; do
  gh label delete "$label" --repo "$REPO_FULL" --yes 2>/dev/null || true
done

create_label() {
  local name="$1" color="$2" desc="$3"
  gh label create "$name" \
    --repo "$REPO_FULL" \
    --color "$color" \
    --description "$desc" \
    --force 2>/dev/null
  success "Label: $name"
}

# Épicas
create_label "epic:offline"    "534AB7" "Historias del núcleo offline (E-01)"
create_label "epic:sync"       "BA7517" "Historias del motor de sincronización (E-02)"
create_label "epic:onboarding" "0F6E56" "Historias de instalación y setup (E-03)"
create_label "epic:cloud"      "993C1D" "Historias del portal SaaS cloud (E-04)"

# Tipos
create_label "type:story"      "2D1B6B" "Historia de usuario"
create_label "type:bug"        "E24B4A" "Defecto a corregir"
create_label "type:tech-debt"  "888780" "Deuda técnica planificada"
create_label "type:spike"      "5DCAA5" "Investigación técnica"

# Prioridades
create_label "priority:critical" "A32D2D" "Bloquea el sprint o el MVP"
create_label "priority:high"     "EF9F27" "Alta prioridad para el sprint actual"
create_label "priority:medium"   "B5D4F4" "Prioridad media"
create_label "priority:low"      "D3D1C7" "Baja prioridad"

# Estados especiales
create_label "offline-validated" "1D9E75" "Probado manualmente sin internet"
create_label "needs-chaos-test"  "F0997B" "Requiere test de caos antes de Done"
create_label "blocked"           "D85A30" "Bloqueado por dependencia externa"

# ══════════════════════════════════════════════════════════════════
# PASO 3 — Milestones (Fases del proyecto)
# ══════════════════════════════════════════════════════════════════
step "3/6 — Milestones"

create_milestone() {
  local title="$1" desc="$2" due="$3"
  gh api repos/"$REPO_FULL"/milestones \
    --method POST \
    --field title="$title" \
    --field description="$desc" \
    --field due_on="${due}T23:59:59Z" \
    --silent 2>/dev/null && success "Milestone: $title" || warn "Milestone ya existe: $title"
}

# Fechas relativas desde Abril 2026
create_milestone \
  "Fase 1 — Fundamentos y Setup" \
  "Monorepo, Docker Edge, Cloud base, Auth multi-tenant, GitHub Projects. WP-1.1 a WP-1.5" \
  "2026-04-28"

create_milestone \
  "Fase 2 — Core Offline (Nodo Edge)" \
  "Modelo de datos, API local, PWA React, KDS, Dashboard conectividad, Impresión LAN. WP-2.1 a WP-2.6" \
  "2026-06-23"

create_milestone \
  "Fase 3 — Motor de Sincronización" \
  "Outbox Pattern, Sync Agent, Sync Engine Cloud, Resolución de conflictos, Chaos Tests. WP-3.1 a WP-3.6" \
  "2026-08-18"

create_milestone \
  "Fase 4 — Cloud SaaS y Pagos" \
  "Portal admin, Stripe, Onboarding automatizado, Gestión de menú, Reportes. WP-4.1 a WP-4.5" \
  "2026-09-29"

create_milestone \
  "Fase 5 — Automatización y Go-to-Market" \
  "Agente IA, Bot WhatsApp, Documentación, Programa piloto ISP, Lanzamiento MVP. WP-5.1 a WP-5.5" \
  "2026-11-10"

# Obtener IDs de milestones para asignar a Issues
get_milestone_id() {
  gh api repos/"$REPO_FULL"/milestones --jq ".[] | select(.title | startswith(\"$1\")) | .number"
}

M1=$(get_milestone_id "Fase 1"); M2=$(get_milestone_id "Fase 2")
M3=$(get_milestone_id "Fase 3"); M4=$(get_milestone_id "Fase 4")
M5=$(get_milestone_id "Fase 5")

info "Milestone IDs: F1=$M1 F2=$M2 F3=$M3 F4=$M4 F5=$M5"

# ══════════════════════════════════════════════════════════════════
# PASO 4 — Issues (WPs + User Stories)
# ══════════════════════════════════════════════════════════════════
step "4/6 — Issues"

create_issue() {
  local title="$1" body="$2" labels="$3" milestone="$4"
  gh issue create \
    --repo "$REPO_FULL" \
    --title "$title" \
    --body "$body" \
    --label "$labels" \
    --milestone "$milestone" \
    --assignee "$GITHUB_USER" \
    2>/dev/null
  success "Issue: $title"
  sleep 0.5   # Evitar rate limiting
}

# ── FASE 1 ──────────────────────────────────────────────────────
create_issue \
  "[WP-1.1] Repositorio y estructura del monorepo" \
  "## Objetivo\nConfigurar el monorepo base del proyecto ResiliOS.\n\n## Criterios de aceptación\n- [ ] Repositorio GitHub creado con estructura edge/ y cloud/\n- [ ] Branch strategy documentada en README\n- [ ] .gitignore configurado para Rails y Docker\n- [ ] GitHub Actions CI base configurado (lint + test skeleton)\n- [ ] README.md con quickstart funcional\n\n## Convención de commit\n\`\`\`\nchore: initial monorepo structure\n\`\`\`" \
  "type:story,priority:critical" "$M1"

create_issue \
  "[WP-1.2] Entorno Docker Edge local" \
  "## Objetivo\nCualquier técnico puede levantar el nodo Edge completo con un solo comando.\n\n## Criterios de aceptación\n- [ ] \`docker compose up\` levanta edge_api, sync_agent, edge_web, edge_kds\n- [ ] Todos los servicios tienen healthcheck definido\n- [ ] El stack levanta en < 60 segundos en hardware mínimo (Raspberry Pi 4)\n- [ ] \`.env.example\` documentado con todas las variables necesarias\n- [ ] Endpoint \`GET /health\` retorna 200\n\n## Notas técnicas\nBase: Ruby 3.3-slim. SQLite con WAL mode. Volumen persistente para storage/." \
  "type:story,priority:critical,epic:onboarding" "$M1"

create_issue \
  "[WP-1.3] Entorno Cloud (Rails 8 + PostgreSQL)" \
  "## Objetivo\nSetup del backend centralizado SaaS.\n\n## Criterios de aceptación\n- [ ] Rails 8 API-only inicializado en cloud/\n- [ ] PostgreSQL conectado y migraciones base\n- [ ] Kamal 2 configurado para deploy a staging\n- [ ] Variables de entorno documentadas en .env.example\n- [ ] GitHub Actions pipeline ejecuta tests contra PostgreSQL real en CI" \
  "type:story,priority:critical,epic:cloud" "$M1"

create_issue \
  "[WP-1.4] Autenticación multi-tenant" \
  "## Objetivo\nCada restaurante tiene su cuenta aislada. Los nodos Edge se vinculan via token.\n\n## Criterios de aceptación\n- [ ] Modelo Restaurant/Tenant en Cloud con aislamiento de datos\n- [ ] Generación de tokens de vinculación Edge-Cloud (uso único, expiran en 24h)\n- [ ] JWT para autenticación de requests del Edge al Cloud\n- [ ] Rotación de token después del primer uso (seguridad)\n- [ ] Test: un nodo no puede acceder a datos de otro tenant" \
  "type:story,priority:critical,epic:cloud" "$M1"

create_issue \
  "[WP-1.5] GitHub Projects — tablero Kanban y DoD" \
  "## Objetivo\nConfigurar el sistema de gestión del proyecto para el equipo.\n\n## Criterios de aceptación\n- [ ] GitHub Project creado con columnas: Backlog / Ready / In Progress / In Review / Done\n- [ ] Todos los Issues del WBS están creados y asignados al milestone correspondiente\n- [ ] Labels configurados según el documento de gestión\n- [ ] Definition of Done publicada en el wiki del repo\n- [ ] Template de PR configurado con checklist DoD" \
  "type:story,priority:high" "$M1"

# ── FASE 2 ──────────────────────────────────────────────────────
create_issue \
  "[WP-2.1] Modelo de datos Edge (SQLite + ULIDs)" \
  "## Objetivo\nEsquema de base de datos local con soporte completo para operación offline.\n\n## Criterios de aceptación\n- [ ] Entidades: Order, OrderItem, Table, Product, Category, SyncOperation\n- [ ] Todos los IDs son ULIDs (no autoincrement integers)\n- [ ] SQLite configurado en WAL mode\n- [ ] Migraciones de Rails para el schema completo\n- [ ] Índices en sync_operations(synced_at, status) para performance del Sync Agent\n\n## Notas técnicas\nLibrería ULID: gem 'ulid-ruby'. WAL mode: PRAGMA journal_mode=WAL en database.yml." \
  "type:story,priority:critical,epic:offline,needs-chaos-test" "$M2"

create_issue \
  "[WP-2.2] API local REST (Rails API-only)" \
  "## Objetivo\nEl corazón del nodo Edge. Opera sin internet, responde en < 200ms.\n\n## Criterios de aceptación\n- [ ] Endpoints CRUD para: /orders, /order_items, /tables, /products\n- [ ] POST /orders genera SyncOperation en la misma transacción (Outbox Pattern)\n- [ ] Respuesta < 200ms bajo carga normal (benchmark en Raspberry Pi 4)\n- [ ] Funciona sin ninguna variable de red configurada\n- [ ] Tests unitarios con cobertura > 80% en controllers y models\n\n## Validación offline\n- [ ] Probado con red completamente desconectada" \
  "type:story,priority:critical,epic:offline,offline-validated,needs-chaos-test" "$M2"

create_issue \
  "[WP-2.3] Interfaz POS — React PWA" \
  "## Objetivo\nInterfaz principal del mesero. Instalable en tablet. Funciona sin internet.\n\n## Criterios de aceptación\n- [ ] Service Worker con estrategia offline-first (cache-first para assets, network-first para API)\n- [ ] Pantalla de mesas con estado visual (libre / ocupada / con pedido)\n- [ ] Flujo completo de toma de pedido: mesa → productos → confirmación → envío a KDS\n- [ ] Indicador de conectividad: verde (online) / amarillo (sync) / rojo (offline)\n- [ ] Instalable como PWA en Android e iOS\n- [ ] Funciona en tablets de bajo costo (Android 8+, 2GB RAM)" \
  "type:story,priority:critical,epic:offline" "$M2"

create_issue \
  "[WP-2.4] KDS — Kitchen Display System" \
  "## Objetivo\nPantalla de cocina en LAN. Recibe pedidos sin internet.\n\n## Criterios de aceptación\n- [ ] Pantalla muestra pedidos en tiempo real via WebSocket local (LAN)\n- [ ] Pedido llega a KDS en < 2 segundos después de confirmado por el mesero\n- [ ] Botón 'Listo' marca el plato como preparado\n- [ ] Funciona completamente sin internet (solo requiere LAN local)\n- [ ] Diseño optimizado para pantalla táctil de cocina (botones grandes, fondo oscuro)" \
  "type:story,priority:critical,epic:offline,offline-validated" "$M2"

create_issue \
  "[WP-2.5] Dashboard de estado de conectividad" \
  "## Objetivo\nVisibilidad del estado del sistema para el administrador del local.\n\n## Criterios de aceptación\n- [ ] Indicador en tiempo real: online / offline / sincronizando\n- [ ] Contador de pedidos pendientes de sincronización\n- [ ] Timestamp del último sync exitoso\n- [ ] Visible desde la pantalla principal del POS\n- [ ] Notificación cuando la conexión se restaura y el sync comienza" \
  "type:story,priority:high,epic:offline" "$M2"

create_issue \
  "[WP-2.6] Impresión local en LAN" \
  "## Objetivo\nImpresión de tickets de pedido sin internet.\n\n## Criterios de aceptación\n- [ ] Integración con impresoras térmicas via protocolo ESC/POS en red LAN\n- [ ] Impresión en < 3 segundos después de confirmar el pedido\n- [ ] No requiere internet en ningún paso\n- [ ] Compatible con: Epson TM-T20, Star TSP100, impresoras genéricas ESC/POS\n- [ ] Manejo de error si la impresora no está disponible (sin crash)" \
  "type:story,priority:medium,epic:offline" "$M2"

# ── FASE 3 ──────────────────────────────────────────────────────
create_issue \
  "[WP-3.1] Outbox Pattern — Operation Log" \
  "## Objetivo\nCola de operaciones inmutable que garantiza zero data loss durante desconexión.\n\n## Criterios de aceptación\n- [ ] Tabla sync_operations con: id (ULID), operation_type, entity_type, entity_id, payload (JSON), status, created_at\n- [ ] Toda mutación de datos crea una SyncOperation en la MISMA transacción de base de datos\n- [ ] El log es append-only (nunca se modifica, solo se marca como synced)\n- [ ] Test de caos: interrupción de red durante creación de pedido → no hay pérdida de datos al reconectar\n- [ ] Performance: insertar SyncOperation agrega < 5ms a cada operación" \
  "type:story,priority:critical,epic:sync,needs-chaos-test" "$M3"

create_issue \
  "[WP-3.2] Sync Agent — cliente Edge" \
  "## Objetivo\nProceso en background que sincroniza automáticamente cuando hay internet.\n\n## Criterios de aceptación\n- [ ] Detecta restauración de conexión en < 10 segundos\n- [ ] Procesa la cola de SyncOperations en orden cronológico (ULID ordering)\n- [ ] Retry con exponential backoff en caso de error de red\n- [ ] Idempotente: reenviar la misma operación no crea duplicados en Cloud\n- [ ] Actualiza el estado del Dashboard de conectividad en tiempo real\n- [ ] Test: sync después de 2 horas offline con 500 pedidos acumulados" \
  "type:story,priority:critical,epic:sync,needs-chaos-test" "$M3"

create_issue \
  "[WP-3.3] Sync Engine — servidor Cloud" \
  "## Objetivo\nEndpoint en Cloud que recibe las operaciones del Sync Agent con garantía de idempotencia.\n\n## Criterios de aceptación\n- [ ] POST /api/v1/sync/operations acepta batch de operaciones\n- [ ] Idempotencia garantizada por ULID (reenvíos ignorados silenciosamente)\n- [ ] Aplica operaciones en orden de ULID timestamp\n- [ ] Responde con lista de operaciones rechazadas y razón\n- [ ] Autenticación via node_token del restaurante\n- [ ] Rate limiting: máximo 1000 operaciones por request, 10 requests/minuto por nodo" \
  "type:story,priority:critical,epic:sync" "$M3"

create_issue \
  "[WP-3.4] Políticas de resolución de conflictos" \
  "## Objetivo\nCuando dos nodos modifican el mismo dato offline, el sistema resuelve sin intervención humana.\n\n## Políticas por entidad\n- Orders: last-write-wins (basado en updated_at del ULID)\n- OrderItems: merge (unión de items de ambas versiones)\n- Payments: server-authoritative (Cloud siempre gana)\n- Products/Menu: server-authoritative (Cloud siempre gana)\n\n## Criterios de aceptación\n- [ ] Cada política implementada y documentada\n- [ ] Log de conflictos resueltos visible en panel admin\n- [ ] Test para cada política con escenario de conflicto real\n- [ ] No hay pérdida silenciosa de datos (todo conflicto queda registrado)" \
  "type:story,priority:critical,epic:sync" "$M3"

create_issue \
  "[WP-3.5] Chaos Engineering — test suite offline" \
  "## Objetivo\nSuite de tests que simula escenarios de falla de red durante operaciones críticas.\n\n## Escenarios a cubrir\n- [ ] Corte de red durante creación de pedido\n- [ ] Corte durante sincronización en curso\n- [ ] Reconexión después de 2h offline con 500+ operaciones en cola\n- [ ] Fallo de red intermitente (conecta/desconecta cada 5 segundos)\n- [ ] Reinicio del nodo Edge durante sync\n- [ ] Conflicto de 50+ operaciones simultáneas\n\n## Criterios de aceptación\n- [ ] Todos los escenarios pasan: zero data loss\n- [ ] Tests corren en CI en la pipeline ci-edge.yml\n- [ ] Tiempo de recovery documentado para cada escenario" \
  "type:story,priority:critical,epic:sync,needs-chaos-test" "$M3"

create_issue \
  "[WP-3.6] Monitoreo de sincronización (Cloud Dashboard)" \
  "## Objetivo\nVisibilidad completa del estado de todos los nodos Edge desde la nube.\n\n## Criterios de aceptación\n- [ ] Vista de lista de nodos con: estado de conexión, último sync, operaciones en cola, errores recientes\n- [ ] Alerta por email si un nodo lleva > 2h sin sincronizar\n- [ ] Gráfico de latencia de sync por nodo (últimas 24h)\n- [ ] Log de conflictos resueltos por restaurante\n- [ ] API endpoint para que el Sync Agent reporte su estado" \
  "type:story,priority:high,epic:sync" "$M3"

# ── FASE 4 ──────────────────────────────────────────────────────
create_issue \
  "[WP-4.1] Portal web de administración" \
  "## Objetivo\nDashboard completo para que el dueño del restaurante gestione su negocio desde la nube.\n\n## Criterios de aceptación\n- [ ] Login multi-tenant con sesión persistente\n- [ ] Dashboard con ventas del día, top productos, gráfico por hora\n- [ ] Historial de pedidos con filtros por fecha, mesa, mesero\n- [ ] Estado de conectividad del nodo Edge en tiempo real\n- [ ] Vista de reportes exportable a CSV" \
  "type:story,priority:high,epic:cloud" "$M4"

create_issue \
  "[WP-4.2] Integración Stripe — Facturación SaaS" \
  "## Objetivo\nEl cobro del SaaS es completamente automatizado.\n\n## Criterios de aceptación\n- [ ] Planes de suscripción definidos (por volumen de pedidos/mes)\n- [ ] Checkout de Stripe Billing integrado\n- [ ] Webhook: pago exitoso → activa/renueva la licencia del nodo\n- [ ] Webhook: pago fallido → notificación y período de gracia de 7 días\n- [ ] Portal de cliente Stripe para gestión de factura y tarjeta\n- [ ] Test en modo sandbox con todos los escenarios de pago" \
  "type:story,priority:high,epic:cloud" "$M4"

create_issue \
  "[WP-4.3] Onboarding automatizado" \
  "## Objetivo\nUn nuevo restaurante puede empezar a operar el mismo día de pago, sin soporte manual.\n\n## Flujo objetivo\n1. Dueño paga en Stripe\n2. Recibe email con credenciales y link de descarga del docker-compose.yml pre-configurado\n3. Técnico ejecuta docker compose up\n4. Escanea QR → nodo vinculado en < 5 minutos\n5. Carga menú básico → sistema operativo\n\n## Criterios de aceptación\n- [ ] Flujo completo funciona sin intervención humana de parte de ResiliOS\n- [ ] Email de bienvenida con instrucciones en < 2 minutos post-pago\n- [ ] QR de vinculación expira en 24h y es de un solo uso\n- [ ] Tiempo total de onboarding < 30 minutos" \
  "type:story,priority:high,epic:onboarding" "$M4"

create_issue \
  "[WP-4.4] Gestión de menú desde la nube" \
  "## Objetivo\nEl dueño actualiza su menú en la nube y se sincroniza a todos sus nodos Edge.\n\n## Criterios de aceptación\n- [ ] CRUD de categorías y productos en portal Cloud\n- [ ] Precios, nombres e imágenes editables\n- [ ] Sincronización descendente (Cloud → Edge) en < 5 minutos\n- [ ] El Edge sigue operando con el menú anterior mientras no hay internet\n- [ ] Soporte para marcar productos como no disponibles temporalmente" \
  "type:story,priority:medium,epic:cloud" "$M4"

create_issue \
  "[WP-4.5] Reportes y analytics" \
  "## Objetivo\nEl dueño puede tomar decisiones de negocio basadas en datos de sus ventas.\n\n## Criterios de aceptación\n- [ ] Ventas por hora del día (heatmap)\n- [ ] Top 10 productos más vendidos por período\n- [ ] Comparativa ventas: períodos online vs offline\n- [ ] Exportación a CSV de cualquier reporte\n- [ ] Los datos se actualizan con cada ciclo de sincronización del nodo" \
  "type:story,priority:medium,epic:cloud" "$M4"

# ── FASE 5 ──────────────────────────────────────────────────────
create_issue \
  "[WP-5.1] Agente de soporte con IA (Claude API)" \
  "## Objetivo\nEl soporte de primer nivel es automático. Un agente analiza logs y genera diagnósticos.\n\n## Criterios de aceptación\n- [ ] El nodo Edge envía telemetría: errores, latencia, estado de sync, versión\n- [ ] El agente analiza los logs vía Claude API y genera diagnóstico en lenguaje natural\n- [ ] Diagnósticos comunes cubiertos: nodo offline > 2h, sync fallando, disco lleno, error de auth\n- [ ] El dueño recibe el diagnóstico vía email o WhatsApp en < 5 minutos del problema\n- [ ] Solo escala a soporte humano si el agente no puede resolver con > 85% de confianza" \
  "type:story,priority:high,epic:cloud" "$M5"

create_issue \
  "[WP-5.2] Bot de soporte WhatsApp Business" \
  "## Objetivo\nSoporte accesible en el canal preferido de LATAM, disponible 24/7.\n\n## Criterios de aceptación\n- [ ] WhatsApp Business API configurado\n- [ ] Bot responde consultas comunes: estado del sistema, último sync, cómo reiniciar el nodo\n- [ ] Escalado a humano con transcripción del historial cuando el bot no puede resolver\n- [ ] Tiempo de respuesta del bot < 30 segundos\n- [ ] Disponible en español únicamente (mercado objetivo)" \
  "type:story,priority:medium,epic:cloud" "$M5"

create_issue \
  "[WP-5.3] Documentación técnica de instalación" \
  "## Objetivo\nCualquier técnico puede instalar ResiliOS siguiendo la documentación, sin llamar a soporte.\n\n## Entregables\n- [ ] Guía de instalación paso a paso (markdown + video)\n- [ ] Requisitos mínimos de hardware documentados\n- [ ] Troubleshooting de los 10 errores más comunes\n- [ ] Guía de actualización del nodo Edge\n- [ ] FAQ para dueños de restaurantes (sin tecnicismos)" \
  "type:story,priority:high,epic:onboarding" "$M5"

create_issue \
  "[WP-5.4] Programa piloto — Bundle ISP + ResiliOS" \
  "## Objetivo\nValidar el canal de distribución ISP con restaurantes clientes reales.\n\n## Criterios de aceptación\n- [ ] 3 restaurantes clientes del ISP instalados y operando en producción\n- [ ] Feedback recopilado: encuesta post-instalación y entrevistas\n- [ ] Issues críticos de producción documentados y resueltos\n- [ ] Métricas capturadas: uptime del nodo, ciclos de sync, pedidos procesados offline\n- [ ] Decisión de pricing validada con los pilotos" \
  "type:story,priority:critical,epic:onboarding" "$M5"

create_issue \
  "[WP-5.5] Lanzamiento MVP y primer MRR" \
  "## Objetivo\nResiliOS está en producción con al menos 1 cliente de pago activo.\n\n## Criterios de aceptación\n- [ ] Landing page publicada con propuesta de valor clara\n- [ ] Pricing definido y publicado (al menos 2 planes)\n- [ ] Al menos 1 restaurante con suscripción Stripe activa\n- [ ] MRR > $0 al cierre del mes de lanzamiento\n- [ ] Retrospectiva de proyecto documentada: qué funcionó, qué no, siguiente fase" \
  "type:story,priority:critical" "$M5"

# ══════════════════════════════════════════════════════════════════
# PASO 5 — GitHub Project (tablero Kanban)
# ══════════════════════════════════════════════════════════════════
step "5/6 — GitHub Project (tablero Kanban)"

PROJECT_ID=$(gh project create \
  --owner "$GITHUB_ORG" \
  --title "ResiliOS POS — Roadmap MVP" \
  --format json 2>/dev/null | jq -r '.id' || echo "")

if [[ -z "$PROJECT_ID" ]]; then
  warn "No se pudo crear el Project via CLI (puede requerir permisos adicionales)."
  warn "Crea el Project manualmente en: https://github.com/$GITHUB_ORG?tab=projects"
  warn "Luego vincula todos los Issues al Project."
else
  success "GitHub Project creado (ID: $PROJECT_ID)"

  # Agregar todos los Issues al proyecto
  info "Agregando Issues al Project..."
  gh issue list --repo "$REPO_FULL" --limit 100 --json number --jq '.[].number' | \
  while read -r issue_num; do
    gh project item-add "$PROJECT_ID" \
      --owner "$GITHUB_ORG" \
      --url "https://github.com/$REPO_FULL/issues/$issue_num" \
      2>/dev/null && echo -n "." || echo -n "x"
  done
  echo ""
  success "Issues agregados al Project."
fi

# ══════════════════════════════════════════════════════════════════
# PASO 6 — Branch develop
# ══════════════════════════════════════════════════════════════════
step "6/6 — Branch develop"

cd "$REPO_ROOT" 2>/dev/null || true
if git show-ref --quiet refs/heads/develop 2>/dev/null; then
  warn "Branch develop ya existe."
else
  git checkout -b develop 2>/dev/null && \
  git push origin develop 2>/dev/null && \
  success "Branch develop creado y subido." || \
  warn "No se pudo crear branch develop (puede que el repo aún no esté clonado localmente)."
fi

# Configurar branch protection rules via API
gh api repos/"$REPO_FULL"/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["lint","test"]}' \
  --field enforce_admins=false \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null \
  --silent 2>/dev/null && \
  success "Branch protection en main configurado (require PR + 1 review)." || \
  warn "No se pudo configurar branch protection (requiere admin del repo)."

# ══════════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ══════════════════════════════════════════════════════════════════
echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║          ✅  Setup completado exitosamente           ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Repositorio${NC}  https://github.com/$REPO_FULL"
echo -e "  ${GREEN}Issues${NC}       https://github.com/$REPO_FULL/issues"
echo -e "  ${GREEN}Milestones${NC}   https://github.com/$REPO_FULL/milestones"
echo -e "  ${GREEN}Actions${NC}      https://github.com/$REPO_FULL/actions"
echo -e "  ${GREEN}Projects${NC}     https://github.com/$GITHUB_ORG?tab=projects"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo -e "  1. Abre el tablero en GitHub Projects y ajusta el orden del backlog"
echo -e "  2. Agrega los secrets de CI en Settings → Secrets:"
echo -e "     KAMAL_REGISTRY_PASSWORD, SSH_PRIVATE_KEY"
echo -e "  3. Ejecuta: cd edge && cp .env.example .env && docker compose up"
echo -e "  4. Asigna las issues de Fase 1 a los miembros del equipo"
echo ""
