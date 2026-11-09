@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-And-Run.ps1" %*
if errorlevel 1 (
  echo BUILD/LAUNCH FAILED. See the error above.
  pause
)
