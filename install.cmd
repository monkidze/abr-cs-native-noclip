@echo off
title ABR Native Noclip Installer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set "install_result=%errorlevel%"
echo.
pause
exit /b %install_result%
