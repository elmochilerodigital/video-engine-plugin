# Plugin del motor de video: reglas para todo agente

Este repo es el instalador y el skill que preparan un computador para el
motor. Lo bajan las maquinas de los clientes desde `main` en GitHub, asi
que cada push a main es un release.

- Dueño: Claude. Codex puede trabajar aqui, pero antes de tocar algo lo
  anota en `EN-CURSO.md` del repo de la web y le avisa a Carlos.
- Carpetas: Claude en `~/Development/video-engine-plugin`, Codex en
  `~/Development/video-engine-plugin-codex`. Nadie entra a la del otro.
- Lee `SKILL.md` y `README.md` antes de tocar nada.
- `windows/instalar.ps1` y los `ubuntu-*.sh` corren en maquinas de
  clientes sin nadie tecnico al frente: cada cambio se prueba en un
  Windows real o se dice claro que no se pudo probar.
- El skill instalado en este Mac (`~/.claude/skills/video-engine`) es un
  clon de este repo: tras un push, `git pull` ahi para tenerlo al dia.
- Las reglas compartidas de la casa estan en `AGENTS.md` del repo de la
  web (`ia-nomads-tools`).
- Commits con carlos@ianomads.com, en español, sin nombrar cuentas.
