@echo off
if /i "%DEV_RESOURCE_PROJECT%"=="CloudSync" goto :dev_resource_ready
set "DEV_RESOURCE_BATCH_ARGS=%*"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0.build-support\Invoke-ResourceTask.ps1" -Product CloudSync -BatchPath "%~f0"
exit /b %errorlevel%
:dev_resource_ready
@echo off
setlocal
chcp 65001 >nul
set "LITHICA_PREPARE_TARGETS=None"
call "%~dp0PREPARAR_REPO.bat" --auto
if errorlevel 1 exit /b 1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0package_plugin.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %EXIT_CODE%

