#!/bin/bash
# Bootstrap del CLIENTE: jala el MOTOR fresco desde el gateway de la app y lo
# extrae a un caché local. El cliente lleva SOLO su llave (en ~/.ia-nomads/config);
# el token de GitHub vive en el servidor, nunca en la máquina del cliente.
#
# Uso: pull-engine.sh [canal]        (canal por defecto: stable)
#   ENGINE_SECRET       (env) gana sobre el config
#   ~/.ia-nomads/config       ENGINE_SECRET=... [ENGINE_GATEWAY_URL=...]
#   ENGINE_HOME         (env) destino del motor  (default ~/.ia-nomads/engine)
set -e

CHANNEL="${1:-stable}"
CONFIG="${ENGINE_CONFIG:-$HOME/.ia-nomads/config}"
DEST="${ENGINE_HOME:-$HOME/.ia-nomads/engine}"
GATEWAY="${ENGINE_GATEWAY_URL:-https://ia-nomads-tools.vercel.app}"

# Llave: env var ENGINE_SECRET gana; si no, se lee del config del home.
if [ -z "$ENGINE_SECRET" ] && [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG"
fi
if [ -z "$ENGINE_SECRET" ]; then
  echo "✗ Falta ENGINE_SECRET. Ponlo en $CONFIG:  ENGINE_SECRET=..."
  exit 1
fi

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
