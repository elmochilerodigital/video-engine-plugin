#!/bin/bash
# ubuntu-root.sh — deja el Ubuntu de WSL listo para el motor. Lo corre
# windows/instalar.ps1 como root (wsl -u root), así que no pide contraseña.
# Instala lo mismo que la imagen de la nube (nube/Dockerfile del motor):
# librerías de Chrome headless, fuentes, python con Pillow y numpy, ffmpeg
# FIJO en la serie 8.1 (build estático de BtbN), node 22 y whisper.cpp
# compilado en la versión del Mac. Idempotente: lo que ya está se salta.
set -e
export DEBIAN_FRONTEND=noninteractive
paso() { echo "── $* ──"; }

paso "Librerías del sistema"
apt-get update -qq
LIBASOUND=libasound2t64
apt-cache show libasound2t64 >/dev/null 2>&1 || LIBASOUND=libasound2
apt-get install -y -qq --no-install-recommends \
  build-essential cmake git curl ca-certificates xz-utils file procps bc \
  python3 python3-pip python3-pil python3-numpy \
  libnss3 libdbus-1-3 libatk1.0-0 libgbm-dev "$LIBASOUND" libxrandr2 libxkbcommon-dev \
  libxfixes3 libxcomposite1 libxdamage1 libatk-bridge2.0-0 libpango-1.0-0 libcairo2 libcups2 libcurl4 \
  fontconfig fonts-noto-color-emoji fonts-dejavu-core fonts-liberation2 >/dev/null
fc-cache -f >/dev/null 2>&1 || true

# ffmpeg y ffprobe: la misma serie que el Mac y la nube (8.1), el mismo build
# estático de BtbN que hornea la imagen de la nube, verificado por su sha256.
# Solo existe para x86_64, que es lo que traen los PC con Windows; en un
# equipo ARM se usa el ffmpeg de Ubuntu y se avisa. El tag es el último
# build de un mes, que BtbN guarda dos años (los diarios los borra a los 14
# días); va igual al de nube/Dockerfile del motor.
FFMPEG_TAG=autobuild-2026-09-30-13-08
FFMPEG_PKG=ffmpeg-n8.1.3-9-g29e619e767-linux64-gpl-8.1
FFMPEG_SHA256=97ce978979194b5cf7e06a5e68020dbdaa7a4f3294c5452b6a1bc347100dbb79
if ! ffmpeg -version 2>/dev/null | head -1 | grep -q "ffmpeg version n8.1"; then
  if [ "$(uname -m)" = x86_64 ]; then
    paso "ffmpeg 8.1"
    T="$(mktemp -d)"
    base="https://github.com/BtbN/FFmpeg-Builds/releases/download"
    # Si aun así el fijo ya no está, se usa el último de la misma serie 8.1
    # (la serie es lo que importa para que el local y la nube corten igual).
    if curl -fsSL -o "$T/ff.tar.xz" "$base/${FFMPEG_TAG}/${FFMPEG_PKG}.tar.xz"; then
      echo "${FFMPEG_SHA256}  $T/ff.tar.xz" | sha256sum -c - >/dev/null
    else
      echo "· El build fijo ya no está en GitHub: se usa el último de la serie 8.1"
      FFMPEG_PKG=ffmpeg-n8.1-latest-linux64-gpl-8.1
      curl -fsSL -o "$T/ff.tar.xz" "$base/latest/${FFMPEG_PKG}.tar.xz"
    fi
    tar xJf "$T/ff.tar.xz" -C "$T"
    install -m 755 "$T/${FFMPEG_PKG}/bin/ffmpeg" "$T/${FFMPEG_PKG}/bin/ffprobe" /usr/local/bin/
    rm -rf "$T"
  else
    paso "ffmpeg de Ubuntu (equipo ARM: no hay build 8.1 fijo para esta arquitectura)"
    apt-get install -y -qq ffmpeg >/dev/null
  fi
fi

# node 22, como la nube.
if ! node --version 2>/dev/null | grep -q '^v2[2-9]\.'; then
  paso "node 22"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null
  apt-get install -y -qq nodejs >/dev/null
fi

# whisper.cpp en la versión del Mac, compilado estático: un solo binario.
WHISPER_TAG=v1.9.1
if ! command -v whisper-cli >/dev/null 2>&1; then
  paso "whisper ${WHISPER_TAG} (compila unos minutos)"
  T="$(mktemp -d)"
  git -c advice.detachedHead=false clone -q --depth 1 --branch "$WHISPER_TAG" https://github.com/ggml-org/whisper.cpp "$T/w"
  cmake -S "$T/w" -B "$T/w/build" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF >/dev/null
  cmake --build "$T/w/build" -j"$(nproc)" --target whisper-cli >/dev/null
  install -m 755 "$T/w/build/bin/whisper-cli" /usr/local/bin/whisper-cli
  rm -rf "$T"
fi

echo "✓ Ubuntu listo: $(ffmpeg -version | head -1 | cut -d' ' -f1-3) · node $(node --version) · whisper-cli $(command -v whisper-cli)"
