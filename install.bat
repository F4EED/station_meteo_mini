@echo off
chcp 65001 >nul
title Station météo — installation
echo.
echo ========================================
echo   Station météo — installation Windows
echo ========================================
echo.
cd /d "%~dp0"

if not exist "%~dp0install.ps1" (
  echo Telechargement du script d'installation...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/F4EED/station_meteo_mini/main/install.ps1' -OutFile '%TEMP%\stmet-install.ps1'; powershell -NoProfile -ExecutionPolicy Bypass -File '%TEMP%\stmet-install.ps1'"
  if errorlevel 1 pause
  exit /b %ERRORLEVEL%
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 (
  echo.
  echo Echec de l'installation.
  pause
)
