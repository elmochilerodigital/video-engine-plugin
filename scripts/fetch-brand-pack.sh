#!/bin/bash
# Jala el BRAND PACK del cliente desde la app (api/brand-pack) y lo materializa
# en un proyecto compuesto: brand.json → src/, product-scenes → src/scenes,
# catálogo de escenas de la marca → scenes-catalog/ (junto al proyecto, como
# referencia à la carte), sfx → public/sfx, logo → public/brand. El cliente
# lleva SOLO su api_secret
# (~/.ia-nomads/config: ENGINE_SECRET=<api_secret>).
# Uso: fetch-brand-pack.sh <carpeta-proyecto> [--client <marca>]
#   --client elige la llave de esa marca en máquinas con varias configuradas.
set -e

PROJ=""
CLIENT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --client) CLIENT="$2"; shift 2 ;;
    *) [ -z "$PROJ" ] && PROJ="$1"; shift ;;
  esac
done
CONFIG="${ENGINE_CONFIG:-$HOME/.ia-nomads/config}"
GATEWAY="${ENGINE_GATEWAY_URL:-https://app.ianomads.com}"
[ -z "$PROJ" ] && { echo "Uso: fetch-brand-pack.sh <carpeta-proyecto> [--client <marca>]"; exit 1; }

# shellcheck disable=SC1091
source "$(dirname "$0")/_secret.sh"

echo "── Jalando brand pack desde el gateway ──"
mkdir -p "$PROJ/src/scenes" "$PROJ/public/sfx" "$PROJ/public/brand"

ENGINE_SECRET="$ENGINE_SECRET" GATEWAY="$GATEWAY" PROJ="$PROJ" node <<'NODE'
const fs = require('fs');
const { ENGINE_SECRET, GATEWAY, PROJ } = process.env;
(async () => {
  const r = await fetch(GATEWAY + '/api/brand-pack', { headers: { 'x-client-secret': ENGINE_SECRET } });
  if (!r.ok) { console.error('✗ gateway ' + r.status + ': ' + (await r.text())); process.exit(1); }
  const j = await r.json();
  fs.writeFileSync(PROJ + '/src/brand.json', JSON.stringify(j.brand, null, 2) + '\n');
  console.log('  ✓ src/brand.json (' + j.brand.name + ')');
  const dl = async (url, dest) => {
    const x = await fetch(url);
    if (!x.ok) throw new Error(x.status + ' ' + dest);
    fs.writeFileSync(dest, Buffer.from(await x.arrayBuffer()));
  };
  for (const s of (j.productScenes || [])) { await dl(s.url, PROJ + '/src/scenes/' + s.name); console.log('  ✓ src/scenes/' + s.name); }
  // Catálogo de escenas de la marca (carpetas por escena + catalog.json/catalogo.md).
  // Se materializa como referencia à la carte; cada video importa las que use.
  const path = require('path');
  for (const s of (j.scenesCatalog || [])) {
    const dest = PROJ + '/scenes-catalog/' + s.path;
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    await dl(s.url, dest);
  }
  if ((j.scenesCatalog || []).length) console.log('  ✓ ' + j.scenesCatalog.length + ' archivos → scenes-catalog/ (catálogo de la marca)');
  for (const s of (j.sfx || [])) { await dl(s.url, PROJ + '/public/sfx/' + s.name); }
  console.log('  ✓ ' + (j.sfx || []).length + ' sfx → public/sfx');
  const fonts = j.fonts || [];
  if (fonts.length) {
    fs.mkdirSync(PROJ + '/public/fonts', { recursive: true });
    for (const f of fonts) { await dl(f.url, PROJ + '/public/fonts/' + f.name); }
    if (j.fontsManifest) fs.writeFileSync(PROJ + '/public/fonts/manifest.json', JSON.stringify(j.fontsManifest, null, 2) + '\n');
    console.log('  ✓ ' + fonts.length + ' fuentes → public/fonts (render offline y reproducible)');
  }
  const lg = j.brand.logo;
  if (lg && lg.startsWith('data:')) {
    const m = lg.match(/^data:([^;,]+)(;base64)?,(.*)$/s);
    if (m) {
      const ext = m[1].includes('svg') ? 'svg' : (m[1].split('/')[1] || 'png');
      const buf = m[2] ? Buffer.from(m[3], 'base64') : Buffer.from(decodeURIComponent(m[3]));
      fs.writeFileSync(PROJ + '/public/brand/logo.' + ext, buf);
      console.log('  ✓ public/brand/logo.' + ext);
    }
  } else if (lg) {
    // El logo llega como URL: la extensión sale de la ruta (sin query), para
    // que el proyecto lo referencie como public/brand/logo.<ext>.
    const ext = (new URL(lg).pathname.match(/\.([a-z0-9]+)$/i) || [, 'png'])[1];
    await dl(lg, PROJ + '/public/brand/logo.' + ext);
    console.log('  ✓ public/brand/logo.' + ext);
  }
})().catch((e) => { console.error('✗ ' + e.message); process.exit(1); });
NODE

echo ""
echo "✅ Brand pack materializado en $PROJ"
