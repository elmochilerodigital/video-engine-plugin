#!/bin/bash
# SHIM de compatibilidad: la lógica real vive en el MOTOR (que llega fresco
# en cada video); este script solo delega. Así un fix del fetch se libera
# UNA vez en el motor y les llega a todos los clientes sin tocar el plugin.
ENGINE="${ENGINE_HOME:-$HOME/.ia-nomads/engine}"
if [ ! -f "$ENGINE/scripts/fetch-brand-pack.sh" ]; then
  echo "✗ El motor no está en $ENGINE — corre primero pull-engine.sh"
  exit 1
fi
exec bash "$ENGINE/scripts/fetch-brand-pack.sh" "$@"
