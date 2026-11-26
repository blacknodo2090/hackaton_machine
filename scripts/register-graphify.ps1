[CmdletBinding()]
param(
    [datetime]$At = '19:00',
    [string]$PythonPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot 'update_graphify.py'
$taskName = 'Hackaton-Graphify'

if (Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue) {
    throw "Ya existe la tarea '$taskName'. Edita su horario en el Programador de tareas."
}

if (-not $PythonPath) {
    $graphify = Get-Command graphify.exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $graphify) {
        throw 'Graphify no aparece en el PATH de esta cuenta. Usa -PythonPath con el python.exe de su entorno.'
    }
    $PythonPath = Join-Path (Split-Path -Parent $graphify.Source) 'python.exe'
}
$PythonPath = (Get-Item -LiteralPath $PythonPath).FullName

# Comprueba el entorno y genera el primer grafo antes de crear la tarea.
& $PythonPath $builder
if ($LASTEXITCODE -ne 0) {
    throw "La primera ejecucion de Graphify fallo (codigo $LASTEXITCODE)."
}

$account = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute $PythonPath -Argument ('"{0}"' -f $builder) -WorkingDirectory $projectRoot
$trigger = New-ScheduledTaskTrigger -Daily -At $At
$principal = New-ScheduledTaskPrincipal -UserId $account -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Actualiza el grafo local de documentacion de Hackaton.' | Out-Null
Get-ScheduledTaskInfo -TaskName $taskName | Select-Object TaskName, NextRunTime
