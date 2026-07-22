# Shooter Roguelike — con NPCs inteligentes

Top-down shooter roguelike donde avanzas por pisos de un dungeon generado
proceduralmente. En cada piso hay NPCs (mercaderes, prisioneros, aliados dudosos)
con los que conversas en **lenguaje natural**: los diálogos no están scriptados,
se generan en tiempo real con la **Claude API**. Los NPCs recuerdan lo que hiciste
en la run, reaccionan a tus decisiones y pueden darte misiones emergentes.

Referentes de jugabilidad: *Enter the Gungeon* y *Hades* (simplificados).

> 🚧 Proyecto en desarrollo — portafolio personal. Objetivo: build web publicada en itch.io.

---

## Estado

**Mes 1 — Base del shooter** (en curso)

- ✅ Movimiento top-down (8 direcciones, apuntado al ratón)
- ✅ Disparo con cadencia de fuego
- ✅ Dos tipos de enemigo: **Perseguidor** (melee) y **Tirador** (a distancia)
- ✅ Vida del jugador, i-frames, muerte y reinicio
- ✅ HUD y menú principal (estética retro-moderna)
- ⬜ Cámara con suavizado
- ⬜ Generación procedural de salas (BSP)

**Mes 2 — Integración de IA** · **Mes 3 — Pulido y deploy** → pendientes.

---

## Controles

| Acción | Tecla |
|---|---|
| Moverse | `WASD` / Flechas |
| Apuntar | Ratón |
| Disparar | Clic izquierdo |
| Interactuar | `E` |
| Reiniciar / Menú (al morir) | `R` / `Esc` |

---

## Stack

- **Motor:** Godot 4.7 (GDScript)
- **IA / diálogos:** Claude API
- **Deploy previsto:** itch.io (build HTML5)

---

## Cómo ejecutar

Requiere [Godot 4.7+](https://godotengine.org).

```bash
godot --path .          # ejecuta el juego
godot -e --path .       # abre el editor
```

O abre `project.godot` desde el editor de Godot.
