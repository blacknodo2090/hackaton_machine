@echo off
for %%I in (code.cmd code.exe code.bat code.com) do if not "%%~$PATH:I"=="" (
    "%%~$PATH:I" "%~dp0Hackaton.code-workspace"
    exit /b
)

echo Error: no se encontro 'code' en el PATH. 1>&2
echo Agrega Visual Studio Code al PATH y vuelve a abrir este archivo. 1>&2
pause
exit /b 1
