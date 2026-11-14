@echo off
setlocal EnableExtensions
rem scrcpy-remote (Windows port of the repo's scrcpy-remote.sh)
rem Mirrors an Android device at full resolution with mouse/keyboard control.
rem Supports USB and TCP/IP (Wi-Fi ADB) transports, and MULTIPLE devices.
rem
rem Usage:
rem   scrcpy-remote.bat                 auto-detect (1 device: launch; many: picker)
rem   scrcpy-remote.bat --usb           only consider USB devices
rem   scrcpy-remote.bat --tcp           only consider TCP/IP ADB devices
rem   scrcpy-remote.bat --serial <id>   target a specific device (e.g. 192.168.22.114:5555)
rem   scrcpy-remote.bat --list          list ADB devices and exit
rem   scrcpy-remote.bat <scrcpy args>   pass straight to scrcpy (e.g. -m 1080 -f)
rem
rem NOTE: scrcpy itself fully supports multiple devices. To mirror several at
rem once, run one scrcpy window per device, each with its own --serial.

set "SCRCPY_DIR=%~dp0"
if "%SCRCPY_DIR:~-1%"=="\" set "SCRCPY_DIR=%SCRCPY_DIR:~0,-1%"
set "SCRCPY=%SCRCPY_DIR%\scrcpy.exe"

rem Prefer the full platform-tools adb (has full tooling), else the bundled adb.
if exist "%USERPROFILE%\android-sdk\platform-tools\adb.exe" (
  set "ADB=%USERPROFILE%\android-sdk\platform-tools\adb.exe"
) else (
  set "ADB=%SCRCPY_DIR%\adb.exe"
)

set MODE=auto
set SERIAL_OPT=
set EXTRA_ARGS=
set "DEVS=%TEMP%\scrcpy-remote-devs-%RANDOM%.txt"

:parse
if "%~1"=="" goto detect
if "%~1"=="--usb" ( set MODE=usb & shift & goto parse )
if "%~1"=="--tcp" ( set MODE=tcp & shift & goto parse )
if "%~1"=="--serial" goto serial
if "%~1"=="--list" ( "%ADB%" devices -l & pause & exit /b 0 )
if "%~1"=="--help" ( echo See the header comments of this script & pause & exit /b 0 )
set "EXTRA_ARGS=%EXTRA_ARGS% %~1"
shift
goto parse

:serial
if "%~2"=="" (
  echo ERROR: --serial needs a device id. Run --list to see available ids.
  pause
  exit /b 1
)
set SERIAL_OPT=%~2
shift
shift
goto parse

:collect
rem Write one device serial per line to stdout (USB first, then TCP/IP).
"%ADB%" devices 2>nul > "%DEVS%"
if not "%MODE%"=="tcp" (
  for /f "tokens=1" %%a in ('findstr /r "device" "%DEVS%" ^| findstr /r /v ":" ^| findstr /r /v "attached"') do (
    echo %%a
  )
)
if not "%MODE%"=="usb" (
  for /f "tokens=1" %%a in ('findstr /r "device" "%DEVS%" ^| findstr /r ":"') do (
    echo %%a
  )
)
goto :eof

:detect
set "DEVS2=%TEMP%\scrcpy-remote-list-%RANDOM%.txt"
call :collect > "%DEVS2%"

rem ---- Explicit --serial: validate it exists, then launch. ----
if not defined SERIAL_OPT goto count_devices
set "FOUND=0"
for /f "tokens=1" %%a in (%DEVS2%) do (
  if "%%a"=="%SERIAL_OPT%" set "FOUND=1"
)
if "%FOUND%"=="1" (
  set "SERIAL=%SERIAL_OPT%"
  echo Device: %SERIAL%
  goto launch
)
echo ERROR: device "%SERIAL_OPT%" is not in the current device list.
echo Current devices:
for /f "tokens=1" %%a in (%DEVS2%) do echo   - %%a
pause
exit /b 1

:count_devices
set "COUNT=0"
for /f "tokens=1" %%a in (%DEVS2%) do set /a COUNT+=1
if "%COUNT%"=="0" (
  echo ERROR: no ADB device found.
  echo   - Connect via USB, enable USB debugging, accept the RSA prompt; OR
  echo   - Use Wi-Fi ADB: run adb connect ^<device-ip^>:5555 first.
  echo   - List what adb sees: scrcpy-remote.bat --list
  pause
  exit /b 1
)
rem One device: launch it.
if "%COUNT%"=="1" (
  for /f "tokens=1" %%a in (%DEVS2%) do set "SERIAL=%%a"
  echo Device: %SERIAL%
  goto launch
)

rem Multiple devices: numbered picker (call :sub per line so the counter
rem increments correctly — cmd expands %vars% once before a for block).
set "PICK=%TEMP%\scrcpy-remote-pick-%RANDOM%.txt"
set "PICKN=0"
for /f "tokens=1" %%a in (%DEVS2%) do call :append_pick %%a
goto picker_done

:append_pick
set /a PICKN+=1
echo %PICKN% %~1>> "%PICK%"
goto :eof

:picker_done
echo.
echo Multiple devices connected - choose one:
type "%PICK%"
set /p "CHOICE=Enter number 1-%COUNT% (or blank to cancel): "
if "%CHOICE%"=="" (
  echo Cancelled.
  pause
  exit /b 0
)
set "SERIAL="
for /f "tokens=1" %%a in (%DEVS2%) do call :match_pick %%a
if not defined SERIAL (
  echo Invalid choice.
  pause
  exit /b 1
)
echo Device: %SERIAL%
goto launch

:match_pick
rem %~1 = serial; find its line number in PICK, compare to CHOICE.
set "LINENO="
for /f "tokens=1" %%n in ('findstr /r "%~1" "%PICK%"') do set "LINENO=%%n"
for /f "tokens=1" %%n in ("%LINENO%") do if "%%n"=="%CHOICE%" set "SERIAL=%~1"
goto :eof

:launch
del /q "%DEVS%" 2>nul
del /q "%DEVS2%" 2>nul
del /q "%PICK%" 2>nul
echo Starting scrcpy...
"%SCRCPY%" --serial "%SERIAL%" %EXTRA_ARGS%
endlocal
