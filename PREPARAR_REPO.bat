@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Preparar repo - CloudSync
if not defined LITHICA_BUILDS_ROOT set "LITHICA_BUILDS_ROOT=D:\LithicaBuilds"
set "CHECK_ARG="
if /i "%~1"=="--check-only" set "CHECK_ARG=-CheckOnly"
echo Preparando CloudSync...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0PREPARAR_REPO.ps1" -Product "CloudSync" -ProjectRoot "%~dp0" -TargetSet "QGIS" %CHECK_ARG%
set "EXIT_CODE=%ERRORLEVEL%"
echo.
echo Reporte: %LITHICA_BUILDS_ROOT%\CloudSync\logs\prepare-repo-last.txt
if not "%EXIT_CODE%"=="0" echo Preparacion incompleta. Revise el reporte indicado.
if "%EXIT_CODE%"=="0" if exist "%~dp0LITHICA.bat" echo Preparacion terminada. Ahora puede ejecutar LITHICA.bat.
if "%EXIT_CODE%"=="0" if not exist "%~dp0LITHICA.bat" echo Preparacion terminada. Este repo aun no tiene aplicacion ejecutable.
if "%~1"=="" pause
exit /b %EXIT_CODE%
