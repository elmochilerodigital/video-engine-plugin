# Producir videos desde la nube: los seis pasos

No hay que instalar nada en tu computador. Los videos se producen en una
sesión de Claude que corre en la nube de Anthropic, con tu propia cuenta de
Claude, y el motor de video de IA Nomads hace el resto. Esta página se hace
una sola vez; después cada video es abrir una sesión y pedirlo.

Vas a necesitar tres cosas: una cuenta de Claude con plan de pago, una
cuenta de GitHub (gratis) y la llave que te entregó IA Nomads.

## 1 · Un plan de Claude

Entra a [claude.ai](https://claude.ai) y asegúrate de tener un plan Pro,
Max o Team. Las sesiones en la nube vienen con el plan: no hay un cobro
aparte por la máquina, y cada video consume de tu uso mensual de Claude.

## 2 · Una cuenta de GitHub (gratis)

Crea una cuenta en [github.com](https://github.com) si no tienes. No vas a
programar nada: Claude la usa para abrir, en la nube, la carpeta con el
"arrancador" del motor. La cuenta gratuita sirve.

## 3 · Conectar GitHub en claude.ai/code

1. Entra a [claude.ai/code](https://claude.ai/code).
2. La primera vez te pide conectar GitHub: acepta y autoriza la aplicación
   de Claude en tu cuenta de GitHub.
3. Cuando te pregunte qué repositorio abrir, escribe o pega:

   ```text
   elmochilerodigital/video-engine-plugin
   ```

   Es público: no hace falta pedir acceso.

## 4 · Crear el entorno (pegando tres bloques)

En claude.ai/code, antes de escribir el primer mensaje, hay un selector de
entorno debajo de la caja de texto. Ábrelo, elige **New environment** y
llena el formulario así. Nombre: `Motor de video`.

**Bloque 1 · Red.** En *Network access* elige **Custom**, marca la casilla
que dice incluir la lista de gestores de paquetes (*Also include default
list of common package managers*) y pega esto en *Allowed domains*:

```text
app.ianomads.com
nryqfezguccbmvukqxel.supabase.co
storage.googleapis.com
raw.githubusercontent.com
```

**Bloque 2 · Script de preparación.** Pega en *Setup script* el contenido
completo del archivo [`nube/setup.sh`](../nube/setup.sh) de este
repositorio (ábrelo en GitHub, botón *Raw*, selecciona todo y copia). Tarda
menos de un minuto: instala ffmpeg y dos librerías de Python, y deja la
marca de que esto es la nube. No instala nada más. Corre la primera vez y
se guarda; vuelve a correr solo cuando cambias el script o los dominios y
cada siete días más o menos, cuando caduca lo guardado. Verlo correr de
nuevo es normal.

Guarda el entorno con **Add environment**.

**Bloque 3 · La llave, como secreto de red.** Vuelve a abrir el entorno
que acabas de crear (ícono de ajustes en su fila), baja a *Network
secrets* y pulsa **Add secret**:

| Campo | Qué poner |
|---|---|
| Name | `Llave del motor de video` |
| Secret type | `Bearer` (el que viene por defecto) |
| Allowed websites | `app.ianomads.com` |
| Custom headers | deja `Authorization` con prefijo `Bearer` y pega en *Value* la llave que te entregó IA Nomads |

Si tu formulario es más corto y solo pide **Host** y **Value** (pasa en
el plan Team cuando tu usuario no es administrador de la organización):
Host `app.ianomads.com`, tipo **Token**, y en Value la llave. Funciona
igual. En el plan Enterprise solo un administrador de la organización
puede agregar el secreto: pídele que lo haga en el entorno, o que cree un
entorno compartido con estos tres bloques.

Pulsa **Add**. La llave queda guardada fuera de la sesión: Claude nunca la
ve, no aparece en ningún archivo y no hay que pegarla en el chat. Si algún
día te dan otra llave, se borra este secreto y se agrega de nuevo (no se
edita).

## 5 · Tu primer video

Abre una sesión nueva en claude.ai/code con el repositorio
`elmochilerodigital/video-engine-plugin` y el entorno `Motor de video`.
Copia el ID del video desde su tarjeta en el Planner y escribe:

> edita este video: `<el id de la tarjeta>`

La sesión revisa sola que todo responde, descarga el motor y te pregunta
una sola cosa: si lo quieres **exprés** (lo hace entero y lo deja en la
tarjeta para revisar) o **asistida** (te lo va mostrando por partes).
Desde ahí, la tarjeta en el Planner te dice en qué va; el video terminado
llega a la misma tarjeta, en *Revisar*.

Para saber qué hay listo para producir, basta con preguntarlo en la misma
sesión: "qué videos hay aprobados para producir".

## 6 · Después: lo que conviene saber

- **Cada sesión es un video.** Al terminar uno, abre otra sesión para el
  siguiente; la lista de la izquierda guarda las anteriores.
- **Si la sesión estuvo quieta mucho rato**, la máquina de la nube se
  apaga y la conversación se conserva. Al volver a escribirle, Claude
  revisa si la carpeta del video sigue; si no, la rehace desde la nube de
  IA Nomads y sigue donde iba. No tienes que hacer nada especial.
- **Si algo de la red falla**, la primera línea que escribe la sesión lo
  dice en palabras simples: casi siempre es un dominio que faltó en el
  bloque 1 o el secreto del bloque 3 que no quedó. Se corrige en el
  entorno y se abre una sesión nueva.
- **Cambiar de llave**: borrar el secreto de red y agregarlo de nuevo con
  la llave nueva. Nada más cambia.
