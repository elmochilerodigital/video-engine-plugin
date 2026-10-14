---
name: video-engine
description: Produce videos verticales 9:16 de marca (anuncios, redes) con el motor de video de IA Nomads — jala el motor y la marca frescos desde la nube y compone el proyecto Remotion. El footage entra de dos formas: un archivo local, o un video ya aprobado en la app identificado por su ID (la tarjeta del Planner lo lleva). Úsalo SIEMPRE que se pida crear, editar, montar o producir un video/anuncio/reel de una marca montada sobre este sistema; cuando llegue un ID de video para editar o producir ("edita este video: <id>"); cuando se pregunte qué videos hay aprobados o pendientes por producir; cuando se pida agregar motion graphics, captions, zooms o SFX a un footage de esa marca; o cuando alguien diga "iniciemos" o "sigamos el entrenamiento de <marca>" (el modo entrenamiento del motor).
---

# Video Engine — bootstrap del cliente

Este plugin es SOLO el arranque: **el cerebro completo (flujo, criterio,
reglas, scripts) vive en el MOTOR**, que se descarga fresco de la nube en
cada video. Nada del proceso se decide aquí — así los arreglos y mejoras
llegan solos, sin reinstalar este plugin. (El plugin además se
auto-actualiza al jalar el motor.)

La persona del otro lado sabe de video, no de terminales: **los tres pasos
de abajo los corre la sesión**, no ella. A ella solo se le pide lo que la
sesión no puede resolver (su llave, y la contraseña del Mac si falta
Homebrew).

## Paso 0 · Preparar la máquina (la sesión lo corre, una vez)

```bash
bash ~/.claude/skills/video-engine/scripts/preparar.sh
```

Instala con Homebrew lo que falte (node, ffmpeg, whisper-cpp, python3 con
Pillow). Si termina con código 2 es que falta Homebrew: su instalador pide
la contraseña del Mac, así que se le pasa a la persona el comando que el
script imprime para que lo pegue en su Terminal, y se vuelve a correr
`preparar.sh`. Las herramientas de render (Remotion) no van aquí: el motor
las instala solo en el primer paso que corra en esta máquina.

## Paso 1 · Asegurar la llave (una vez por máquina)

El skill necesita la llave que IA Nomads le dio a la persona en
`~/.ia-nomads/config`. Se guarda **con el nombre de la marca**, siempre:

```bash
grep -q '^ENGINE_SECRET_[A-Z0-9_]*=' ~/.ia-nomads/config 2>/dev/null && echo "ok" || echo "falta"
```

Si falta, pedírsela ("pégame la llave que te dio IA Nomads para <marca>")
y guardarla. `<MARCA>` va en MAYÚSCULAS, sin espacios, guiones → `_`:

```bash
mkdir -p ~/.ia-nomads
printf 'ENGINE_SECRET_<MARCA>=%s\n' "<llave>" >> ~/.ia-nomads/config
chmod 600 ~/.ia-nomads/config
```

Con una sola marca en la máquina los scripts la usan solos. Con varias,
se elige con `--client <marca>`; sin default a propósito: si una
operación no especifica marca, FALLA con mensaje claro y se pregunta —
**el sistema nunca adivina la marca**. Antes de componer, confirmar
siempre con cuál se trabaja. (`ENGINE_SECRET=` a secas, sin nombre, sigue
valiendo en máquinas viejas de una sola marca.)

## Paso 2 · Jalar el motor y seguir SUS instrucciones

```bash
bash ~/.claude/skills/video-engine/scripts/pull-engine.sh stable --client <marca>
```

A partir de aquí, **el proceso completo lo dicta el motor**:
**leer `~/.ia-nomads/engine/SKILL.md` y seguirlo** — el flujo, los scripts
(`~/.ia-nomads/engine/scripts/`), la doctrina y los formatos viven allá y
llegan frescos en cada descarga. Si la frase fue "iniciemos" o "sigamos el
entrenamiento de <marca>", la puerta es `~/.ia-nomads/engine/ENTRENAMIENTO.md`.

## Notas

- La llave de una PERSONA hereda sus permisos en la app y se revoca sola;
  la llave de la CUENTA (`api_secret`) puede todo lo que la cuenta
  contrata. Revocar cualquiera en la nube corta esa máquina de todo.
- Este plugin se instala como **carpeta** en `~/.claude/skills/video-engine/`
  (clonando este repo ahí) y se auto-actualiza en cada `pull-engine`.
- **Regla de fuego (innegociable):** plugin y motor son conocimiento 100%
  GENÉRICO — nunca nombrar una marca, cliente o persona en su código, docs
  ni commits. Lo que tenga nombre de marca vive en su brand pack.
