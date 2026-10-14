#!/bin/bash
# preparar.sh — deja la máquina lista para el motor: revisa e instala lo que
# falte (node, ffmpeg, whisper-cpp, python3 con Pillow y numpy, y en Linux
# las librerías que Chrome headless necesita para renderizar). Lo corre la
# sesión al arrancar el skill, sin que la persona pegue comandos.
#
# Dónde corre:
#   macOS            Homebrew.
#   Linux y Windows  el motor corre en Linux (es el mismo de la nube). En
#                    Windows eso es WSL con Ubuntu: Claude Code se instala y
#                    se abre DENTRO de Ubuntu, no en PowerShell. Ahí se usa
#                    apt para las librerías del sistema y Homebrew para node,
#                    ffmpeg y whisper-cpp (mismas herramientas que el Mac).
#   Windows sin WSL  (Git Bash, PowerShell) no corre el motor: el script lo
#                    dice y explica cómo entrar a WSL.
#
# Lo que pide contraseña (apt con sudo, el instalador de Homebrew) no lo
# puede teclear la sesión: el script imprime el comando exacto para que la
# persona lo pegue en su terminal, y termina con código 2. Se vuelve a correr
# después y sigue desde donde quedó.
#
# Uso: preparar.sh            (instala lo que falte)
#      preparar.sh --revisar  (solo dice qué falta, no instala)
set -e
REVISAR=""
[ "${1:-}" = "--revisar" ] && REVISAR=1

SISTEMA="$(uname -s 2>/dev/null || echo desconocido)"
case "$SISTEMA" in
  Darwin) PLATAFORMA=mac ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then PLATAFORMA=wsl; else PLATAFORMA=linux; fi ;;
  MINGW*|MSYS*|CYGWIN*) PLATAFORMA=windows ;;
  *) PLATAFORMA=desconocida ;;
esac

if [ "$PLATAFORMA" = windows ] || [ "$PLATAFORMA" = desconocida ]; then
  echo "✗ El motor no corre directo en Windows: corre dentro de WSL, con Ubuntu."
  echo "  Correr el instalador de Windows (PowerShell) y seguir su código de salida:"
  echo '  irm https://raw.githubusercontent.com/elmochilerodigital/video-engine-plugin/main/windows/instalar.ps1 -OutFile "$env:TEMP\instalar.ps1"'
  echo '  powershell -ExecutionPolicy Bypass -File "$env:TEMP\instalar.ps1"'
  exit 3
fi

# Homebrew en Linux vive fuera del PATH hasta que se carga su entorno.
if ! command -v brew >/dev/null 2>&1; then
  for b in /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew" /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then eval "$("$b" shellenv)"; break; fi
  done
fi

# ── Linux / WSL: librerías del sistema (las del Dockerfile de la nube) ──
APT_PAQUETES="build-essential curl git file procps python3 python3-pip bc xz-utils ca-certificates \
libnss3 libdbus-1-3 libatk1.0-0 libgbm-dev libasound2t64 libxrandr2 libxkbcommon-dev libxfixes3 \
libxcomposite1 libxdamage1 libatk-bridge2.0-0 libpango-1.0-0 libcairo2 libcups2 \
fontconfig fonts-noto-color-emoji fonts-dejavu-core fonts-liberation2"
if [ "$PLATAFORMA" = wsl ] || [ "$PLATAFORMA" = linux ]; then
  faltan_apt=()
  for p in $APT_PAQUETES; do
    # Ubuntu 24.04 renombró varias librerías con el sufijo t64 (libasound2,
    # libatk, libcups...): cualquiera de los dos nombres sirve.
    base_p="${p%t64}"
    dpkg -s "$base_p" >/dev/null 2>&1 || dpkg -s "${base_p}t64" >/dev/null 2>&1 || faltan_apt+=("$p")
  done
  if [ ${#faltan_apt[@]} -gt 0 ]; then
    echo "· Faltan librerías del sistema: ${faltan_apt[*]}"
    [ -n "$REVISAR" ] && exit 1
    # libasound2t64 no existe en Ubuntu 22.04: ahí se pide libasound2.
    apt_lista="$(printf '%s ' "${faltan_apt[@]}")"
    if ! apt-cache show libasound2t64 >/dev/null 2>&1; then apt_lista="${apt_lista/libasound2t64/libasound2}"; fi
    cmd="sudo apt-get update && sudo apt-get install -y ${apt_lista}"
    if sudo -n true 2>/dev/null; then
      echo "── Instalando librerías del sistema ──"
      eval "$cmd"
    else
      echo "✗ Instalar las librerías del sistema pide la contraseña de Ubuntu. Pégale a la persona este comando para que lo corra en su terminal y vuelve a correr preparar.sh:"
      echo "$cmd"
      exit 2
    fi
  fi
fi

# ── Herramientas (Homebrew en Mac y en Linux) ──
faltan=()
command -v node >/dev/null 2>&1 || faltan+=("node")
command -v ffmpeg >/dev/null 2>&1 || faltan+=("ffmpeg")
command -v whisper-cli >/dev/null 2>&1 || command -v whisper-cpp >/dev/null 2>&1 || faltan+=("whisper-cpp")
command -v python3 >/dev/null 2>&1 || faltan+=("python3")
command -v git >/dev/null 2>&1 || faltan+=("git")
py=""
python3 -c "import PIL, numpy" 2>/dev/null || py=1

if [ ${#faltan[@]} -eq 0 ] && [ -z "$py" ]; then
  echo "✓ La máquina tiene todo lo que el motor necesita ($PLATAFORMA)"
  exit 0
fi
echo "· Falta: ${faltan[*]:-}${py:+ Pillow/numpy}"
[ -n "$REVISAR" ] && exit 1

if [ ${#faltan[@]} -gt 0 ]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "✗ Falta Homebrew y su instalador pide la contraseña. Pégale a la persona este comando para que lo corra en su terminal y vuelve a correr preparar.sh:"
    if [ "$PLATAFORMA" = mac ]; then
      echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    else
      echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && echo '"'"'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'"'"' >> ~/.bashrc'
    fi
    exit 2
  fi
  echo "── Instalando con Homebrew: ${faltan[*]} ──"
  brew install "${faltan[@]}"
fi
if [ -n "$py" ]; then
  echo "── Instalando Pillow y numpy para python3 ──"
  python3 -m pip install --quiet --user Pillow numpy 2>/dev/null \
    || python3 -m pip install --quiet --user --break-system-packages Pillow numpy
fi
echo "✓ La máquina quedó lista para el motor ($PLATAFORMA)"
