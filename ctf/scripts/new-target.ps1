<#
.SYNOPSIS
  Crea un directorio de objetivo nuevo copiando la plantilla _TEMPLATE.
.EXAMPLE
  .\new-target.ps1 maquina1
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Name
)

$ErrorActionPreference = "Stop"
$root     = Split-Path -Parent $PSScriptRoot          # ...\ctf
$template = Join-Path $root "targets\_TEMPLATE"
$dest     = Join-Path $root "targets\$Name"

if (Test-Path $dest) {
  Write-Host "Ya existe: $dest" -ForegroundColor Yellow
  exit 1
}
if (-not (Test-Path $template)) {
  Write-Host "No se encuentra la plantilla: $template" -ForegroundColor Red
  exit 1
}

Copy-Item -Recurse $template $dest
# Normaliza el titulo de NOTES.md
$notes = Join-Path $dest "NOTES.md"
(Get-Content $notes -Raw).Replace("<objetivo>", $Name) | Set-Content -Encoding utf8 $notes

Write-Host "Objetivo creado: $dest" -ForegroundColor Green
Write-Host "Siguiente paso: rellena SCOPE.md y confirma la autorizacion antes de escanear." -ForegroundColor Cyan
