# Binding of Ismael — Clean Architecture para Godot 4

Este proyecto usa una Clean Architecture pragmática. El objetivo es separar reglas de juego, casos de uso, infraestructura y presentación sin pelear contra el modelo de escenas/nodos de Godot.

## Capas

- `src/domain/`: estado y reglas puras del juego. No conoce HUD, escenas ni almacenamiento.
- `src/application/`: casos de uso que coordinan reglas de dominio: economía, pickups y recompensas.
- `src/infrastructure/`: carga de assets y persistencia local.
- `src/presentation/`: adaptadores/controladores que conectan Godot con las capas internas.
- `scripts/`: presentación heredada. Se mantiene temporalmente para conservar compatibilidad mientras la migración avanza.
- `assets/`: recursos visuales. La lógica nunca debe depender del dibujo concreto de un objeto.

## Regla de dependencias

La dirección deseada es Presentation -> Application -> Domain. Infrastructure implementa detalles utilizados por Presentation/Application. Domain no debe importar scripts de UI, escenas ni archivos de usuario.

## Puente legado

`src/presentation/game/main_controller.gd` hereda temporalmente de `scripts/main.gd`. Centraliza catálogo de objetos, economía y recompensas en las capas nuevas manteniendo variables y métodos antiguos para no romper HUD, tienda, saves ni escenas existentes.

Cuando todos los sistemas estén migrados, `scripts/main.gd` podrá retirarse sin modificar las reglas de dominio.

## Assets

`IsmaelAssetRegistry` es el único punto de resolución de sprites de objetos. Pickups y recompensas deben pedir su textura por ID semántico (`coin`, `vida`, `perforante`, etc.). Si falta un asset, la presentación conserva un fallback procedimental visible para que nunca exista un objeto recogible invisible.

## Principios de cambio

1. Un cambio visual no modifica stats ni colisiones.
2. Un cambio de balance no modifica sprites ni HUD.
3. Persistencia y archivos `user://` viven en Infrastructure.
4. Los sistemas externos deben usar métodos públicos del controlador antes que leer/escribir variables privadas.
5. Cada migración debe mantener el APK actualizable y pasar el build Android antes de eliminar compatibilidad heredada.
