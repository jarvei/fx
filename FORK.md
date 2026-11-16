# Notas del fork: el selector de proveedor

Este árbol es el upstream `vercel-labs/fx` con un solo parche propio: el
selector `/provider` lista las conexiones que declara `~/.fx/settings.json` en
lugar de las cuentas de fábrica (Vercel, Codex, Grok), y los avisos de cambio
nombran esas conexiones. El resto del árbol es upstream intacto, para que
rebasear sea: fusionar el tag nuevo, reaplicar los bloques de abajo y pasar las
comprobaciones del final.

Los bloques van anclados a nombres de función y de declaración, no a líneas,
porque las líneas se mueven en cada release.

## Bloques del parche

1. `src/core/config/configured_provider.zig` — `max_providers` pasa a `pub`
   para que el selector dimensione su columna con el límite real de conexiones.
2. `src/core/auth/provider_picker_catalog.zig` — `providerOptions` lee el
   registro (`configured_provider.Registry.definitions`) en vez de
   `provider_catalog.entries`; se van `providerVisible` y los imports que solo
   él usaba; `no_connections_label` y `no_connections_annotation` dan una fila
   informativa a un perfil sin conexiones.
3. `src/core/auth/provider_catalog.zig` — `displayName(*const ProviderId)`
   devuelve el nombre propio de una conexión configurada, o el nombre de ruta
   del catálogo para una de fábrica. Recibe puntero a propósito: devolver
   `label()` desde una copia por valor deja el nombre colgando.
4. `src/core/app/provider_picker_runtime.zig` — `configuredProviders(app)` y
   `providerFor(app, name)` resuelven y enlazan la conexión elegida; la columna
   `.provider`, `submit`, `advanceOnSpace` y `syncProviderSelection` los usan.
   La columna escribe la anotación de cada fila antes de poder saltársela: el
   búfer nace `undefined` y el render lee `annotations[0..count]`.
5. `src/core/app/app_auth_runtime.zig` — los avisos «Already using …» y
   «Switched to … with …» usan `provider_catalog.displayName`.
6. `src/core/auth/auth_runtime.zig` — `preparationFailureText` usa
   `displayName`, para que un fallo de credencial nombre la conexión.

El mensaje de `fx provider` (`unknownProviderMessage` en
`src/core/config/config_runtime.zig`) se queda como está: los dos nombres de
fábrica siguen aceptándose en la línea de órdenes aunque el selector no los
ofrezca, y dos textos distintos sobre lo mismo obligarían a tocar también los
e2e de `tests/e2e/configured-providers.test.ts` en cada rebase.

Cada bloque lleva el comentario `Fork:` en el sitio exacto, para encontrarlo con
`grep -rn "Fork:" src/`.

## Comprobaciones tras reaplicar

```bash
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux
./scripts/smoke-binary.sh ./zig-out/bin/fx
```

Después, con el binario recién compilado (`./zig-out/bin/fx`, nunca el
instalado) y un HOME de pruebas:

- `/provider` lista exactamente los `providers` del `settings.json` de ese HOME.
- Enter sobre uno imprime `* provider: Switched to <nombre> con <modelo>`
  (en inglés: `with`).
- `/model` a continuación lista los modelos de esa conexión.
- Con un `settings.json` sin `providers`, la columna muestra la fila
  `no-connections` en vez de quedarse vacía.
- `fx provider vercel` deja de resolver; `fx provider <conexión>` sigue.

Las pruebas de estos ficheros son bloques `test` en línea
(`provider_picker_catalog.zig`, `provider_picker_runtime.zig`,
`provider_catalog.zig`). `zig build test` arrastra además suites ajenas que en
este equipo fallan por el entorno (config_runtime, settings_store,
app_lifecycle, mcp, terminal); no son de este parche.

## Esquema de settings de 0.0.17

Upstream cambió `model_metadata.<modelo>.efforts` (lista de niveles) por
`reasoning_efforts` (mapa nivel → campos de la petición que lo eligen). Un
`settings.json` escrito para 0.0.16 no carga:

```json
"efforts": ["low", "high", "max"]
  ->  "reasoning_efforts": {
        "low":  {"reasoning_effort": "low"},
        "high": {"reasoning_effort": "high"},
        "max":  {"reasoning_effort": "max"}
      }
```

No es un cambio del fork: es de upstream y no se parchea aquí.
