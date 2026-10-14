#!/bin/bash
# preparar.sh — deja la máquina lista para el motor: revisa e instala lo que
# falte (node, ffmpeg, whisper-cpp, python3 con Pillow) con Homebrew. Lo corre
# la sesión al arrancar el skill, sin que la persona pegue comandos.
#
# Lo único que no instala solo es Homebrew: su instalador pide la
# contraseña del Mac en la Terminal. Si falta, imprime el comando exacto
# para que la persona lo pegue, y termina con código 2.
#
# Uso: preparar.sh            (instala lo que falte)
#      preparar.sh --revisar  (solo dice qué falta, no instala)
set -e
REVISAR=""
[ "${1:-}" = "--revisar" ] && REVISAR=1

faltan=()
command -v node >/dev/null 2>&1 || faltan+=("node")
command -v ffmpeg >/dev/null 2>&1 || faltan+=("ffmpeg")
command -v whisper-cli >/dev/null 2>&1 || command -v whisper-cpp >/dev/null 2>&1 || faltan+=("whisper-cpp")
command -v python3 >/dev/null 2>&1 || faltan+=("python3")
command -v git >/dev/null 2>&1 || faltan+=("git")
pillow=""
python3 -c "import PIL" 2>/dev/null || pillow=1

if [ ${#faltan[@]} -eq 0 ] && [ -z "$pillow" ]; then
  echo "✓ La máquina tiene todo lo que el motor necesita"
  exit 0
fi
echo "· Falta: ${faltan[*]:-}${pillow:+ Pillow}"
[ -n "$REVISAR" ] && exit 1

if [ ${#faltan[@]} -gt 0 ]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "✗ Falta Homebrew y su instalador pide la contraseña del Mac. Pégale a la persona este comando para que lo corra en su Terminal y vuelve a correr preparar.sh:"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 2
  fi
  echo "── Instalando con Homebrew: ${faltan[*]} ──"
  brew install "${faltan[@]}"
fi
if [ -n "$pillow" ]; then
  echo "── Instalando Pillow para python3 ──"
  python3 -m pip install --quiet --user Pillow 2>/dev/null \
    || python3 -m pip install --quiet --user --break-system-packages Pillow
fi
echo "✓ La máquina quedó lista para el motor"
