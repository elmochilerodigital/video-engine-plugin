#!/bin/bash
# _nube_sesion.sh — ¿esta sesión corre en la nube de Anthropic? Se carga
# con `source` y expone `nube_sesion` (código 0 = sí), `nube_sesion_motivo`
# (imprime la señal que lo decidió) y `nube_sesion_aviso_401` (el texto que
# se le suma a un 401 del gateway cuando se fue sin llave).
#
# En una sesión de Claude Code en la nube no hay llave en disco: la llave
# de la cuenta vive como "secreto de red" del entorno y el proxy de
# Anthropic la adjunta (Authorization: Bearer) a toda petición hacia el
# gateway, sin que la sesión la vea. Los scripts del motor siguen mandando
# x-engine-secret cuando hay llave (copia exacta de la del motor); sin llave mandan la petición sin esa
# cabecera y el gateway la autentica por el Bearer.
#
# Señales, en orden (solo estas; una marca suelta en ~/.ia-nomads no vale,
# para que una prueba en un Mac no deje al motor sin exigir llave):
#   ENGINE_NUBE_SESION=1|0   lo fuerza (pruebas, diagnóstico)
#   CLAUDE_CODE_REMOTE=true  la pone la VM de Anthropic en toda sesión
#   /etc/ia-nomads/nube      marca que deja el script de preparación del
#                            entorno (nube/setup.sh), como root
nube_sesion_motivo() {
  case "${ENGINE_NUBE_SESION:-}" in 1) echo "ENGINE_NUBE_SESION=1"; return 0 ;; 0) return 1 ;; esac
  [ "${CLAUDE_CODE_REMOTE:-}" = true ] && { echo "CLAUDE_CODE_REMOTE=true"; return 0; }
  [ -f /etc/ia-nomads/nube ] && { echo "la marca /etc/ia-nomads/nube"; return 0; }
  return 1
}
nube_sesion() { nube_sesion_motivo >/dev/null; }
# Para sumar a un 401/403 del gateway cuando la petición fue sin llave.
nube_sesion_aviso_401() {
  echo "  Esta sesión corre SIN llave porque $(nube_sesion_motivo || echo "ENGINE_AUTH_PROXY=1"): el proxy no adjuntó la llave."
  echo "  Revisar el secreto de red del entorno (host del gateway, cabecera Authorization con prefijo"
  echo "  Bearer) o, si esto no es una sesión en la nube, borrar la marca /etc/ia-nomads/nube."
}
