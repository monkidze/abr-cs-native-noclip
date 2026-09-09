@echo off
title ABR Native Noclip Uninstaller
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
set "install_result=%errorlevel%"
echo.
pause
exit /b %install_result%
