<#
.SYNOPSIS
  Busca patrones de bandera (flag{...}, CTF{...}, etc.) en archivos de forma recursiva.
  Util tras volcar loot o extraer archivos de un reto.
.EXAMPLE
  .\flag-grep.ps1 -Path ..\targets\maquina1\loot
  .\flag-grep.ps1 -Path C:\ruta\dump -Pattern "HTB\{"
#>
param(
  [Parameter(Mandatory = $true)] [string]$Path,
  [string]$Pattern = "(flag|ctf|htb|key)\{[^}]{0,200}\}"
)

if (-not (Test-Path $Path)) { Write-Host "Ruta no encontrada: $Path" -ForegroundColor Red; exit 1 }

Write-Host "Buscando patron '$Pattern' en $Path ..." -ForegroundColor Cyan

Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
  $file = $_.FullName
  try {
    Select-String -Path $file -Pattern $Pattern -AllMatches -ErrorAction Stop | ForEach-Object {
      foreach ($m in $_.Matches) {
        [PSCustomObject]@{ File = $file; Line = $_.LineNumber; Match = $m.Value }
      }
    }
  } catch {}
} | Format-Table -AutoSize -Wrap

Write-Host "Nota: para binarios usa 'strings' antes, o busca tambien en base64/hex." -ForegroundColor DarkGray
