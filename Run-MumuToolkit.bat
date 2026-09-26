@echo off
setlocal
set "ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%ROOT%src\Invoke-MumuToolkit.ps1" %*
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" if "%~1"=="" pause
exit /b %CODE%
