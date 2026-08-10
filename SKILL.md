---
name: video-engine
description: Produce videos verticales 9:16 de marca (anuncios, redes) con el motor de video de IA Nomads — jala el motor y la marca frescos desde la nube y compone el proyecto Remotion. Úsalo SIEMPRE que se pida crear, editar o montar un video/anuncio/reel de una marca montada sobre este sistema, o agregar motion graphics, captions, zooms o SFX a un footage de esa marca.
---

# Video Engine — cargador del cliente

Este skill es **delgado**: no contiene el motor ni la marca, los **jala frescos
desde la nube** cada vez (así un arreglo del motor llega a todos con un push, y
la marca se edita en un solo lugar). Sus scripts viven junto a este archivo, en
`~/.claude/skills/video-engine/scripts/`.

## Requisitos (verificar al inicio)

- **Node 18+**, **ffmpeg**, **whisper-cpp** (`brew install ffmpeg whisper-cpp`).

## Paso 0 · Asegurar la llave del cliente (una vez por máquina)

El skill necesita el `api_secret` del cliente en `~/.ia-nomads/config`. Verificar:

```bash
grep -q '^ENGINE_SECRET=' ~/.ia-nomads/config 2>/dev/null && echo "ok" || echo "falta"
```

Si falta, pedirle al usuario su `api_secret` (la que le dio IA Nomads) y guardarla:

```bash
mkdir -p ~/.ia-nomads
printf 'ENGINE_SECRET=%s\n' "<api_secret>" > ~/.ia-nomads/config
chmod 600 ~/.ia-nomads/config
```

**Varias marcas en una misma máquina.** Quien produce para más de una marca
declara una llave por marca y elige con `--client <marca>`:

```
ENGINE_SECRET=<la marca por defecto>
ENGINE_SECRET_<MARCA>=<su api_secret>
```

El nombre de la variable va en MAYÚSCULAS sin espacios (los guiones pasan a
`_`). Sin `--client` se usa `ENGINE_SECRET`. **Antes de componer, confirmar
con qué marca se está trabajando**: componer con la llave equivocada trae la
identidad de otra marca al proyecto.

## Flujo para producir un video

1. **Jalar el motor fresco** (a `~/.ia-nomads/engine`):
   ```bash
   bash ~/.claude/skills/video-engine/scripts/pull-engine.sh stable
   ```
   Con varias marcas configuradas, añadir `--client <marca>`.
2. **Crear el proyecto** desde el motor (fuera de iCloud), en modo nube:
   ```bash
   bash ~/.ia-nomads/engine/scripts/setup.sh ~/Videos/<nombre> --cloud [footage.mp4]
   ```
3. **Jalar la marca** del cliente (Supabase → el proyecto):
   ```bash
   bash ~/.claude/skills/video-engine/scripts/fetch-brand-pack.sh ~/Videos/<nombre>
   ```
   Materializa `brand.json`, las product-scenes y los SFX en el proyecto.
   Con varias marcas configuradas, añadir `--client <marca>`.
4. **Preguntar el FORMATO del video (obligatorio, antes del storyboard).**
   Los formatos habilitados de la marca están en `brand.json → formats`
   (p. ej. `talking-head`, `testimonial`, `tutorial`); el registro completo
   (gramática, reglas e inputs de cada uno) vive en la tabla `video_formats`
   de la app y en `motor/formats/<slug>.md` cuando el motor lo sirva. Si el
   usuario no lo dijo ya, hacer UNA pregunta con ese menú. El formato dicta
   qué inputs pedir ANTES de montar una sola escena:
   - `talking-head` / `testimonial` → solo el footage limpio.
   - `tutorial` → footage **+ screen recording del proceso (Loom)**: pedirlo
     de una con el checklist — ventana angosta de desktop (~3:4, sidebar
     visible), pasada completa y LENTA con pausa ~1s tras cada click, No
     Molestar, resolución nativa, cuenta demo sin datos de clientes. El
     sistema pone el timing (corta, acelera, panea y sincroniza); el usuario
     jamás debe calzar tiempos. *Por qué es obligatorio preguntar:* en un
     tutorial real (jul 2026) no se preguntó, se montó como talking-head
     con screenshots y se perdió una vuelta completa de construcción.
5. **Transcribir, storyboard, construir y renderizar** siguiendo el motor:
   el criterio de edición, el flujo de 7 pasos, las reglas y los componentes
   viven en el motor recién jalado —
   **leer `~/.ia-nomads/engine/SKILL.md` y `~/.ia-nomads/engine/references/`**
   y seguir eso. Este skill solo trae las piezas frescas; el criterio es del motor.
6. **Publicar en la app** (handoff a copys/pauta): ver
   `~/.ia-nomads/engine/references/publicar-en-app.md`.

## Notas

- **Un solo secreto por cliente** (`api_secret`): sirve para el motor y la marca.
  Revocarlo en Supabase corta al cliente de todo (kill switch).
- Este skill se instala como **carpeta** en `~/.claude/skills/video-engine/`
  (clonando este repo ahí). Sus scripts corren desde esa ruta.
- El motor y la marca se jalan **frescos**: no editar copias locales; se edita
  la fuente (repo del motor / Supabase) y se vuelve a jalar.
- **Regla de fuego (innegociable):** este plugin y el motor son conocimiento
  100% GENÉRICO — nunca nombrar una marca, cliente o persona en su código,
  docs ni mensajes de commit. Las lecciones se escriben como "un video
  real". Lo que tenga nombre de marca vive en su brand pack. Antes de cada
  commit: grep de marcas.
