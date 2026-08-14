---
name: video-engine
description: Produce videos verticales 9:16 de marca (anuncios, redes) con el motor de video de IA Nomads — jala el motor y la marca frescos desde la nube y compone el proyecto Remotion. Úsalo SIEMPRE que se pida crear, editar o montar un video/anuncio/reel de una marca montada sobre este sistema, o agregar motion graphics, captions, zooms o SFX a un footage de esa marca.
---

# Video Engine — bootstrap del cliente

Este plugin es SOLO el arranque: **el cerebro completo (flujo, criterio,
reglas, scripts) vive en el MOTOR**, que se descarga fresco de la nube en
cada video. Nada del proceso se decide aquí — así los arreglos y mejoras
llegan solos, sin reinstalar este plugin. (El plugin además se
auto-actualiza al jalar el motor.)

## Requisitos (verificar al inicio)

- **Node 18+**, **ffmpeg**, **whisper-cpp** (`brew install ffmpeg whisper-cpp`).

## Paso 1 · Asegurar la llave del cliente (una vez por máquina)

El skill necesita el `api_secret` del cliente en `~/.ia-nomads/config`:

```bash
grep -q '^ENGINE_SECRET=' ~/.ia-nomads/config 2>/dev/null && echo "ok" || echo "falta"
```

Si falta, pedirla al usuario (la que le dio IA Nomads) y guardarla:

```bash
mkdir -p ~/.ia-nomads
printf 'ENGINE_SECRET=%s\n' "<api_secret>" > ~/.ia-nomads/config
chmod 600 ~/.ia-nomads/config
```

**Varias marcas en una máquina:** una llave por marca y se elige con
`--client <marca>` en los scripts:

```
ENGINE_SECRET=<la marca por defecto>
ENGINE_SECRET_<MARCA>=<su api_secret>
```

(MAYÚSCULAS sin espacios; guiones → `_`.) **Antes de componer, confirmar
con qué marca se trabaja**: la llave equivocada trae la identidad de otra
marca al proyecto.

## Paso 2 · Jalar el motor y seguir SUS instrucciones

```bash
bash ~/.claude/skills/video-engine/scripts/pull-engine.sh stable [--client <marca>]
```

A partir de aquí, **el proceso completo lo dicta el motor**:
**leer `~/.ia-nomads/engine/SKILL.md` y seguirlo** — el flujo, los scripts
(`~/.ia-nomads/engine/scripts/`), la doctrina y los formatos viven allá y
llegan frescos en cada descarga.

## Notas

- **Un solo secreto por cliente** (`api_secret`): sirve para el motor y la
  marca. Revocarlo en la nube corta al cliente de todo (kill switch).
- Este plugin se instala como **carpeta** en `~/.claude/skills/video-engine/`
  (clonando este repo ahí) y se auto-actualiza en cada `pull-engine`.
- **Regla de fuego (innegociable):** plugin y motor son conocimiento 100%
  GENÉRICO — nunca nombrar una marca, cliente o persona en su código, docs
  ni commits. Lo que tenga nombre de marca vive en su brand pack.
