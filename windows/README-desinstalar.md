# Quitar el motor de un Windows

`windows/desinstalar.ps1` es el espejo de `windows/instalar.ps1`: deja el
computador como estaba antes de instalar el motor, sin perder nada de la
persona. Lo corre la sesión de Claude en Windows, no la persona.

## Antes de correrlo

Solo se corre cuando se cumplen las dos cosas:

1. Los videos pendientes de esa persona ya se entregaron a la app.
2. El trabajo en la nube (las sesiones de Claude en la nube) ya funciona
   para ella.

Hasta entonces el motor se queda en el computador tal como está.

## Cómo se pide

En una sesión de Claude en Windows (app de escritorio, pestaña Code, en
el Windows normal, no dentro de Ubuntu), la persona dice:

> "quita el motor de video de este computador"

La sesión baja el desinstalador y lo corre:

```powershell
irm https://raw.githubusercontent.com/elmochilerodigital/video-engine-plugin/main/windows/desinstalar.ps1 -OutFile "$env:TEMP\desinstalar.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\desinstalar.ps1"
```

Si el computador ya usaba WSL antes del motor (para otra cosa), se agrega
`-ConservarWsl` al final: quita Ubuntu y lo del motor pero deja WSL. El
desinstalador también deja WSL solo cuando encuentra otros Linux que no
son del motor.

A la persona se le habla en palabras simples, nunca de comandos. Lo único
que hace ella es decir Sí en la ventana de permiso de Windows y reiniciar
cuando se le pide.

## Qué hace, en orden

1. **Mira qué hay.** Si no encuentra nada del motor, termina con código 0
   y lo dice.
2. **Copia lo de la persona ANTES de borrar.** De la casa de Ubuntu copia
   la carpeta `videos`, la llave (`.ia-nomads/config`), las sesiones de
   Claude (`.claude`) y cualquier otra carpeta o archivo visible, a
   `D:\IA NOMADS CLIENTES\Respaldo Ubuntu <fecha>` (o al disco con más
   espacio si no hay D). No copia lo que se vuelve a bajar: el motor
   descargado (`.ia-nomads/engine`), la copia del skill y las
   `node_modules`. Comprueba que la copia tiene el mismo número de
   archivos y los mismos bytes que el origen; si no coincide, para con
   código 1 sin borrar nada. Deja un `LEEME.txt` en la copia.
3. **Quita Ubuntu**: lo desregistra de WSL, borra la carpeta a donde se
   movió (`D:\IA NOMADS CLIENTES\Ubuntu`, con su `ext4.vhdx`) solo si ya
   no está registrada y solo tiene ese disco, quita la app de Ubuntu de
   la tienda, los accesos directos "Videos IA Nomads" del escritorio y de
   `D:\IA NOMADS CLIENTES`, la copia del skill del lado Windows y el
   instalador descargado.
4. **Quita WSL** (salvo `-ConservarWsl`): `wsl --uninstall` si es la
   versión de la tienda, y desactiva con DISM las características
   "Subsistema de Windows para Linux" y "Plataforma de máquina virtual".
   Windows pide permiso de administrador (una ventana: decir Sí) y
   normalmente un reinicio. No toca la virtualización del BIOS ni nada
   que no haya puesto el instalador.
5. **Verifica y reporta**: que Ubuntu no esté en WSL, que no quede la
   carpeta del disco ni los accesos, que WSL esté desactivado y que la
   copia siga ahí. Imprime qué se quitó y dónde quedó la copia.

La carpeta `D:\IA NOMADS CLIENTES` no se borra: ahí queda la copia. La
persona decide qué hacer con ella.

## Códigos de salida

- **0**: listo. El reporte dice qué se quitó y dónde está la copia (o
  que no había nada del motor).
- **10**: WSL quedó desactivado y Windows necesita reiniciar. La persona
  reinicia y vuelve a decir "sigamos quitando el motor"; esa segunda
  corrida solo verifica.
- **1**: algo falló; el mensaje dice qué. Si falló la copia, no se borró
  nada y se puede volver a correr.

Se puede correr las veces que haga falta: cada vez sigue desde donde
quedó.

## Qué no se pudo probar

El desinstalador se probó en un Mac con `pwsh`: sintaxis, el flujo sin
Ubuntu (nada que quitar, restos sueltos, `-ConservarWsl`) y el flujo
completo con un `wsl.exe` y un `robocopy.exe` simulados (conteo del
origen con sus exclusiones, copia, verificación que detiene todo cuando
falta un archivo, borrado y reporte). No se ha corrido en un Windows
real: la primera corrida en vivo hay que mirarla, sobre todo la copia
desde `\\wsl.localhost` y el paso de DISM.
