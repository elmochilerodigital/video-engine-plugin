#!/bin/bash
# preparar.sh — deja la máquina lista para el motor: revisa e instala lo que
# falte según lo que la persona va a hacer en ella. Lo corre la sesión al
# arrancar el skill, sin que la persona pegue comandos.
#
# Perfiles (--perfil, y queda guardado en ~/.ia-nomads/config como
# PERFIL_MAQUINA para las siguientes veces):
#   produccion     (por defecto) produce piezas: el render y la voz van en la
#                  nube, así que basta node, ffmpeg y python3 con Pillow y
#                  numpy. Nada de Chrome headless ni de whisper.
#   entrenamiento  entrena formatos: itera hoja, verificar y pedacito en esta
#                  máquina, así que en Linux suma las librerías que Chrome
#                  headless necesita para renderizar.
# La voz se transcribe en la nube en los dos perfiles. Whisper local solo se
# instala si la casa lo pide con TRANSCRIPCION=whisper (entorno o config).
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
# Uso: preparar.sh [--perfil produccion|entrenamiento]  (instala lo que falte)
#      preparar.sh --revisar [--perfil ...]               (solo dice qué falta)
set -e
REVISAR=""; PERFIL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --revisar) REVISAR=1; shift ;;
    --perfil) PERFIL="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
CONFIG="${ENGINE_CONFIG:-$HOME/.ia-nomads/config}"
leer_config() { grep -E "^$1=" "$CONFIG" 2>/dev/null | head -1 | cut -d= -f2- || true; }
if [ -n "$PERFIL" ]; then
  case "$PERFIL" in produccion|entrenamiento) ;; *) echo "✗ Perfil desconocido: $PERFIL (produccion o entrenamiento)"; exit 1 ;; esac
  if [ -z "$REVISAR" ] && [ "$(leer_config PERFIL_MAQUINA)" != "$PERFIL" ]; then
    mkdir -p "$(dirname "$CONFIG")"
    { grep -vE '^PERFIL_MAQUINA=' "$CONFIG" 2>/dev/null || true; echo "PERFIL_MAQUINA=$PERFIL"; } > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    chmod 600 "$CONFIG" 2>/dev/null || true
  fi
else
  PERFIL="$(leer_config PERFIL_MAQUINA)"
  case "$PERFIL" in entrenamiento) ;; *) PERFIL=produccion ;; esac
fi
TRANSCRIPCION="${TRANSCRIPCION:-$(leer_config TRANSCRIPCION)}"
echo "· Perfil de la máquina: $PERFIL"

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
# Las de Chrome headless solo hacen falta para renderizar en esta máquina,
# es decir, en el perfil de entrenamiento.
APT_PAQUETES="curl git file procps python3 python3-pip bc xz-utils ca-certificates \
fontconfig fonts-noto-color-emoji fonts-dejavu-core fonts-liberation2"
APT_CHROME="libnss3 libdbus-1-3 libatk1.0-0 libgbm-dev libasound2t64 libxrandr2 libxkbcommon-dev libxfixes3 \
libxcomposite1 libxdamage1 libatk-bridge2.0-0 libpango-1.0-0 libcairo2 libcups2"
[ "$PERFIL" = entrenamiento ] && APT_PAQUETES="$APT_PAQUETES $APT_CHROME"
# build-essential solo si Homebrew va a instalar algo (lo exige en Linux); el
# instalador de Windows deja node y ffmpeg sin Homebrew.
herramientas_faltan() {
  command -v node >/dev/null 2>&1 && command -v ffmpeg >/dev/null 2>&1 || return 0
  [ "$TRANSCRIPCION" = whisper ] && ! command -v whisper-cli >/dev/null 2>&1 && ! command -v whisper-cpp >/dev/null 2>&1 && return 0
  return 1
}
herramientas_faltan && APT_PAQUETES="build-essential $APT_PAQUETES"
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

# ── Sesiones del motor guardadas en el OS (perfil entrenamiento) ──
# Para mejorar el flujo, las sesiones de Claude del motor en esta máquina
# suben al OS (scripts/sesiones.py, hook de Claude Code). La persona lo sabe:
# el script imprime la frase que la sesión le dice, y cada sesión del motor
# se lo recuerda en pantalla. Nunca hace fallar la preparación.
guardar_sesiones() {
  [ "$PERFIL" = entrenamiento ] && [ -z "$REVISAR" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  python3 "$(dirname "$0")/sesiones.py" instalar || true
}

# ── Herramientas (Homebrew en Mac y en Linux) ──
faltan=()
command -v node >/dev/null 2>&1 || faltan+=("node")
command -v ffmpeg >/dev/null 2>&1 || faltan+=("ffmpeg")
if [ "$TRANSCRIPCION" = whisper ]; then
  command -v whisper-cli >/dev/null 2>&1 || command -v whisper-cpp >/dev/null 2>&1 || faltan+=("whisper-cpp")
fi
command -v python3 >/dev/null 2>&1 || faltan+=("python3")
command -v git >/dev/null 2>&1 || faltan+=("git")
py=""
python3 -c "import PIL, numpy" 2>/dev/null || py=1

if [ ${#faltan[@]} -eq 0 ] && [ -z "$py" ]; then
  echo "✓ La máquina tiene todo lo que el motor necesita ($PLATAFORMA, $PERFIL)"
  guardar_sesiones
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
echo "✓ La máquina quedó lista para el motor ($PLATAFORMA, $PERFIL)"
guardar_sesiones
