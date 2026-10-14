# video-engine

Skill de Claude Code para producir videos verticales 9:16 de marca con el motor
de video de IA Nomads (Remotion + ffmpeg + whisper). Es un **cargador delgado**:
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

La primera vez el skill prepara la máquina solo (instala node, ffmpeg y
whisper con Homebrew; si falta algo que pide contraseña te pasa el comando
exacto para que lo pegues tú) y te pide la llave que te dio IA Nomads, que
guarda en `~/.ia-nomads/config`. Sin una llave válida, el motor y la marca
no se descargan (401).

**Windows:** el motor corre en Linux, igual que en la nube. Instala WSL con
Ubuntu (`wsl --install -d Ubuntu` en PowerShell como administrador),
reinicia, abre Ubuntu e instala Claude Code ahí dentro
(`curl -fsSL https://claude.ai/install.sh | bash`). Todo se trabaja desde la
ventana de Ubuntu, con el footage dentro de Ubuntu.

## Cómo funciona

- El **motor** (privado) y la **marca** (Supabase) se jalan frescos con tu
  `api_secret` — un arreglo del motor llega a todos con un push.
- **Un solo secreto por cliente**: sirve para el motor y la marca. Revocarlo
  corta el acceso (kill switch).
