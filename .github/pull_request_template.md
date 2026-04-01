## Descripción

<!-- Qué cambia este PR y por qué. Máximo 3 oraciones. -->

Closes #<!-- número del Issue -->

---

## Tipo de cambio

- [ ] `feat` — Nueva funcionalidad
- [ ] `fix` — Corrección de bug
- [ ] `test` — Tests (sin cambio de lógica)
- [ ] `docs` — Documentación
- [ ] `chore` — Mantenimiento / dependencias
- [ ] `refactor` — Refactorización sin cambio de comportamiento

---

## Definition of Done — Checklist

### Base (toda historia)
- [ ] El código está en rama `feature/` o `fix/` con este PR apuntando a `develop`
- [ ] Al menos 1 peer review aprobado antes del merge
- [ ] Tests unitarios cubren la lógica de negocio modificada (cobertura > 80% en archivos tocados)
- [ ] El pipeline de CI pasa: lint ✅ tests ✅ build Docker ✅
- [ ] Cada criterio de aceptación del Issue está verificado y marcado abajo

### Si toca el flujo de pedidos (Edge)
- [ ] Escenario **offline** probado manualmente con red desconectada
- [ ] Respuesta del API local < 200ms bajo carga mínima
- [ ] Label `offline-validated` agregado al Issue

### Si toca sincronización
- [ ] Ciclo completo **offline → sync → cloud** probado en staging
- [ ] No genera duplicados (verificado via ULID + idempotencia)
- [ ] Política de resolución de conflictos documentada si aplica

### Documentación
- [ ] PR description explica cómo probar manualmente
- [ ] README o docs actualizados si hay cambios en setup o API
- [ ] CHANGELOG.md actualizado (si es feat o fix relevante)

---

## Criterios de aceptación del Issue

<!-- Copia los criterios del Issue y marca cada uno -->

- [ ] ...
- [ ] ...

---

## Cómo probar manualmente

```bash
# Pasos para reproducir el escenario en local
```

---

## Screenshots / evidencia (si aplica)

<!-- Captura de pantalla, log, o registro de la prueba offline -->
