#!/bin/bash
# nube/setup.sh — script de preparación del ENTORNO EN LA NUBE de Anthropic.
#
# Se pega tal cual en el campo "Setup script" del entorno (claude.ai/code →
# entorno → Setup script). Corre como root en Ubuntu 24.04, una sola vez:
# si termina en menos de cinco minutos, Anthropic guarda la imagen y las
# sesiones siguientes arrancan con todo puesto. Medido en un Ubuntu 24.04
# limpio: ver docs/onboarding-nube.md.
#
# Instala SOLO lo que la sesión de diseño necesita y la VM no trae:
#   ffmpeg            extraer la voz, medir cortes y silencios, mosaicos,
#                     comprimir (apt, serie 6 de Ubuntu)
#   Pillow y numpy    las medidas del gate que corren antes de subir (apt;
#                     si el python3 del PATH no es el del sistema, pip)
#   bc                cuentas de los scripts
# NO instala whisper (la transcripción sale de las palabras con tiempos de
# la tarjeta), ni Remotion, ni Chrome: lo que pinta corre en la nube de IA
# Nomads, no aquí. Tampoco guarda ninguna llave: la llave de la cuenta es
# un secreto de red del entorno y la sesión nunca la ve.
#
# Deja dos marcas (/etc/ia-nomads/nube y ~/.ia-nomads/nube) con las que el
# plugin y el motor reconocen que corren en la nube, y clona este plugin
# como skill del usuario para que la sesión lo encuentre por su nombre.
# Siempre termina con 0: un fallo parcial se imprime y la sesión arranca.
set -u
export DEBIAN_FRONTEND=noninteractive
T0=$(date +%s)
paso() { echo "── $* ──"; }
tiene_py() { python3 -c "import PIL, numpy" >/dev/null 2>&1; }

FALTAN=()
command -v ffmpeg >/dev/null 2>&1 || FALTAN+=(ffmpeg)
command -v bc >/dev/null 2>&1 || FALTAN+=(bc)
tiene_py || FALTAN+=(python3-pil python3-numpy)

if [ ${#FALTAN[@]} -gt 0 ]; then
  paso "apt: ${FALTAN[*]}"
  if apt-get update -qq >/dev/null 2>&1; then
    apt-get install -y -qq --no-install-recommends "${FALTAN[@]}" >/dev/null 2>&1 || echo "⚠️  apt no pudo instalar todo: ${FALTAN[*]}"
  else
    echo "⚠️  apt-get update falló (¿los mirrors de Ubuntu no están permitidos en el entorno?)"
  fi
fi

# El python3 que usan los scripts es el del PATH; si no es el del sistema,
# apt no le sirvió y se completa con pip (PyPI está en la lista de siempre).
if ! tiene_py; then
  paso "pip: Pillow y numpy para $(command -v python3)"
  python3 -m pip install -q pillow numpy >/dev/null 2>&1 \
    || python3 -m pip install -q --break-system-packages pillow numpy >/dev/null 2>&1 \
    || echo "⚠️  no se pudieron instalar Pillow y numpy"
fi

# El plugin como skill del usuario (la sesión además lo tiene como repo).
SKILLS="${HOME:-/root}/.claude/skills"
if [ ! -f "$SKILLS/video-engine/SKILL.md" ]; then
  paso "skill video-engine en $SKILLS"
  mkdir -p "$SKILLS"
  git clone -q --depth 1 https://github.com/elmochilerodigital/video-engine-plugin.git "$SKILLS/video-engine" >/dev/null 2>&1 \
    || echo "⚠️  no se pudo clonar el plugin como skill (la sesión lo tiene igual como repositorio)"
fi

# Las marcas de "esto es la nube": el motor y el plugin no piden llave ni
# intentan preparar la máquina cuando las ven.
mkdir -p /etc/ia-nomads "${HOME:-/root}/.ia-nomads" 2>/dev/null
date -u +%Y-%m-%dT%H:%M:%SZ > /etc/ia-nomads/nube 2>/dev/null || true
date -u +%Y-%m-%dT%H:%M:%SZ > "${HOME:-/root}/.ia-nomads/nube" 2>/dev/null || true
chmod -R a+rX /etc/ia-nomads 2>/dev/null || true

echo ""
echo "✓ Entorno listo en $(( $(date +%s) - T0 )) s: ffmpeg $(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f3 || echo falta) · python3 $(python3 --version 2>/dev/null | cut -d' ' -f2) · Pillow/numpy $(tiene_py && echo ok || echo faltan) · node $(node --version 2>/dev/null || echo falta)"
exit 0
