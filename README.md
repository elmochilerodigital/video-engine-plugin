# video-engine

Skill de Claude Code para producir videos verticales 9:16 de marca con el motor
de video de IA Nomads. Es un **cargador delgado**: jala el motor y la marca
frescos de la nube; no contiene el motor ni secretos.

## En la nube (la forma normal)

No se instala nada en el computador. La persona abre una sesión de Claude
Code en la nube de Anthropic sobre este repositorio, en un entorno que creó
una vez pegando tres bloques (dominios, script de preparación y su llave
como secreto de red), y pide su video por el ID de la tarjeta. Los seis
pasos, en palabras simples y con los bloques listos para copiar:

→ **[docs/onboarding-nube.md](docs/onboarding-nube.md)**

Lo que se pega en el entorno vive en [`nube/`](nube/): `setup.sh` (el
script de preparación: ffmpeg, Pillow, numpy; sin whisper ni Remotion),
`dominios.txt` y el detalle de cada bloque en `nube/README.md`. En esa
sesión el skill no pide llave ni prepara la máquina: la rama "Sesión en la
nube" de `SKILL.md` lo dice. `scripts/diagnostico.sh` responde en una línea
si el gateway contesta 200 desde la sesión.

## En el computador (Mac)

Es un skill de carpeta. Se instala clonando este repo en la carpeta de skills:

```bash
git clone https://github.com/elmochilerodigital/video-engine-plugin.git ~/.claude/skills/video-engine
```

O, en lenguaje natural, dile a tu Claude:

> "Instala el skill de este repo: https://github.com/elmochilerodigital/video-engine-plugin
> — clónalo en ~/.claude/skills/video-engine"

Abre una sesión de Claude en la carpeta de tu video (con el footage crudo) y pide:

> "hazme un video de marca con este footage"

O, si vas a entrenar una marca nueva:

> "iniciemos el entrenamiento de <marca>"

La primera vez el skill prepara la máquina solo (instala node, ffmpeg y
whisper con Homebrew; si falta algo que pide contraseña te pasa el comando
exacto para que lo pegues tú) y te pide la llave que te dio IA Nomads, que
guarda en `~/.ia-nomads/config`. Sin una llave válida, el motor y la marca
no se descargan (401).

## Windows (equipo; ya no es el camino de los clientes)

Desde 2026-10 los clientes producen en la nube (arriba). El instalador de
Windows sigue aquí para el equipo: el motor corre en Linux, igual que en la
nube, y en Windows eso es WSL con Ubuntu. En una sesión de Claude en Windows
se dice "prepara este computador para el motor de video de IA Nomads" y la
sesión corre el instalador:

```powershell
irm https://raw.githubusercontent.com/elmochilerodigital/video-engine-plugin/main/windows/instalar.ps1 -OutFile "$env:TEMP\instalar.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\instalar.ps1"
```

Se corre las veces que haga falta; su código de salida dice qué sigue:

- **10**: WSL quedó instalado. La persona reinicia y vuelve a decir "sigamos preparando el computador".
- **11**: se abrió la ventana de Ubuntu para crear su usuario (nombre en minúscula y una contraseña). La persona la cierra y dice "sigamos".
- **0**: listo. Desde ahora se trabaja en una sesión nueva con el entorno WSL › Ubuntu, carpeta `videos`. El footage va en la carpeta "Videos IA Nomads" del escritorio.
- **1**: algo falló; el mensaje dice qué.

A la persona se le habla en palabras simples, nunca de comandos.

## Cómo funciona

- El **motor** (privado) y la **marca** (Supabase) se jalan frescos con tu
  `api_secret` — un arreglo del motor llega a todos con un push. En la
  nube la llave no está en la máquina: el proxy del entorno la adjunta a
  cada petición (secreto de red) y los scripts mandan la petición sin la
  cabecera de llave.
- **Un solo secreto por cliente**: sirve para el motor y la marca. Revocarlo
  corta el acceso (kill switch).
