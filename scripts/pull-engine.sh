#!/bin/bash
# Bootstrap del CLIENTE: jala el MOTOR fresco desde el gateway de la app y lo
# extrae a un caché local. El cliente lleva SOLO su llave (en ~/.ia-nomads/config);
# el token de GitHub vive en el servidor, nunca en la máquina del cliente.
#
# Uso: pull-engine.sh [canal] [--client <marca>]   (canal por defecto: stable)
#   ENGINE_SECRET       (env) gana sobre el config
#   ~/.ia-nomads/config       ENGINE_SECRET=... [ENGINE_GATEWAY_URL=...]
#   ENGINE_HOME         (env) destino del motor  (default ~/.ia-nomads/engine)
#   --client <marca>    elige la llave de esa marca en máquinas con varias
set -e

# ── Auto-actualización del PLUGIN (best-effort, jamás bloquea) ──
# El plugin es un clon de git congelado al día de la instalación; este pull
# silencioso es la única vía por la que un fix del bootstrap llega solo a
# las máquinas de los clientes. Si el pull trae cambios, el script se
# re-ejecuta ya actualizado (guard contra loops por env).
if [ -z "$ENGINE_PLUGIN_UPDATED" ]; then
  export ENGINE_PLUGIN_UPDATED=1
  PLUGDIR="$(cd "$(dirname "$0")/.." && pwd)"
  BEFORE="$(git -C "$PLUGDIR" rev-parse HEAD 2>/dev/null || true)"
  git -C "$PLUGDIR" pull -q --ff-only 2>/dev/null || true
  AFTER="$(git -C "$PLUGDIR" rev-parse HEAD 2>/dev/null || true)"
  if [ -n "$BEFORE" ] && [ "$BEFORE" != "$AFTER" ]; then
    echo "── Plugin auto-actualizado ──"
    exec bash "$0" "$@"
  fi
fi

CHANNEL=""
CLIENT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --client) CLIENT="$2"; shift 2 ;;
    *) [ -z "$CHANNEL" ] && CHANNEL="$1"; shift ;;
  esac
done
CHANNEL="${CHANNEL:-stable}"
CONFIG="${ENGINE_CONFIG:-$HOME/.ia-nomads/config}"
DEST="${ENGINE_HOME:-$HOME/.ia-nomads/engine}"
GATEWAY="${ENGINE_GATEWAY_URL:-https://app.ianomads.com}"

# shellcheck disable=SC1091
source "$(dirname "$0")/_secret.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "── Jalando motor ($CHANNEL) desde el gateway ──"
code=$(curl -sS -w "%{http_code}" -o "$TMP/engine.tar.gz" \
  -H "x-engine-secret: $ENGINE_SECRET" \
  "$GATEWAY/api/engine?channel=$CHANNEL")

if [ "$code" != "200" ]; then
  echo "✗ El gateway respondió $code"
  head -c 300 "$TMP/engine.tar.gz" 2>/dev/null
  exit 1
fi

echo "── Extrayendo a $DEST ──"
rm -rf "$DEST"
mkdir -p "$DEST"
tar xzf "$TMP/engine.tar.gz" -C "$DEST" --strip-components=1

VER="(sin VERSION)"
[ -f "$DEST/VERSION" ] && VER="$(cat "$DEST/VERSION")"
echo ""
echo "✅ Motor actualizado en: $DEST"
echo "   canal: $CHANNEL · versión: $VER"
echo "   componer un video: $DEST/scripts/setup.sh <dest> <brand-pack> [footage]"
