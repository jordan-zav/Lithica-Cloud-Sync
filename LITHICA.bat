@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Lithica Cloud Sync

if not defined LITHICA_BUILDS_ROOT set "LITHICA_BUILDS_ROOT=D:\LithicaBuilds"
if exist "%LITHICA_BUILDS_ROOT%\Shared\lithica-env-CloudSync.cmd" call "%LITHICA_BUILDS_ROOT%\Shared\lithica-env-CloudSync.cmd"
set "LITHICA_PRODUCT_ROOT=%LITHICA_BUILDS_ROOT%\CloudSync"
set "LITHICA_PRODUCT_KEY=CloudSync"
set "LITHICA_DEFAULT_TARGET=QGIS"
set "LITHICA_LOG_ROOT=%LITHICA_PRODUCT_ROOT%\logs"
if not exist "%LITHICA_LOG_ROOT%" mkdir "%LITHICA_LOG_ROOT%" >nul 2>&1
for /f %%I in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "LITHICA_RUN_ID=%%I"
set "LITHICA_LOG_FILE=%LITHICA_LOG_ROOT%\workflow-%LITHICA_RUN_ID%.log"
> "%LITHICA_LOG_FILE%" echo Lithica Cloud Sync - inicio %DATE% %TIME%

:menu
cls
echo ============================================================
echo   Lithica Cloud Sync
echo   Temporales: %LITHICA_PRODUCT_ROOT%
echo ============================================================
echo   [1] Abrir en desarrollo
echo   [2] Empaquetar cliente
echo   [3] Diagnostico
echo   [4] Salir
echo.
choice /c 1234 /n /m "Selecciona una opcion: "
if errorlevel 4 goto end
if errorlevel 3 goto diagnostic
if errorlevel 2 goto package_menu
if errorlevel 1 goto open

:open
call :workflow_start "Abrir en desarrollo"
call "%~dp0ABRIR_LITHICA_CLOUD_SYNC_EN_QGIS.bat"
set "LITHICA_EXIT_CODE=%ERRORLEVEL%"
call :workflow_end %LITHICA_EXIT_CODE%
goto menu

:package_menu
cls
echo ============================================================
echo   Lithica Cloud Sync - Empaquetar cliente
echo ============================================================
echo   [1] ZIP para QGIS
echo   [2] Volver
echo.
choice /c 12 /n /m "Selecciona un formato: "
if errorlevel 2 goto menu
if errorlevel 1 goto package_1
goto package_menu

:package_1
call :workflow_start "Empaquetar ZIP para QGIS"
call "%~dp0EMPAQUETAR_LITHICA_CLOUD_SYNC.bat"
set "LITHICA_EXIT_CODE=%ERRORLEVEL%"
call :workflow_end %LITHICA_EXIT_CODE%
goto menu

:diagnostic
call :step 1 5 "Preparando entorno"
if not exist "%LITHICA_PRODUCT_ROOT%" mkdir "%LITHICA_PRODUCT_ROOT%" >nul 2>&1
if not exist "%LITHICA_PRODUCT_ROOT%" (
  call :error "No se pudo crear %LITHICA_PRODUCT_ROOT%."
  goto menu
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\prepare-environment.ps1" -Product "%LITHICA_PRODUCT_KEY%" -Target "%LITHICA_DEFAULT_TARGET%" -ProjectRoot "%~dp0."
if errorlevel 1 (
  call :error "Diagnostico fallido. Revisa %LITHICA_LOG_ROOT%\environment-last.txt."
  pause
  goto menu
)
call :step 2 5 "Validando dependencias"
set "RUNTIME_OK="
if defined QGIS_BIN if exist "%QGIS_BIN%" set "RUNTIME_OK=QGIS_BIN"
where qgis-bin.exe >nul 2>&1 && set "RUNTIME_OK=PATH"
if not defined RUNTIME_OK for /f "delims=" %%I in ('dir /b /s "%ProgramFiles%\QGIS *\bin\qgis-bin.exe" 2^>nul') do if not defined RUNTIME_OK set "RUNTIME_OK=QGIS"
if not defined RUNTIME_OK (
  call :error "No se encontro QGIS. Configura QGIS_BIN o agrega QGIS al PATH."
  goto menu
)
call :ok "QGIS detectado."
call :step 3 5 "Validando temporales"
call :ok "Temporales disponibles en %LITHICA_PRODUCT_ROOT%."
call :step 4 5 "Validando registro"
call :ok "Registro disponible en %LITHICA_LOG_FILE%."
call :step 5 5 "Resultado"
call :ok "Diagnostico completado."
pause
goto menu

:workflow_start
echo Log completo: %LITHICA_LOG_FILE%
>> "%LITHICA_LOG_FILE%" echo %DATE% %TIME% Log completo: %LITHICA_LOG_FILE%
call :step 1 5 "Preparando entorno"
set "LITHICA_PREFLIGHT_TARGET=%LITHICA_DEFAULT_TARGET%"
echo %~1 | findstr /i "APK AAB Android" >nul && set "LITHICA_PREFLIGHT_TARGET=Android"
echo %~1 | findstr /i "Windows" >nul && set "LITHICA_PREFLIGHT_TARGET=Windows"
echo %~1 | findstr /i "QGIS ZIP" >nul && set "LITHICA_PREFLIGHT_TARGET=QGIS"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\prepare-environment.ps1" -Product "%LITHICA_PRODUCT_KEY%" -Target "%LITHICA_PREFLIGHT_TARGET%" -ProjectRoot "%~dp0."
if errorlevel 1 (
  call :error "El entorno no esta listo. Revisa environment-last.txt y el mensaje anterior."
  call :workflow_end 1
  goto menu
)
call :step 2 5 "Validando dependencias y configuracion"
call :ok "Entorno verificado para %LITHICA_PREFLIGHT_TARGET%."
call :step 3 5 "Ejecutando preparacion especifica de Lithica Cloud Sync"
call :step 4 5 "%~1"
exit /b 0

:workflow_end
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\capture-console.ps1" -LogPath "%LITHICA_LOG_FILE%" >nul 2>&1
if errorlevel 1 echo [ADVERTENCIA] No se pudo copiar el buffer completo, pero el resumen del workflow sigue disponible.
call :step 5 5 "Resultado"
if not "%~1"=="0" (
  call :error "La operacion fallo con codigo %~1. Revisa el mensaje anterior."
  echo Registro del workflow: %LITHICA_LOG_FILE%
  pause
  exit /b %~1
)
call :ok "Operacion completada."
echo Registro del workflow: %LITHICA_LOG_FILE%
pause
exit /b 0

:step
set "LITHICA_MESSAGE=[%~1/%~2] %~3"
echo.
echo %LITHICA_MESSAGE%
>> "%LITHICA_LOG_FILE%" echo %DATE% %TIME% %LITHICA_MESSAGE%
exit /b 0

:ok
echo [OK] %~1
>> "%LITHICA_LOG_FILE%" echo %DATE% %TIME% [OK] %~1
exit /b 0

:error
echo [ERROR] %~1
>> "%LITHICA_LOG_FILE%" echo %DATE% %TIME% [ERROR] %~1
exit /b 0

:end
>> "%LITHICA_LOG_FILE%" echo Lithica Cloud Sync - fin %DATE% %TIME%
endlocal
exit /b 0
