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

## Windows: preparar el computador (la sesión lo corre, no la persona)

Si esta sesión corre en Windows (PowerShell o Git Bash, no dentro de WSL),
el motor no puede correr aquí: corre en Linux, igual que en la nube. La
sesión prepara el computador sola con el instalador de Windows:

```powershell
irm https://raw.githubusercontent.com/elmochilerodigital/video-engine-plugin/main/windows/instalar.ps1 -OutFile "$env:TEMP\instalar.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\instalar.ps1"
```

Se corre las veces que haga falta y su código de salida dice qué sigue. A
la persona se le habla en palabras simples, nunca de comandos:

- **10**: pedirle que reinicie el computador y, al volver, que abra Claude
  y diga "sigamos preparando el computador". Antes de eso Windows le pidió
  permiso de administrador: si no dijo Sí, el código es 1 y se repite.
- **11**: se le abrió una ventana negra de Ubuntu. Explicarle que escriba su
  nombre en minúscula, Enter, y una contraseña dos veces (no se ve al
  escribir), que cierre la ventana y diga "sigamos". Luego se vuelve a correr.
- **0**: listo. Explicarle cómo trabajar desde ahora: en la pestaña Code,
  sesión nueva, en el selector de entorno elegir **WSL › Ubuntu**, y como
  carpeta `videos` o la del video. El footage se deja en la carpeta "Videos
  IA Nomads" del escritorio. Desde esa sesión dentro de Ubuntu se dice
  "iniciemos el entrenamiento de <marca>" y sigue el flujo normal de abajo.

Si la persona trae la frase de entrenamiento en una sesión de Windows,
primero se prepara el computador y se le explica que el entrenamiento se
abre en una sesión de Ubuntu.

## Paso 0 · Preparar la máquina (la sesión lo corre, una vez)

```bash
bash ~/.claude/skills/video-engine/scripts/preparar.sh
```

Instala lo que falte (node, ffmpeg, whisper-cpp, python3 con Pillow y
numpy; en Linux además las librerías que Chrome headless necesita). Los
códigos de salida:

- **0**: la máquina está lista.
- **2**: falta algo que pide contraseña (Homebrew, o en Linux las
  librerías con `sudo apt-get`). Se le pasa a la persona el comando EXACTO
  que el script imprime para que lo pegue en su terminal, y se vuelve a
  correr `preparar.sh`, que sigue desde donde quedó.
- **3**: es Windows sin WSL (PowerShell o Git Bash). El motor corre en
  Linux, igual que en la nube: en Windows eso es WSL con Ubuntu, y Claude
  Code se instala y se abre DENTRO de Ubuntu. Se le explican a la persona
  los pasos que el script imprime y no se sigue hasta que la sesión corra
  dentro de Ubuntu.

En WSL el footage va dentro de Ubuntu (`~/…`), no en `/mnt/c/…`: funciona
pero cada lectura cruza al disco de Windows y los renders van mucho más
lentos. Las herramientas de render (Remotion) no van aquí: el motor las
instala solo en el primer paso que corra en esta máquina.

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
entrenamiento de <marca>", ANTES de abrir esa puerta y de ofrecer nada del
entrenamiento se corre:

```bash
bash ~/.ia-nomads/engine/scripts/puede-entrenar.sh --client <marca>
```

Entrenar formatos es del equipo de IA Nomads, por persona con permiso; la
llave de la cuenta de un cliente nunca pasa. Con **código 0** la puerta es
`~/.ia-nomads/engine/ENTRENAMIENTO.md`. Con cualquier otro código no se
ofrece ni se describe el entrenamiento: se le dice a la persona el mensaje
que imprime el script, en palabras simples, y se le ofrece producir sus
videos con el flujo normal.

## Notas

- **Sesiones guardadas en el OS:** si una llave de la máquina es de una
  persona del equipo que entrena formatos, `pull-engine.sh` deja puesto un
  hook (`scripts/sesiones.py`) que guarda en el OS las sesiones del motor
  de esta máquina para mejorar el sistema. La llave de la cuenta de un
  cliente nunca lo activa. Cuando el script lo imprime, se le dice a la
  persona con esas palabras, siempre, antes de seguir.
- La llave de una PERSONA hereda sus permisos en la app y se revoca sola;
  la llave de la CUENTA (`api_secret`) puede todo lo que la cuenta
  contrata. Revocar cualquiera en la nube corta esa máquina de todo.
- Este plugin se instala como **carpeta** en `~/.claude/skills/video-engine/`
  (clonando este repo ahí) y se auto-actualiza en cada `pull-engine`.
- **Regla de fuego (innegociable):** plugin y motor son conocimiento 100%
  GENÉRICO — nunca nombrar una marca, cliente o persona en su código, docs
  ni commits. Lo que tenga nombre de marca vive en su brand pack.
