<#
.SYNOPSIS
  Instala WSL2 + Kali y el arsenal de pentest. EJECUTAR COMO ADMINISTRADOR.
  Puede requerir un reinicio tras el primer paso; vuelve a lanzarlo despues.
.NOTES
  Clic derecho sobre PowerShell -> "Ejecutar como administrador", luego:
    cd C:\Users\juanp\Desktop\Hackaton\ctf\scripts
    Set-ExecutionPolicy -Scope Process Bypass -Force
    .\install-wsl.ps1
#>

$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
  Write-Host "Este script necesita PowerShell como ADMINISTRADOR. Abortando." -ForegroundColor Red
  exit 1
}

# Paso 1: nucleo WSL2 (puede pedir reinicio)
if (-not (wsl --status 2>$null)) {
  Write-Host "Instalando nucleo WSL2..." -ForegroundColor Cyan
  wsl --install --no-distribution
  Write-Host "Si pide reiniciar, reinicia y vuelve a ejecutar este script." -ForegroundColor Yellow
}

# Paso 2: distro Kali
$distros = (wsl -l -q 2>$null) -join "`n"
if ($distros -notmatch "kali") {
  Write-Host "Instalando Kali Linux (se abrira para crear usuario/contrasena)..." -ForegroundColor Cyan
  wsl --install -d kali-linux
  Write-Host "Crea tu usuario en la ventana de Kali y vuelve a ejecutar este script para instalar el arsenal." -ForegroundColor Yellow
  exit 0
}

# Paso 3: arsenal dentro de Kali
Write-Host "Instalando herramientas en Kali..." -ForegroundColor Cyan
$apt = "nmap ffuf gobuster sqlmap nikto binwalk exiftool john hashcat netcat-traditional net-tools dnsutils steghide foremost radare2 pipx"
wsl -d kali-linux -- bash -lc "sudo apt update && sudo apt install -y $apt && pipx install pwntools; pipx install impacket"

Write-Host "`nVerificacion:" -ForegroundColor Green
wsl -d kali-linux -- nmap --version
wsl -d kali-linux -- ffuf -V
Write-Host "Listo. Actualiza ctf\tools\INSTALL.md marcando WSL como OK." -ForegroundColor Green
