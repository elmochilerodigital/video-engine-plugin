#!/bin/bash
# _nube_sesion.sh — ¿esta sesión corre en la nube de Anthropic? Se carga
# con `source` y expone `nube_sesion` (código 0 = sí). Copia exacta de la
# del motor (scripts/_nube_sesion.sh): el plugin la necesita antes de que
# el motor esté descargado.
#
# En la nube no hay llave en disco: la llave de la cuenta es un "secreto
# de red" del entorno y el proxy de Anthropic la adjunta (Authorization:
# Bearer) a toda petición hacia el gateway. Los scripts mandan la petición
# sin la cabecera x-engine-secret y el gateway la autentica por el Bearer.
#
# Señales, en orden:
#   ENGINE_NUBE_SESION=1|0   lo fuerza (pruebas, diagnóstico)
#   CLAUDE_CODE_REMOTE=true  la pone la VM de Anthropic en toda sesión
#   /etc/ia-nomads/nube      marca que deja el script de preparación del
#   ~/.ia-nomads/nube        entorno (nube/setup.sh)
nube_sesion() {
  case "${ENGINE_NUBE_SESION:-}" in 1) return 0 ;; 0) return 1 ;; esac
  [ "${CLAUDE_CODE_REMOTE:-}" = true ] && return 0
  [ -f /etc/ia-nomads/nube ] && return 0
  [ -f "${HOME:-/nonexistent}/.ia-nomads/nube" ] && return 0
  return 1
}
