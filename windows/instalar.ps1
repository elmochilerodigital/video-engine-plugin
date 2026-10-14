# instalar.ps1 — prepara un PC con Windows para el motor de video.
#
# Lo corre una sesión de Claude en Windows (app de escritorio, pestaña Code),
# no la persona. El motor corre en Linux, igual que en la nube: aquí eso es
# WSL con Ubuntu, y las sesiones de video se abren DENTRO de Ubuntu desde la
# misma app (Code › entorno › WSL › Ubuntu).
#
# Se corre las veces que haga falta; cada vez sigue desde donde quedó y
# termina con un código que le dice a la sesión qué hacer:
#   0   listo: abrir una sesión en WSL › Ubuntu, carpeta videos
#   10  se instaló WSL: reiniciar el computador y volver a correr esto
#   11  falta crear el usuario de Ubuntu: abrir Ubuntu desde el menú Inicio,
#       escribir un nombre y una contraseña, cerrar y volver a correr esto
#   1   algo falló: el mensaje dice qué
#
# Uso (PowerShell, lo corre la sesión):
#   irm https://raw.githubusercontent.com/elmochilerodigital/video-engine-plugin/main/windows/instalar.ps1 -OutFile "$env:TEMP\instalar.ps1"
#   powershell -ExecutionPolicy Bypass -File "$env:TEMP\instalar.ps1"

$ErrorActionPreference = 'Stop'
$Raw = 'https://raw.githubusercontent.com/elmochilerodigital/video-engine-plugin/main/windows'
$Distro = 'Ubuntu'

function Paso($t) { Write-Host "── $t ──" }
function Fin($codigo, $mensaje) { Write-Host $mensaje; exit $codigo }

# wsl.exe responde en UTF-16; se limpian los nulos para poder leerlo.
function Distros {
  try {
    $salida = & wsl.exe -l -q 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($salida | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
  } catch { return @() }
}

# 1. WSL con Ubuntu.
$hay = Distros | Where-Object { $_ -like "$Distro*" } | Select-Object -First 1
if (-not $hay) {
  Paso 'Instalando Linux (WSL con Ubuntu)'
  Write-Host 'Windows va a mostrar una ventana pidiendo permiso para hacer cambios: hay que decir Sí.'
  try {
    $p = Start-Process -FilePath 'wsl.exe' -ArgumentList '--install', '-d', $Distro -Verb RunAs -Wait -PassThru
  } catch {
    Fin 1 '✗ No se dio el permiso de administrador. Vuelve a correr el instalador y en la ventana de Windows di Sí.'
  }
  Fin 10 'REINICIAR: Linux quedó instalado. Reinicia el computador. Al volver, si se abre una ventana negra de Ubuntu pidiendo un nombre, escribe tu nombre en minúscula y una contraseña que recuerdes. Luego abre Claude y di: sigamos preparando el computador.'
}
$Distro = $hay

# 2. El usuario de Ubuntu (lo crea la persona la primera vez que se abre).
$usuario = (& wsl.exe -d $Distro -u root -- bash -c "getent passwd 1000 | cut -d: -f1" 2>$null | Out-String).Trim()
if (-not $usuario) {
  # Se abre la ventana de Ubuntu para que la persona cree su usuario: es lo
  # único del proceso que se escribe a mano.
  try { Start-Process -FilePath 'wsl.exe' -ArgumentList '-d', $Distro } catch { }
  Fin 11 'FALTA_USUARIO: se abrió una ventana negra de Ubuntu. Pide un nombre: escribe tu nombre en minúscula, sin espacios, y Enter. Luego pide una contraseña dos veces (no se ve mientras escribes, es normal). Cuando la ventana muestre una línea que termina en $, ciérrala, vuelve a Claude y di: sigamos preparando el computador.'
}
Write-Host "· Usuario de Ubuntu: $usuario"

# 3. Lo del sistema, como root: no pide contraseña.
Paso 'Preparando Ubuntu para el motor (la primera vez tarda entre 5 y 10 minutos)'
& wsl.exe -d $Distro -u root -- bash -c "curl -fsSL $Raw/ubuntu-root.sh | bash"
if ($LASTEXITCODE -ne 0) { Fin 1 '✗ La preparación de Ubuntu falló. El mensaje de arriba dice en qué paso.' }

# 4. Lo de la persona: el skill y la carpeta de videos.
Paso 'Instalando el skill del motor'
& wsl.exe -d $Distro -u $usuario -- bash -lc "curl -fsSL $Raw/ubuntu-usuario.sh | bash"
if ($LASTEXITCODE -ne 0) { Fin 1 '✗ No se pudo instalar el skill. El mensaje de arriba dice por qué.' }

# 5. Un acceso en el escritorio a la carpeta de videos de Ubuntu, para dejar
# el footage arrastrándolo desde Windows.
try {
  $escritorio = [Environment]::GetFolderPath('Desktop')
  $destino = "\\wsl.localhost\$Distro\home\$usuario\videos"
  $atajo = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $escritorio 'Videos IA Nomads.lnk'))
  $atajo.TargetPath = $destino
  $atajo.Save()
  Write-Host "· En el escritorio quedó la carpeta 'Videos IA Nomads' ($destino)"
} catch {
  Write-Host "· No pude crear el acceso del escritorio. La carpeta es \\wsl.localhost\$Distro\home\$usuario\videos"
}

Fin 0 "LISTO: el computador quedó preparado. Para trabajar: en Claude, pestaña Code, sesión nueva; en el selector de entorno elige WSL y luego $Distro, y como carpeta videos (o la carpeta del video dentro de videos). El footage se deja en la carpeta 'Videos IA Nomads' del escritorio."
