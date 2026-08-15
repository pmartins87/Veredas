@echo off
setlocal
cd /d "%~dp0"
echo ============================================================
echo Veredas da Trama - Teste fisico Android 11.3 - KIT V3
echo ============================================================
echo.
echo Primeiro sera validado o script no Windows PowerShell 5.1.
echo O teste de 30 minutos so comeca depois das medicoes iniciais.
echo Mantenha o celular conectado por USB durante todo o processo.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$tokens=$null; $errors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path '.\android_physical_soak_windows.ps1').Path,[ref]$tokens,[ref]$errors); if($errors.Count -ne 0){foreach($e in $errors){Write-Host $e.Message}; exit 17}; Write-Host 'PowerShell 5.1 parser: PASS'"
if errorlevel 1 (
  echo.
  echo VALIDACAO DO SCRIPT FALHOU. Nao inicie o soak.
  pause
  exit /b 17
)
if "%VEREDAS_VALIDATE_ONLY%"=="1" (
  echo Launcher validation only: PASS
  exit /b 0
)
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\android_physical_soak_windows.ps1" -Apk ".\veredas-debug.apk" -SoakSeconds 1800
set code=%ERRORLEVEL%
echo.
echo Script finalizado com codigo %code%.
if not "%code%"=="0" echo Envie ao ChatGPT a mensagem de erro acima.
if "%code%"=="0" echo Envie ao ChatGPT physical_device_evidence.json e veredas-physical-soak-raw.zip.
pause
exit /b %code%
