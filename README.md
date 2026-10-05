# Binding of Ismael

Prototipo roguelike 2D para Android inspirado en la estructura de los *twin-stick dungeon shooters*: salas cerradas, combate, proyectiles, enemigos, objetos y progresión por pisos.

## Estado actual — 0.4.2-alpha

- Godot 4.3 + GDScript, en horizontal y con renderizador Compatibility para Android.
- Movimiento con stick virtual izquierdo y apuntado/disparo independiente con el derecho.
- Multitouch y disparo continuo: Ismael puede moverse en una dirección y disparar en otra.
- Salas con obstáculos, puertas bloqueadas durante el combate, cámara de recompensa y jefe de piso.
- Enemigos diferenciados:
  - perseguidor de contacto;
  - embestidor con ráfagas;
  - orbitador con disparos telegrafiados;
  - jefe con abanicos, anillos de proyectiles y segunda fase más rápida.
- Proyectiles enemigos diferenciados de las lágrimas del jugador y eliminados al limpiar o cambiar de sala.
- HUD de corazones, recursos, minimapa lineal y barra de vida del jefe.
- Pickups de corazón, moneda, bomba y llave.
- Recompensas de movimiento, cadencia, vida, curación, velocidad de proyectil y daño.
- Dos pisos jugables y reinicio del recorrido al ganar o perder.
- GitHub Actions genera un APK debug instalable en cada push a `main`.

## Arquitectura v2

```text
scenes/
  main.tscn
scripts/
  main.gd
  main_v2.gd
  player.gd
  enemy.gd
  projectile.gd
  enemy_projectile.gd
  room_visual.gd
  room_obstacle.gd
  room_door.gd
  pickup.gd
  reward_pedestal.gd
  health_hud.gd
  boss_hud.gd
  virtual_stick.gd
.github/workflows/
  android-debug.yml
  cleanup-artifacts.yml
export_presets.cfg
```

`main_v2.gd` conserva el gameplay existente y separa la presentación de sala, el HUD de jefe y los pedestales para continuar el refactor sin romper el prototipo.

## Próximos hitos

1. Sustituir el recorrido lineal por un mapa procedural ramificado.
2. Convertir ítems y modificadores a recursos data-driven.
3. Agregar más familias de enemigos, jefes y estados alterados.
4. Incorporar arte original animado, partículas, sonido y música.
5. Añadir menú inicial, pausa, ajustes y persistencia básica.

## APK de prueba

Cada push a `main` ejecuta el workflow **Android Debug APK**. Cuando termina correctamente, el artifact se publica como `Binding-of-Ismael-debug-apk` durante tres días.

## Principio de control

Los dos sticks nunca comparten dirección. `move_input` y `aim_input` son vectores separados para mantener movimiento y disparo realmente independientes.
