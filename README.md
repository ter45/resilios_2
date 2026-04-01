# ResiliOS POS

> Sistema SaaS de gestión de pedidos híbrido Edge/Cloud — offline-first para restaurantes.

[![CI Edge](https://github.com/TU_ORG/resilios/actions/workflows/ci-edge.yml/badge.svg)](https://github.com/TU_ORG/resilios/actions)
[![CI Cloud](https://github.com/TU_ORG/resilios/actions/workflows/ci-cloud.yml/badge.svg)](https://github.com/TU_ORG/resilios/actions)

## Arquitectura

```
resilios/
├── edge/          # Nodo local del restaurante (Rails API + SQLite)
├── cloud/         # Backend SaaS centralizado (Rails + PostgreSQL)
├── scripts/       # Automatización: setup GitHub Projects, deploy, etc.
└── .github/       # CI/CD, templates de PR e Issues
```

## Quickstart — Nodo Edge local

```bash
cd edge
cp .env.example .env          # Configura variables
docker compose up             # Levanta toda la pila local
```

El nodo Edge estará disponible en `http://localhost:3000`.
Escanea el QR en pantalla para vincular con tu cuenta en la nube.

## Quickstart — Cloud (desarrollo)

```bash
cd cloud
cp .env.example .env
bundle install
rails db:setup
rails server
```

## Branching Strategy

| Rama | Propósito |
|------|-----------|
| `main` | Producción — siempre deployable |
| `develop` | Integración continua de features |
| `feature/WP-X.X-descripcion` | Desarrollo de paquetes de trabajo |
| `fix/descripcion` | Corrección de bugs |

**Regla:** Nunca commit directo a `main`. Todo via PR con al menos 1 aprobación.

## Convención de commits

```
feat(edge): agregar endpoint de pedidos offline
fix(sync): corregir duplicados en resolución de conflictos
docs: actualizar guía de instalación
test(edge): agregar tests de caos para corte de red
chore: actualizar dependencias de Docker
```

## Documentación

- [Project Charter y WBS](docs/ResiliOS_Gestion_Proyecto.docx)
- [Arquitectura de sincronización](docs/sync-architecture.md)
- [Guía de instalación Edge](edge/INSTALL.md)
- [API Reference](cloud/API.md)

## Equipo

| Rol | Responsabilidad |
|-----|----------------|
| PM / Dev Lead | Jesús Telmo |
| Backend Edge | TBD |
| Backend Cloud | TBD |
| Frontend PWA | TBD |
| QA / DevOps | TBD |

---

*Construido sobre los principios de apalancamiento de código de Naval Ravikant.*
