# Item assets

Los sprites se resuelven mediante `src/infrastructure/assets/asset_registry.gd`.

- `pickups/`: consumibles del mundo.
- `rewards/`: objetos pasivos/recompensas.

Los SVG actuales son assets base reemplazables. Se pueden sustituir por PNG/WebP/SVG definitivos conservando el mismo ID en el registro, sin tocar gameplay, hitboxes ni stats.
