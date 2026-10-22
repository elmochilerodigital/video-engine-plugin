# desinstalar.ps1 — quita el motor de video de un PC con Windows y lo deja
# como estaba antes de windows/instalar.ps1, sin perder nada de la persona.
#
# Lo corre una sesión de Claude en Windows (app de escritorio, pestaña Code),
# no la persona. Es el espejo de instalar.ps1: primero copia al disco de
# Windows lo que es de la persona (su carpeta de videos, su llave y sus
# sesiones de Claude dentro de Ubuntu), comprueba que la copia está completa
# y SOLO entonces quita Ubuntu, los accesos directos, el skill y WSL.
#
# Solo se corre cuando los videos pendientes ya se entregaron y el trabajo en
# la nube ya funciona. Se corre las veces que haga falta; cada vez sigue
# desde donde quedó y termina con un código que le dice a la sesión qué hacer:
#   0   listo (o no había nada del motor): el reporte dice qué se quitó y
#       dónde quedó el respaldo
#   10  WSL quedó deshabilitado: reiniciar el computador y volver a correr
#       esto para verificar
#   1   algo falló: el mensaje dice qué. Si el respaldo no coincide con el
#       origen, no se borra nada.
#
# Opciones:
#   -ConservarWsl   deja WSL puesto y quita solo Ubuntu y lo del motor. Va
#                   si el computador ya usaba WSL antes del motor. También
#                   se acepta escrito --conservar-wsl.
#
# Uso (PowerShell, lo corre la sesión):
#   irm https://raw.githubusercontent.com/elmochilerodigital/video-engine-plugin/main/windows/desinstalar.ps1 -OutFile "$env:TEMP\desinstalar.ps1"
#   powershell -ExecutionPolicy Bypass -File "$env:TEMP\desinstalar.ps1"

param(
  [switch]$ConservarWsl,
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Resto
)
if ($Resto -contains '--conservar-wsl') { $ConservarWsl = $true }

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
if ($env:OS -ne 'Windows_NT') { Write-Host '✗ Esto es solo para Windows: en otro sistema no hay nada del instalador de Windows que quitar.'; exit 1 }

$Distro = 'Ubuntu'
$Carpeta = 'IA NOMADS CLIENTES'        # la carpeta del disco donde se movió Ubuntu
$Atajo = 'Videos IA Nomads.lnk'        # el acceso directo que dejó el instalador
$Fecha = Get-Date -Format 'yyyy-MM-dd'
$Quitado = @()                          # para el reporte final
$Respaldo = $null                       # dónde quedó la copia de esta corrida

function Paso($t) { Write-Host "── $t ──" }
function Fin($codigo, $mensaje) { Write-Host $mensaje; exit $codigo }
function MB($bytes) { return [math]::Round($bytes / 1MB, 1) }

# ── Cómo se ve WSL desde aquí ───────────────────────────────────────────────

function HayWsl { return [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue) }

# wsl.exe responde en UTF-16; se limpian los nulos para poder leerlo.
function Distros {
  if (-not (HayWsl)) { return @() }
  try {
    $salida = & wsl.exe -l -q 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    # Solo nombres de distribución (letras, números, punto, guion); así un
    # mensaje de wsl.exe nunca pasa por un Linux instalado.
    return @($salida | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ -match '^[\w.-]+$' })
  } catch { return @() }
}
function Responde($d) {
  if (-not (HayWsl)) { return $false }
  try {
    & wsl.exe -d $d -u root -- true 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
  } catch { return $false }
}
# La distribución del motor es exactamente "Ubuntu" (lo que instala
# instalar.ps1 con -d Ubuntu). Devuelve su nombre si está, o nada.
function Ubuntu {
  if ((Distros) -contains $Distro) { return $Distro }
  if (Responde $Distro) { return $Distro }
  return $null
}
# Corre un programa dentro de Ubuntu sin pasar por el shell de Linux (así los
# argumentos llegan tal cual) y devuelve sus líneas.
function Linux($d, $u, [string[]]$cmd) {
  try { $salida = & wsl.exe -d $d -u $u -e $cmd 2>$null } catch { throw "no pude correr dentro de Ubuntu: $($cmd -join ' ')" }
  if ($LASTEXITCODE -ne 0) { throw "falló dentro de Ubuntu: $($cmd -join ' ')" }
  return @($salida | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
}

# Estado de una característica de Windows sin pedir permiso de administrador:
# 1 = activada, 2 = desactivada, 3 = no existe, 0 = no se pudo leer.
function Caracteristica($n) {
  try {
    $f = Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='$n'" -ErrorAction Stop
    if ($f) { return [int]$f.InstallState }
  } catch { }
  return 0
}
function Paquete($n) {
  try { return [bool](Get-AppxPackage -Name $n -ErrorAction SilentlyContinue) } catch { return $false }
}
# Carpetas de disco que WSL tiene registradas como distribuciones (para no
# borrar nunca una carpeta que todavía esté en uso).
function CarpetasRegistradas {
  $r = @()
  try {
    Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction Stop | ForEach-Object {
      $b = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).BasePath
      if ($b) { $r += (($b -replace '^\\\\\?\\', '').TrimEnd('\')) }
    }
  } catch { }
  return $r
}
function DiscosFijos {
  try { return @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop | Where-Object { $_.DeviceID }) }
  catch {
    # Sin CIM (raro) se usan las unidades que ve PowerShell.
    return @(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -match '^[A-Za-z]$' -and $null -ne $_.Free } |
      ForEach-Object { [pscustomobject]@{ DeviceID = ($_.Name + ':'); FreeSpace = [long]$_.Free } })
  }
}

# ── Lo que dejó el instalador en el lado Windows ───────────────────────────

function Atajos {
  $sitios = @()
  foreach ($s in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('DesktopDirectory'),
                   (Join-Path $Perfil 'Desktop'), (Join-Path $Perfil 'OneDrive\Desktop'))) {
    if ($s) { $sitios += $s }
  }
  foreach ($d in DiscosFijos) { $sitios += (Join-Path ($d.DeviceID + '\') $Carpeta) }
  return @($sitios | Sort-Object -Unique | ForEach-Object { Join-Path $_ $Atajo } | Where-Object { Test-Path -LiteralPath $_ })
}
# La carpeta de disco de una distribución, leída de donde WSL la registra
# (si se movió de disco, es la carpeta nueva). Nada si no está registrada.
function CarpetaDeDistro($nombre) {
  try {
    foreach ($k in Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction Stop) {
      $v = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
      if ($v.DistributionName -eq $nombre -and $v.BasePath) { return (($v.BasePath -replace '^\\\\\?\\', '').TrimEnd('\')) }
    }
  } catch { }
  return $null
}
function RespaldosHechos {
  $r = @()
  foreach ($d in DiscosFijos) {
    $base = Join-Path ($d.DeviceID + '\') $Carpeta
    if (Test-Path -LiteralPath $base) {
      $r += @(Get-ChildItem -LiteralPath $base -Directory -Filter 'Respaldo Ubuntu *' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | ForEach-Object { $_.FullName })
    }
  }
  return $r
}
$Perfil = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$Temp = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$SkillWindows = Join-Path $Perfil '.claude\skills\video-engine'
$InstaladorTemp = Join-Path $Temp 'instalar.ps1'

# ── 1. ¿Hay algo del motor? ────────────────────────────────────────────────

Paso 'Mirando qué hay del motor en este computador'
$hayUbuntu = Ubuntu
$ubuntus = @(Distros | Where-Object { $_ -like "$Distro*" })
if ($ubuntus.Count -gt 1) {
  Fin 1 "✗ Hay más de un Ubuntu en WSL ($($ubuntus -join ', ')) y no puedo saber cuál es del motor y cuál de la persona. No toqué nada: hay que revisarlo a mano."
}
$otras = @(Distros | Where-Object { $_ -ne $Distro })
$carpetaDistro = $null
if ($hayUbuntu) { $carpetaDistro = CarpetaDeDistro $hayUbuntu }
$wslTienda = Paquete 'MicrosoftCorporationII.WindowsSubsystemForLinux'
$wslFeature = Caracteristica 'Microsoft-Windows-Subsystem-Linux'
$vmFeature = Caracteristica 'VirtualMachinePlatform'
$wslPuesto = (-not $ConservarWsl) -and ($otras.Count -eq 0) -and ($wslTienda -or $wslFeature -eq 1 -or $vmFeature -eq 1)
$restos = @()
$restos += Atajos
if (Test-Path -LiteralPath $InstaladorTemp) { $restos += $InstaladorTemp }

if ($hayUbuntu) { Write-Host "· Ubuntu está en WSL como '$hayUbuntu'" } else { Write-Host '· Ubuntu no está en WSL' }
if ($otras.Count -gt 0) { Write-Host "· Hay otros Linux en WSL que no son del motor y no se tocan: $($otras -join ', ')" }
if ($carpetaDistro) { Write-Host "· El disco de Ubuntu está en: $carpetaDistro" }
foreach ($r in $restos) { Write-Host "· Quedó del motor: $r" }
# La copia del skill del lado Windows no la puso el instalador: se avisa y se deja.
if (Test-Path -LiteralPath $SkillWindows) { Write-Host "· Hay una copia del skill en $SkillWindows; no es del instalador y se deja como está." }

if (-not $hayUbuntu -and $restos.Count -eq 0 -and -not $wslPuesto) {
  $previos = @(RespaldosHechos)
  $nota = ''
  if ($previos.Count -gt 0) { $nota = " El respaldo de la persona está en: $($previos[0])" }
  Fin 0 "NADA_QUE_QUITAR: en este computador no hay nada del motor de video.$nota"
}

# ── 2. Respaldo de lo que es de la persona, ANTES de borrar ───────────────

if ($hayUbuntu) {
  Paso 'Copiando lo de la persona fuera de Ubuntu'
  if (-not (Responde $hayUbuntu)) {
    Fin 1 "✗ Ubuntu está registrado pero no arranca, así que no puedo copiar lo que hay adentro. No borré nada. El disco de Ubuntu sigue en su carpeta ($carpetaDistro); hay que revisarlo a mano antes de quitarlo."
  }
  try {
  # La persona es el usuario normal de Ubuntu: uid de 1000 en adelante (65534
  # es "nobody"). Si no hay ninguno o hay varios, no se adivina: se para.
  $personas = @()
  foreach ($linea in (Linux $hayUbuntu root @('getent', 'passwd'))) {
    $campos = $linea -split ':'
    if ($campos.Count -lt 6) { continue }
    $uid = 0; if (-not [int]::TryParse($campos[2], [ref]$uid)) { continue }
    if ($uid -ge 1000 -and $uid -lt 65534) { $personas += [pscustomobject]@{ nombre = $campos[0]; casa = $campos[5] } }
  }
  if ($personas.Count -eq 0) { Fin 1 '✗ No encontré el usuario de la persona en Ubuntu. No borro nada: hay que revisarlo a mano.' }
  if ($personas.Count -gt 1) { Fin 1 "✗ Ubuntu tiene varios usuarios ($(($personas | ForEach-Object { $_.nombre }) -join ', ')) y no sé cuál es la persona. No borro nada: hay que revisarlo a mano." }
  $usuario = $personas[0].nombre
  $home_ = $personas[0].casa
  if (-not $home_ -or -not $home_.StartsWith('/')) { $home_ = "/home/$usuario" }
    Write-Host "· Usuario de Ubuntu: $usuario (su casa es $home_)"

    # Qué se copia: la carpeta de videos y cualquier otra carpeta o archivo
    # visible de su casa en Ubuntu, más su llave (.ia-nomads, sin el motor
    # descargado, que es de IA Nomads y se vuelve a bajar) y sus sesiones de
    # Claude (.claude, sin la copia del skill, que es este repo). Las
    # node_modules de los proyectos se saltan: son paquetes descargados.
    $carpetas = @(Linux $hayUbuntu root @('find', $home_, '-mindepth', '1', '-maxdepth', '1', '-type', 'd', '-printf', '%f\n'))
    $archivos = @(Linux $hayUbuntu root @('find', $home_, '-mindepth', '1', '-maxdepth', '1', '-type', 'f', '-printf', '%f\n'))
    $carpetas = @($carpetas | Where-Object { -not $_.StartsWith('.') -or $_ -eq '.ia-nomads' -or $_ -eq '.claude' })
    $archivos = @($archivos | Where-Object { -not $_.StartsWith('.') })
    $excluidas = @{ '.ia-nomads' = @('engine'); '.claude' = @('skills') }

    # Cuánto hay en el origen, contado desde adentro de Ubuntu (archivos y
    # bytes, sin enlaces ni lo excluido).
    $origen = @{}
    $totalArchivos = 0; $totalBytes = [long]0
    foreach ($c in $carpetas) {
      $cmd = @('find', "$home_/$c", '-type', 'f', '-not', '-path', '*/node_modules/*')
      foreach ($x in $excluidas[$c]) { $cmd += @('-not', '-path', "$home_/$c/$x/*") }
      $cmd += @('-printf', '%s\n')
      $tamanos = @(Linux $hayUbuntu root $cmd)
      $n = $tamanos.Count; $b = [long]0
      foreach ($t in $tamanos) { $b += [long]$t }
      $origen[$c] = @{ archivos = $n; bytes = $b; carpeta = $true }
      $totalArchivos += $n; $totalBytes += $b
      if ($c -eq 'videos' -and $n -eq 0) { Write-Host '· La carpeta videos está vacía: no hay videos que guardar.' }
      else { Write-Host "· $c`: $n archivos, $(MB $b) MB" }
    }
    foreach ($a in $archivos) {
      $t = @(Linux $hayUbuntu root @('stat', '-c', '%s', "$home_/$a"))
      $b = [long]$t[0]
      $origen[$a] = @{ archivos = 1; bytes = $b; carpeta = $false }
      $totalArchivos += 1; $totalBytes += $b
      Write-Host "· $a`: 1 archivo, $(MB $b) MB"
    }
    if ($carpetas -notcontains 'videos') { Write-Host '· No existe la carpeta videos en Ubuntu.' }

    if ($totalArchivos -eq 0) {
      Write-Host '· No había nada de la persona que copiar.'
    } else {
      # Dónde: D:\IA NOMADS CLIENTES si D existe y le cabe; si no, el disco
      # fijo con más espacio libre.
      $necesario = [long]($totalBytes * 1.05) + 200MB
      $discos = DiscosFijos
      $base = $null
      $d = $discos | Where-Object { $_.DeviceID -eq 'D:' } | Select-Object -First 1
      if ($d -and (Test-Path 'D:\') -and $d.FreeSpace -gt $necesario) { $base = 'D:\' }
      if (-not $base -and $discos.Count -eq 0 -and (Test-Path 'D:\')) { Write-Host '· No pude leer el espacio libre de los discos: uso D: sin comprobarlo.'; $base = 'D:\' }
      if (-not $base) {
        $d = $discos | Sort-Object FreeSpace -Descending | Select-Object -First 1
        if ($d -and $d.FreeSpace -gt $necesario) { $base = $d.DeviceID + '\' }
      }
      if (-not $base) { Fin 1 "✗ No hay un disco con espacio para la copia (hacen falta $(MB $necesario) MB libres). No borré nada." }
      $Respaldo = Join-Path (Join-Path $base $Carpeta) "Respaldo Ubuntu $Fecha"
      if (Test-Path -LiteralPath $Respaldo) { $Respaldo = "$Respaldo $(Get-Date -Format 'HHmm')" }
      New-Item -ItemType Directory -Path $Respaldo -Force | Out-Null
      $Respaldo = Convert-Path -LiteralPath $Respaldo
      Write-Host "· La copia va a: $Respaldo"

      # La casa de Ubuntu vista desde Windows.
      $casaWin = ($home_.TrimStart('/') -replace '/', '\')
      $unc = "\\wsl.localhost\$hayUbuntu\$casaWin"
      if (-not (Test-Path -LiteralPath $unc)) {
        $viejo = "\\wsl$\$hayUbuntu\$casaWin"
        if (Test-Path -LiteralPath $viejo) { $unc = $viejo } else { Write-Host "· Windows no confirma la ruta $unc; se intenta la copia igual." }
      }

      foreach ($nombre in $origen.Keys) {
        $destino = Join-Path $Respaldo $nombre
        if ($origen[$nombre].carpeta) {
          $rc = @("$unc\$nombre", $destino, '/E', '/COPY:DT', '/DCOPY:T', '/R:3', '/W:3', '/XJ', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XD', 'node_modules')
          foreach ($x in $excluidas[$nombre]) { $rc += "$unc\$nombre\$x" }
        } else {
          $rc = @($unc, $Respaldo, $nombre, '/COPY:DT', '/R:3', '/W:3', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
        }
        & robocopy.exe $rc | Out-Null
        if ($LASTEXITCODE -ge 8) { Fin 1 "✗ La copia de $nombre falló (robocopy terminó con $LASTEXITCODE; el origen es $unc\$nombre). No borré nada; lo copiado hasta ahora está en $Respaldo." }
      }

      # Se comprueba que la copia tiene los mismos archivos y los mismos bytes.
      Paso 'Comprobando la copia'
      $copiaArchivos = 0; $copiaBytes = [long]0
      foreach ($nombre in $origen.Keys) {
        $destino = Join-Path $Respaldo $nombre
        $n = 0; $b = [long]0
        if (Test-Path -LiteralPath $destino) {
          $lista = @(Get-ChildItem -LiteralPath $destino -Recurse -File -Force -ErrorAction SilentlyContinue)
          $n = $lista.Count
          foreach ($f in $lista) { $b += [long]$f.Length }
        }
        $copiaArchivos += $n; $copiaBytes += $b
        if ($n -ne $origen[$nombre].archivos -or $b -ne $origen[$nombre].bytes) {
          Fin 1 "✗ La copia de $nombre no coincide con el origen: en Ubuntu hay $($origen[$nombre].archivos) archivos ($(MB $origen[$nombre].bytes) MB) y en la copia quedaron $n ($(MB $b) MB). No borré nada. La copia incompleta está en $Respaldo."
        }
      }
      Write-Host "· Copia completa: $copiaArchivos archivos, $(MB $copiaBytes) MB, igual que en Ubuntu."

      @(
        "Copia de lo que había en el Ubuntu de este computador antes de quitar el motor de video.",
        "Hecha el $Fecha desde $unc.",
        "",
        "videos:      la carpeta de trabajo con los videos y proyectos (sin node_modules, que son paquetes descargables).",
        ".ia-nomads:  la llave de acceso (config). El motor descargado no se copia porque se vuelve a bajar.",
        ".claude:     las sesiones y ajustes de Claude dentro de Ubuntu (sin la copia del skill).",
        "Cualquier otra carpeta o archivo visible que hubiera en la casa de Ubuntu también está aquí.",
        "Los archivos ocultos de la casa fuera de .ia-nomads y .claude (por ejemplo .ssh, .gitconfig o .bashrc) NO se copiaron."
      ) | Out-File -FilePath (Join-Path $Respaldo 'LEEME.txt') -Encoding UTF8
    }
  } catch {
    $nota = ''
    if ($Respaldo) { $nota = " Lo copiado hasta ahora está en $Respaldo." }
    Fin 1 "✗ No pude terminar la copia de lo de la persona: $($_.Exception.Message). No borré nada.$nota"
  }
}

# ── 3. Quitar Ubuntu y lo que dejó el instalador en Windows ───────────────

if ($hayUbuntu) {
  Paso 'Quitando Ubuntu de WSL'
  try { & wsl.exe --shutdown 2>$null | Out-Null } catch { }
  try { & wsl.exe --unregister $hayUbuntu 2>$null | Out-Null } catch { }
  if (Ubuntu) { Fin 1 "✗ No se pudo quitar Ubuntu de WSL. Nada más se borró; el respaldo está en $Respaldo." }
  $Quitado += "Ubuntu (Linux) de WSL"
}

# La app de Ubuntu de la tienda, si la instalación la dejó.
if (-not (Ubuntu)) {
  try {
    $apps = @()
    if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) { $apps = @(Get-AppxPackage -Name 'CanonicalGroupLimited.Ubuntu*' -ErrorAction SilentlyContinue) }
    foreach ($app in $apps) { $app | Remove-AppxPackage -ErrorAction Stop; $Quitado += "la app de Ubuntu ($($app.Name))" }
  } catch { Write-Host "· No pude quitar la app de Ubuntu de la tienda: $($_.Exception.Message)" }
}

# La carpeta de disco de Ubuntu (la que WSL tenía registrada; si se movió de
# disco, la nueva). Al desregistrar WSL borra el ext4.vhdx pero puede dejar la
# carpeta; se borra solo si ya no está registrada y no tiene nada más que ese
# disco.
if ($carpetaDistro -and (Test-Path -LiteralPath $carpetaDistro)) {
  $c = $carpetaDistro
  if (@(CarpetasRegistradas) -contains $c) { Write-Host "· $c sigue registrada en WSL: no se toca." }
  else {
    $otros = @(Get-ChildItem -LiteralPath $c -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer -and $_.Extension -ne '.vhdx' })
    if ($otros.Count -gt 0) { Write-Host "· $c tiene archivos que no son de Ubuntu ($($otros.Count)): no se borra, revísala a mano." }
    else { Remove-Item -LiteralPath $c -Recurse -Force; $Quitado += "la carpeta del disco de Ubuntu ($c)" }
  }
}

foreach ($a in Atajos) { Remove-Item -LiteralPath $a -Force; $Quitado += "el acceso directo $a" }
if (Test-Path -LiteralPath $InstaladorTemp) { Remove-Item -LiteralPath $InstaladorTemp -Force; $Quitado += 'el instalador descargado' }

# ── 4. Quitar WSL (lo puso el instalador), salvo que se pida conservarlo ──

if ($ConservarWsl) {
  Write-Host '· WSL se deja puesto, como se pidió.'
} elseif ($otras.Count -gt 0) {
  Write-Host "· WSL se deja puesto porque tiene otros Linux que no son del motor: $($otras -join ', ')."
} elseif ($wslTienda -or $wslFeature -eq 1 -or $vmFeature -eq 1) {
  Paso 'Quitando WSL de Windows'
  Write-Host 'Windows va a mostrar una ventana pidiendo permiso para hacer cambios: hay que decir Sí.'
  $log = Join-Path $Temp 'desinstalar-admin.log'
  $admin = Join-Path $Temp 'desinstalar-admin.ps1'
  $lineas = @(
    '$ErrorActionPreference = ''Continue''',
    "`$log = '$log'",
    '"inicio" | Out-File -FilePath $log',
    '$reiniciar = $false',
    '& wsl.exe --shutdown 2>&1 | Out-Null'
  )
  if ($wslTienda) {
    $lineas += '$s = & wsl.exe --uninstall 2>&1'
    $lineas += '(("wsl --uninstall: $LASTEXITCODE " + ($s | Out-String)) -replace "`0", "") | Out-File -FilePath $log -Append'
  }
  foreach ($f in @('VirtualMachinePlatform', 'Microsoft-Windows-Subsystem-Linux')) {
    $estado = if ($f -eq 'VirtualMachinePlatform') { $vmFeature } else { $wslFeature }
    if ($estado -ne 1) { continue }
    $lineas += "`$s = & dism.exe /online /disable-feature /featurename:$f /norestart 2>&1"
    $lineas += '$c = $LASTEXITCODE'
    $lineas += "`"dism ${f}: `$c`" | Out-File -FilePath `$log -Append"
    $lineas += 'if ($c -eq 3010) { $reiniciar = $true } elseif ($c -ne 0) { ($s | Out-String) | Out-File -FilePath $log -Append; exit $c }'
  }
  $lineas += 'if ($reiniciar) { exit 3010 } else { exit 0 }'
  $lineas | Out-File -FilePath $admin -Encoding UTF8
  try {
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$admin`"") -Verb RunAs -Wait -PassThru
  } catch {
    Fin 1 '✗ No se dio el permiso de administrador. Ubuntu y lo del motor ya se quitaron; vuelve a correr esto y en la ventana de Windows di Sí para quitar WSL.'
  }
  if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | ForEach-Object { Write-Host "  $_" } }
  Remove-Item -LiteralPath $admin -Force -ErrorAction SilentlyContinue
  if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { Fin 1 "✗ Windows no pudo quitar WSL (terminó con $($p.ExitCode)). Ubuntu y lo del motor ya se quitaron; el detalle está arriba." }
  $Quitado += 'WSL de Windows'
  if ($p.ExitCode -eq 3010) {
    $nota = ''
    if ($Respaldo) { $nota = " La copia de lo de la persona está en $Respaldo." }
    Fin 10 "REINICIAR: WSL quedó quitado, pero Windows necesita reiniciar para terminar. Reinicia el computador, abre Claude y di: sigamos quitando el motor. Esa segunda corrida solo verifica.$nota"
  }
  Write-Host '· Windows no pidió reiniciar.'
} else {
  Write-Host '· WSL ya no está en Windows.'
}

# ── 5. Verificación final y reporte ────────────────────────────────────────

Paso 'Verificando que no quedó nada'
$problemas = @()
if (Ubuntu) { $problemas += 'Ubuntu sigue en WSL' }
if ($carpetaDistro -and (Test-Path -LiteralPath $carpetaDistro)) { $problemas += "sigue la carpeta del disco de Ubuntu $carpetaDistro" }
foreach ($a in Atajos) { $problemas += "sigue el acceso directo $a" }
if ($Respaldo -and -not (Test-Path -LiteralPath $Respaldo)) { $problemas += "la copia de $Respaldo ya no está" }
if (-not $ConservarWsl -and $otras.Count -eq 0) {
  if ((Caracteristica 'VirtualMachinePlatform') -eq 1) { $problemas += 'la Plataforma de máquina virtual sigue activada' }
  if ((Caracteristica 'Microsoft-Windows-Subsystem-Linux') -eq 1) { $problemas += 'el Subsistema de Windows para Linux sigue activado' }
  if (Paquete 'MicrosoftCorporationII.WindowsSubsystemForLinux') { $problemas += 'la app de WSL de la tienda sigue instalada' }
}
if ($problemas.Count -gt 0) { Fin 1 "✗ Quedó algo por quitar: $($problemas -join '; '). Vuelve a correr esto; si se repite, hay que mirarlo a mano." }

$dondeRespaldo = $Respaldo
if (-not $dondeRespaldo) { $previos = @(RespaldosHechos); if ($previos.Count -gt 0) { $dondeRespaldo = $previos[0] } }
$reporte = @('LISTO: el computador quedó como antes de instalar el motor de video.')
if ($Quitado.Count -gt 0) { $reporte += "Se quitó: $($Quitado -join '; ')." } else { $reporte += 'En esta corrida solo se verificó: todo ya estaba quitado.' }
if ($ConservarWsl) { $reporte += 'WSL se dejó puesto, como se pidió.' }
elseif ($otras.Count -gt 0) { $reporte += "WSL se dejó puesto porque tiene otros Linux: $($otras -join ', ')." }
else { $reporte += 'WSL quedó quitado de Windows.' }
if (Test-Path -LiteralPath $SkillWindows) { $reporte += "Queda una copia del skill en $SkillWindows; no era del instalador y se dejó." }
if ($dondeRespaldo) { $reporte += "La copia de lo de la persona (videos, llave y sesiones) está en: $dondeRespaldo. No se borra; la persona decide qué hacer con ella." }
else { $reporte += 'No hay ninguna copia de respaldo en este computador: no había nada de la persona que guardar.' }
Fin 0 ($reporte -join ' ')
