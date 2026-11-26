<#
.SYNOPSIS
  Reconocimiento inicial de red con nmap (Kali/WSL si esta disponible, si no nmap nativo).
  Vuelca resultados en targets\<Target>\loot\.
.EXAMPLE
  .\recon.ps1 -Target 10.10.10.5 -Name maquina1
.NOTES
  Requiere que exista targets\<Name>\SCOPE.md con la autorizacion confirmada.
#>
param(
  [Parameter(Mandatory = $true)] [string]$Target,
  [Parameter(Mandatory = $true)] [string]$Name
)

$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $PSScriptRoot            # ...\ctf
$tdir   = Join-Path $root "targets\$Name"
$loot   = Join-Path $tdir "loot"
$scope  = Join-Path $tdir "SCOPE.md"

if (-not (Test-Path $scope)) {
  Write-Host "No existe $scope. Crea el objetivo con new-target.ps1 y rellena SCOPE.md primero." -ForegroundColor Red
  exit 1
}
Write-Host "ATENCION: confirma que '$Target' esta dentro del alcance autorizado en SCOPE.md." -ForegroundColor Yellow
if (-not (Test-Path $loot)) { New-Item -ItemType Directory -Path $loot | Out-Null }

# Detecta motor de nmap: WSL Kali primero, luego nmap nativo.
$useWsl = $false
try {
  $distros = (wsl -l -q) -join "`n"
  if ($distros -match "kali" -or $distros -match "Ubuntu") { $useWsl = $true }
} catch {}

$outBase = "loot/nmap_$Name"

if ($useWsl) {
  Write-Host "Motor: nmap via WSL" -ForegroundColor Cyan
  Push-Location $tdir
  wsl -- nmap -sC -sV -p- -oA $outBase $Target
  Pop-Location
} else {
  $nmap = Get-ChildItem "C:\Program Files (x86)\Nmap\nmap.exe","C:\Program Files\Nmap\nmap.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $nmap) { Write-Host "nmap no encontrado (ni WSL ni nativo)." -ForegroundColor Red; exit 1 }
  Write-Host "Motor: nmap nativo Windows" -ForegroundColor Cyan
  & $nmap.FullName -sC -sV -p- -oA (Join-Path $tdir "loot\nmap_$Name") $Target
}

Write-Host "Recon terminado. Revisa $loot y anota lo relevante en NOTES.md." -ForegroundColor Green
