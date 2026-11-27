# Fase 01 — baseline y contrato de calidad

Base de recuperación: f1482100130997a2e2ae59cb6e4dda87701c03e8 (Fase 10.2).
Rama de respaldo: backup/fase-10-2-base. No reescribir ni borrar esa referencia.

## Contratos protegidos
- Siete pisos y guardianes; cinco sellos originales y tres rutas.
- Multitouch independiente, mapa ampliable, controles editables, corazones azules.
- Tiendas, cofres, botín, pedestales, pactos, eventos y secretos; objetos y sinergias.
- Progreso histórico, desbloqueos, música de exploración y de guardianes.
- Identidad Android: com.loloscarprr.bindingofismael, arm64-v8a, versión creciente, certificado existente.

## Puertas de calidad
1. Importación headless sin errores.
2. Suite existente tests/ci_smoke.gd sin regresiones.
3. Suite tests/ci_baseline.gd: 280 mapas generados, conectividad pública, jefe alcanzable, sellos, economía y estado de cofres/botín. La semilla se registra al fallar, pero aún no permite reproducir exactamente la generación; se corregirá en una fase posterior.
4. Exportación Android con el certificado fijado y verificación del APK.
5. Prueba manual en Redmi 12 5G: actualizar sin desinstalar; comprobar historial y controles; iniciar partida, mantener ambos sticks y abrir mapa; entrar y regresar de una sala; abrir cofre y regresar; derrotar guardián, verificar música y avanzar piso; suspender/reanudar. Registrar FPS, tiempos de transición y errores. No declarar superada sin evidencia.

Comandos locales (Godot 4.3):
```sh
godot --headless --editor --quit
godot --headless --path . --script res://tests/ci_smoke.gd
godot --headless --path . --script res://tests/ci_baseline.gd
```

## Firma y distribución
La clave actual depende del caché de GitHub Actions. Un respaldo Git no incluye ese archivo ni los datos locales del teléfono. Conservar exactamente el certificado existente; no generar una clave sustituta. Antes de una publicación estable, el propietario debe conservar una copia cifrada y segura del keystore original fuera del caché y verificar su huella. Nunca publicar el keystore, contraseñas ni secretos en el repositorio o artifacts. Si la clave falta, detener exportación; no recomendar desinstalar.
Los APK de prueba caducan: no considerar los artifacts un sistema de respaldo permanente.

## Criterios de cierre
- CI verde para el commit candidato; ninguna prueba omitida.
- Prueba manual registrada; actualización conserva los datos.
- No fusionar cambios de gameplay junto a esta fase.
- Mantener main como referencia hasta revisar resultados. Las mejoras de rendimiento y arquitectura se realizan después.
