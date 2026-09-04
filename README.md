# Binding of Ismael

Prototype roguelike 2D para Android inspirado en la estructura de los twin-stick dungeon shooters: salas cerradas, combate, proyectiles, enemigos, objetos y progresión procedural.

## Estado actual

Alpha técnica inicial en Godot 4:

- Movimiento con stick virtual izquierdo.
- Apuntado/disparo completamente independiente con stick virtual derecho.
- Multitouch: ambos sticks pueden mantenerse activos simultáneamente.
- Disparo continuo mientras se mantiene inclinado el stick derecho.
- Sala de prueba con límites y puertas provisionales.
- Cuatro enemigos perseguidores con vida y colisión.
- Proyectiles con daño.
- Controles de teclado para pruebas: WASD para movimiento y flechas para disparo.
- Renderizador Compatibility para priorizar compatibilidad Android.

## Arquitectura inicial

```text
scenes/
  main.tscn
scripts/
  main.gd
  player.gd
  projectile.gd
  enemy.gd
  virtual_stick.gd
```

## Próximos hitos

1. Sistema real de salas y puertas.
2. Cámara, HUD de vida y pickups.
3. Room templates y generación procedural de piso.
4. Enemigos con comportamientos distintos.
5. Sistema data-driven de ítems y modificadores.
6. Jefe y transición de piso.
7. Exportación Android automatizada mediante GitHub Actions.
8. Sustituir gráficos provisionales por arte original.

## Principio de control

Los dos sticks nunca comparten dirección. `move_input` y `aim_input` son vectores separados: el jugador puede desplazarse en una dirección mientras dispara simultáneamente hacia cualquier otra.
