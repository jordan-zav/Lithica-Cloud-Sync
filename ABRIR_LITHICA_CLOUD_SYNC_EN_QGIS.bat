@echo off
setlocal
chcp 65001 >nul
title Lithica Cloud Sync - QGIS

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-qgis-plugin.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
    echo.
    echo [ERROR] No se pudo instalar o abrir Lithica Cloud Sync en QGIS.
    pause
)
endlocal & exit /b %EXIT_CODE%
