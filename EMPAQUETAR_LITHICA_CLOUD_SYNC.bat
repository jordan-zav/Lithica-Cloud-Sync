@echo off
setlocal
chcp 65001 >nul
set "LITHICA_PREPARE_TARGETS=None"
call "%~dp0PREPARAR_REPO.bat" --auto
if errorlevel 1 exit /b 1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0package_plugin.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %EXIT_CODE%

