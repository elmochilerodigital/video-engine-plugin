# video-engine

Skill de Claude Code para producir videos verticales 9:16 de marca con el motor
de video de IA Nomads (Remotion + ffmpeg). Es un **cargador delgado**:
jala el motor y la marca frescos de la nube; no contiene el motor ni secretos.

## Instalar

Es un skill de carpeta. Se instala clonando este repo en la carpeta de skills:

```bash
git clone https://github.com/elmochilerodigital/video-engine-plugin.git ~/.claude/skills/video-engine
```

O, en lenguaje natural, dile a tu Claude:

> "Instala el skill de este repo: https://github.com/elmochilerodigital/video-engine-plugin
> — clónalo en ~/.claude/skills/video-engine"

## Primer uso

Abre una sesión de Claude en la carpeta de tu video (con el footage crudo) y pide:

> "hazme un video de marca con este footage"

O, si vas a entrenar una marca nueva:

> "iniciemos el entrenamiento de <marca>"

La primera vez el skill prepara la máquina solo (instala node y ffmpeg con
Homebrew, y para entrenar formatos lo que Chrome headless necesita; la voz se
transcribe en la nube; si falta algo que pide contraseña te pasa el comando
exacto para que lo pegues tú) y te pide la llave que te dio IA Nomads, que
guarda en `~/.ia-nomads/config`. Sin una llave válida, el motor y la marca
no se descargan (401).

## Windows

El motor corre en Linux, igual que en la nube: en Windows eso es WSL con
Ubuntu, y las sesiones de video se abren dentro de Ubuntu desde la app de
Claude (pestaña Code › entorno WSL › Ubuntu). La persona no instala nada a
mano: en una sesión de Claude en Windows dice "prepara este computador para
el motor de video de IA Nomads" y la sesión corre el instalador:

```powershell
irm https://raw.githubusercontent.com/elmochilerodigital/video-engine-plugin/main/windows/instalar.ps1 -OutFile "$env:TEMP\instalar.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\instalar.ps1" -Perfil produccion
```

`-Perfil entrenamiento` para quien entrena formatos (itera el render en
local); `-Perfil produccion` (el de por defecto) para quien produce piezas,
con el render y la voz en la nube.

Se corre las veces que haga falta; su código de salida dice qué sigue:

- **10**: WSL quedó instalado. La persona reinicia y vuelve a decir "sigamos preparando el computador".
- **11**: se abrió la ventana de Ubuntu para crear su usuario (nombre en minúscula y una contraseña). La persona la cierra y dice "sigamos".
- **0**: listo. Desde ahora se trabaja en una sesión nueva con el entorno WSL › Ubuntu, carpeta `videos`. El footage va en la carpeta "Videos IA Nomads" del escritorio.
- **1**: algo falló; el mensaje dice qué.

A la persona se le habla en palabras simples, nunca de comandos.

## Cómo funciona

- El **motor** (privado) y la **marca** (Supabase) se jalan frescos con tu
  `api_secret` — un arreglo del motor llega a todos con un push.
- **Un solo secreto por cliente**: sirve para el motor y la marca. Revocarlo
  corta el acceso (kill switch).
