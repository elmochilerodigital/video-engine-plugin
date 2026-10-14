#!/bin/bash
# ubuntu-usuario.sh — la parte del Ubuntu de WSL que es de la persona, no del
# sistema: el skill del motor en su ~/.claude/skills y la carpeta ~/videos
# donde deja el footage. Lo corre windows/instalar.ps1 con el usuario de
# Ubuntu. Idempotente.
set -e
SKILL="$HOME/.claude/skills/video-engine"
if [ -d "$SKILL/.git" ]; then
  git -C "$SKILL" pull -q --ff-only || true
else
  mkdir -p "$HOME/.claude/skills"
  git clone -q https://github.com/elmochilerodigital/video-engine-plugin.git "$SKILL"
fi
mkdir -p "$HOME/videos"
bash "$SKILL/scripts/preparar.sh" --revisar
echo "✓ Skill del motor en $SKILL y carpeta de videos en $HOME/videos"
