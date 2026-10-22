# Sesión en la nube: lo que se pega en el entorno

Tres bloques, los tres copiados tal cual en el entorno de claude.ai/code
(la guía paso a paso para la persona: `docs/onboarding-nube.md`).

## 1 · Dominios permitidos (`dominios.txt`)

Red del entorno en **Custom**, con la casilla "incluir la lista de
gestores de paquetes" marcada (ahí viven los mirrors de Ubuntu, PyPI y
GitHub que el script de preparación necesita), y estos dominios, uno por
línea:

| Dominio | Para qué |
|---|---|
| `app.ianomads.com` | el gateway: motor, marca, tarjetas, trabajos de la nube, latidos |
| `nryqfezguccbmvukqxel.supabase.co` | los archivos firmados que el gateway entrega: footage de la tarjeta, logo y sonidos de la marca, aportes, fichas de formato |
| `storage.googleapis.com` | subir el paquete delgado a la nube de IA Nomads y bajar lo que sale (hojas, gate, pedacitos) |
| `raw.githubusercontent.com` | archivos sueltos de este plugin |

El gateway queda además como host del secreto de red (bloque 3): por esa
vía se alcanza aunque no estuviera en la lista.

## 2 · Script de preparación (`setup.sh`)

El contenido de `setup.sh`, entero. Corre como root una vez; instala
ffmpeg, Pillow, numpy y bc, clona el plugin como skill y deja la marca de
"esto es la nube". Sin whisper, sin Remotion, sin llaves.

## 3 · Secreto de red

| Campo | Valor |
|---|---|
| Nombre | `Llave del motor de video` (o cualquiera) |
| Tipo | Bearer |
| Allowed websites | `app.ianomads.com` |
| Cabecera | `Authorization`, prefijo `Bearer`, valor: la llave que entregó IA Nomads |

El proxy de Anthropic adjunta `Authorization: Bearer <llave>` a toda
petición de la sesión hacia ese host; la sesión nunca ve la llave y los
scripts no la piden ni la guardan.

## Qué prueba `scripts/diagnostico.sh`

Una línea: si el gateway responde 200 desde esta sesión y por dónde llegó
la llave. Es lo primero que corre el skill en la nube.
