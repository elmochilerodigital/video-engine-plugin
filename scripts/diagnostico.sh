#!/bin/bash
# diagnostico.sh — UNA línea: ¿el gateway responde 200 desde esta sesión?
#
# Uso: diagnostico.sh [--client <marca>]
#   código 0 = 200, la sesión puede producir; 1 = otra cosa, con el motivo.
#
# Pregunta algo barato y autenticado (motor-donde) con la misma regla de
# llave de todos los scripts: la llave de ~/.ia-nomads/config si existe, y
# si no, en una sesión en la nube de Anthropic, sin cabecera (el proxy del
# entorno adjunta Authorization: Bearer). No imprime la llave jamás.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
CLIENT=""
while [ $# -gt 0 ]; do
  case "$1" in --client) CLIENT="${2:-}"; shift 2 ;; *) shift ;; esac
done
CONFIG="${ENGINE_CONFIG:-$HOME/.ia-nomads/config}"
GATEWAY="${ENGINE_GATEWAY_URL:-https://app.ianomads.com}"
HOST="${GATEWAY#*://}"; HOST="${HOST%%/*}"

# shellcheck disable=SC1091
source "$DIR/_nube_sesion.sh"
ENGINE_SECRET="${ENGINE_SECRET:-}"
SALIDA="$(CLIENT="$CLIENT" CONFIG="$CONFIG" bash -c 'source "$1/_secret.sh" >/dev/null 2>&1 && printf "%s" "$ENGINE_SECRET"' _ "$DIR" 2>/dev/null)" || true
ENGINE_SECRET="$SALIDA"
if [ -n "$ENGINE_SECRET" ]; then VIA="llave de ~/.ia-nomads/config"
elif nube_sesion; then VIA="sin llave en disco, la pone el proxy de la nube (señal: $(nube_sesion_motivo))"
else
  echo "✗ sin llave: no hay ~/.ia-nomads/config y esta no es una sesión en la nube (el skill la pide)"
  exit 1
fi

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
CODE="$(curl -sS --connect-timeout 5 -m 20 -o "$TMP" -w '%{http_code}' -X POST "$GATEWAY/api/video-editor" \
  -H "content-type: application/json" -H "x-engine-secret: $ENGINE_SECRET" \
  -d '{"action":"motor-donde"}' 2>/dev/null)" || CODE=000
DONDE="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('motor_donde') or '')" "$TMP" 2>/dev/null || true)"
case "$CODE" in
  200) echo "✓ gateway $HOST responde 200 desde esta sesión · $VIA${DONDE:+ · la cuenta pinta en: $DONDE}"; exit 0 ;;
  000) echo "✗ gateway $HOST no responde (sin red hacia él): en la nube, revisar que $HOST esté en los dominios permitidos del entorno y como host del secreto de red"; exit 1 ;;
  401|403) echo "✗ gateway $HOST respondió $CODE: la llave no llegó o no vale · $VIA"
           [ -z "$ENGINE_SECRET" ] && nube_sesion_aviso_401
           exit 1 ;;
  *) echo "✗ gateway $HOST respondió $CODE · $VIA · $(head -c 160 "$TMP" | tr '\n' ' ')"; exit 1 ;;
esac
