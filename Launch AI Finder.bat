@echo off
setlocal EnableExtensions

rem Double-click this file in File Explorer to launch the AI Finder dev server.
rem It opens your browser automatically once Rails is ready.

cd /d "%~dp0" || goto :error

if not defined PORT set "PORT=3000"
set "URL=http://localhost:%PORT%"
set "AI_FINDER_URL=%URL%"

echo == AI Finder ==
echo Working in: %CD%

where bundle >NUL 2>NUL
if errorlevel 1 (
  echo Bundler not found - install Ruby and Bundler first ^(see README^).
  goto :error
)

where curl.exe >NUL 2>NUL
if errorlevel 1 (
  echo curl.exe not found - install a current Windows version or add curl to PATH.
  goto :error
)

echo == Checking dependencies ==
call bundle check >NUL 2>NUL
if errorlevel 1 (
  call bundle install || goto :error
)

call :server_responding
if not errorlevel 1 (
  echo == Server already running on %URL% ==
  call :check_database || goto :error
  start "" "%URL%"
  echo == Database checked; using existing server ==
  exit /b 0
)

call :check_database || goto :error

rem Start a quiet background helper that opens the browser after Rails responds.
start "" /B powershell -NoProfile -ExecutionPolicy Bypass -Command "$url = $env:AI_FINDER_URL; for ($i = 0; $i -lt 60; $i++) { try { Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 2 | Out-Null; break } catch { Start-Sleep -Seconds 1 } }; Start-Process $url" >NUL 2>NUL

echo == Starting server on %URL% ^(press Ctrl-C to stop^) ==
call bundle exec rails server -p "%PORT%" -b 127.0.0.1
set "EXIT_CODE=%ERRORLEVEL%"
echo.
echo == Server stopped ==
exit /b %EXIT_CODE%

:check_database
echo == Preparing database ==
call bundle exec rails db:prepare || exit /b 1
echo == Applying seed data ==
call bundle exec rails db:seed || exit /b 1
echo == Checking seed-backed DB data ==
call bundle exec rails ai_finder:verify_seed_data || exit /b 1
exit /b 0

:server_responding
curl.exe -fsS --max-time 2 -o NUL "%URL%" >NUL 2>NUL
exit /b %ERRORLEVEL%

:error
echo.
echo Launch failed. Check the messages above, then press any key to close.
pause >NUL
exit /b 1
