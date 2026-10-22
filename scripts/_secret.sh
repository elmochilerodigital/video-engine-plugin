#!/bin/bash
# Resuelve con qué llave hablarle al gateway. Se carga con `source`.
#
# Una máquina normal tiene una sola marca:
#   ~/.ia-nomads/config
#     ENGINE_SECRET=<llave>
#
# Una máquina que produce para varias marcas las declara todas y elige con
# --client <marca>:
#   ~/.ia-nomads/config
#     ENGINE_SECRET=<la de siempre>          ← la que se usa sin --client
#     ENGINE_SECRET_<MARCA>=<llave>          ← marca en MAYÚSCULAS, - pasa a _
#
# Prioridad: --client  >  ENGINE_SECRET del entorno  >  ENGINE_SECRET del config.
# Entradas: $CLIENT (marca pedida, puede ir vacía) y $CONFIG (ruta del config).
# Salida: $ENGINE_SECRET resuelto, o corta con un mensaje claro.

_env_secret="$ENGINE_SECRET"
if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG"
fi
# El entorno pisa al config, salvo que se pida una marca concreta.
[ -n "$_env_secret" ] && ENGINE_SECRET="$_env_secret"

if [ -n "$CLIENT" ]; then
  _key="ENGINE_SECRET_$(printf '%s' "$CLIENT" | tr '[:lower:]-' '[:upper:]_')"
  eval "_sel=\${$_key:-}"
  if [ -z "$_sel" ]; then
    # shellcheck disable=SC1091
    source "$(dirname "${BASH_SOURCE[0]}")/_nube_sesion.sh"
    if ! nube_sesion; then
      echo "✗ No hay llave para \"$CLIENT\": falta $_key en $CONFIG"
      exit 1
    fi
  fi
  ENGINE_SECRET="$_sel"
fi

# Sesión en la nube de Anthropic (_nube_sesion.sh): no hay llave en disco
# y no hace falta. El proxy del entorno adjunta Authorization: Bearer a
# toda petición hacia el gateway; curl omite la cabecera x-engine-secret
# cuando va vacía, y ENGINE_AUTH_PROXY=1 se lo dice a quien lo necesite.
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/_nube_sesion.sh"
if [ -z "$ENGINE_SECRET" ] && nube_sesion; then
  ENGINE_SECRET=""
  ENGINE_AUTH_PROXY=1
  export ENGINE_AUTH_PROXY
fi

if [ -z "$ENGINE_SECRET" ] && [ -z "${ENGINE_AUTH_PROXY:-}" ]; then
  echo "✗ No hay llave para esta operación. En máquinas de UNA marca:"
  echo "  ENGINE_SECRET=<llave> en $CONFIG. Con varias marcas: pasa"
  echo "  --client <marca> (las llaves van como ENGINE_SECRET_<MARCA>,"
  echo "  sin default — el sistema nunca adivina la marca)."
  exit 1
fi
