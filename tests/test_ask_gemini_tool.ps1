$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "test-ask-gemini-tool-$([guid]::NewGuid())"
$scriptDir = Join-Path $tempRoot 'scripts'
$toolsDir = Join-Path $tempRoot 'docs/tools'
$envBefore = @{ Path = $env:Path; TEMP = $env:TEMP; TMP = $env:TMP }
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-Test($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-GenerationFails([string]$Expected, [switch]$Actualizar) {
    try {
        & $scriptPath -Programa prueba -Actualizar:$Actualizar
    } catch {
        Assert-Test ($_.Exception.Message -like "*$Expected*") $_.Exception.Message
        return
    }
    throw "Se esperaba un error que incluyera: $Expected"
}

try {
    New-Item -ItemType Directory -Force -Path $scriptDir, $toolsDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'scripts/ask-gemini-tool.ps1') -Destination $scriptDir
    Copy-Item -LiteralPath (Join-Path $root 'docs/tools/TEMPLATE.md'), (Join-Path $root 'docs/tools/README.md') -Destination $toolsDir
    $scriptPath = Join-Path $scriptDir 'ask-gemini-tool.ps1'
    $indexPath = Join-Path $toolsDir 'README.md'
    $fichaPath = Join-Path $toolsDir 'prueba.md'
    $responsePath = Join-Path $toolsDir 'response.txt'
    $stdinPath = Join-Path $toolsDir 'stdin.txt'
    $originalIndex = [IO.File]::ReadAllText($indexPath)
    $response = [IO.File]::ReadAllText((Join-Path $toolsDir 'TEMPLATE.md'))
    $response = $response -replace '(?<=^# Ficha de herramienta: ).*', 'prueba'
    $response = $response -replace '\[[^\r\n\]]+\]', 'Dato de prueba'

    $fakeGemini = @'
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$docs = Join-Path $PSScriptRoot 'docs/tools'
[IO.File]::WriteAllText((Join-Path $docs 'stdin.txt'), [Console]::In.ReadToEnd())
[IO.File]::WriteAllText((Join-Path $docs 'args.txt'), ($args -join '|'))
$errorPath = Join-Path $docs 'error.txt'
if (Test-Path -LiteralPath $errorPath) {
    [Console]::Error.WriteLine([IO.File]::ReadAllText($errorPath))
    exit 1
}
[Console]::Write([IO.File]::ReadAllText((Join-Path $docs 'response.txt')))
'@
    [IO.File]::WriteAllText((Join-Path $tempRoot 'fake-gemini.ps1'), $fakeGemini, $utf8)
    [IO.File]::WriteAllText((Join-Path $tempRoot 'gemini.cmd'), '@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-gemini.ps1" %*')
    [IO.File]::WriteAllText((Join-Path $tempRoot 'help.txt'), ('A' * 20000) + 'FUERA_DEL_LIMITE')
    $env:Path = "$tempRoot;$env:Path"
    $env:TEMP = $tempRoot
    $env:TMP = $tempRoot

    [IO.File]::WriteAllText($responsePath, $response, $utf8)
    & $scriptPath -Programa PRUEBA -AyudaCmd 'type help.txt' -Modelo gemini-test
    $prompt = [IO.File]::ReadAllText($stdinPath)
    $cliArgs = [IO.File]::ReadAllText((Join-Path $toolsDir 'args.txt'))
    Assert-Test ($cliArgs -like '*--approval-mode|plan|--skip-trust|-o|text|-m|gemini-test') 'Argumentos headless incorrectos.'
    Assert-Test ($prompt.Contains(('A' * 20000)) -and -not $prompt.Contains('FUERA_DEL_LIMITE')) 'La ayuda local no tiene el limite esperado.'
    Assert-Test ([IO.File]::ReadAllText($fichaPath).Trim() -ceq $response.Trim()) 'La ficha publicada difiere de la respuesta.'

    Assert-GenerationFails 'Ya existe'
    $fence = [string][char]96 * 3
    $updated = $response -replace 'Dato de prueba', 'Dato actualizado'
    [IO.File]::WriteAllText($responsePath, "${fence}markdown`n$($updated.Trim())`n$fence", $utf8)
    & $scriptPath -Programa prueba -AyudaCmd 'echo ERROR_EN_AYUDA & exit /b 4' -Actualizar
    $cliArgs = [IO.File]::ReadAllText((Join-Path $toolsDir 'args.txt'))
    Assert-Test ($cliArgs -like '*|-m|gemini-3.5-flash-lite') 'Modelo por defecto incorrecto.'
    $prompt = [IO.File]::ReadAllText($stdinPath)
    Assert-Test ($prompt.Contains('No se adjunta ayuda local.') -and -not $prompt.Contains('ERROR_EN_AYUDA')) 'Se incluyo la salida de un comando de ayuda fallido.'
    Assert-Test ([IO.File]::ReadAllText($fichaPath).Trim() -ceq $updated.Trim()) 'No se actualizo la ficha o se alteraron sus bloques de codigo.'
    $indexed = [IO.File]::ReadAllText($indexPath)
    Assert-Test ($indexed.StartsWith($originalIndex)) 'Se alteraron lineas existentes del indice.'
    Assert-Test ([regex]::Matches($indexed, '\]\(prueba\.md\)').Count -eq 1) 'El indice debe incluir un solo enlace.'

    [IO.File]::WriteAllText($responsePath, '429 Too Many Requests')
    Assert-GenerationFails 'cuota de Gemini' -Actualizar
    $errorPath = Join-Path $toolsDir 'error.txt'
    [IO.File]::WriteAllText($errorPath, 'RESOURCE_EXHAUSTED')
    Assert-GenerationFails 'cuota de Gemini' -Actualizar
    [IO.File]::Delete($errorPath)
    [IO.File]::WriteAllText($responsePath, '# Ficha de herramienta: prueba')
    Assert-GenerationFails 'encabezados de la plantilla' -Actualizar
    Assert-Test ([IO.File]::ReadAllText($indexPath) -ceq $indexed) 'Se cambio el indice tras una generacion fallida.'
    Assert-Test ([IO.File]::ReadAllText($fichaPath).Trim() -ceq $updated.Trim()) 'Se cambio la ficha tras una generacion fallida.'
    Write-Host 'Pruebas de fichas OK.'
} finally {
    foreach ($name in $envBefore.Keys) { [Environment]::SetEnvironmentVariable($name, $envBefore[$name]) }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
