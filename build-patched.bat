@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title CC Desktop Switch - Patched Build

echo ========================================
echo    CC Desktop Switch - Patched Build
echo    Pulls latest from PR #3 and builds
echo ========================================
echo.

REM ── Step 0: preflight ──
cd /d "%~dp0"

where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found on PATH. Install Python 3.11+ from python.org.
    echo         Make sure "Add Python to PATH" was checked during install.
    pause
    exit /b 1
)

python --version
echo.

REM ── Step 1: fetch the patched code ──
echo [1/6] Fetching patched source from PR #3...
git --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] git not found on PATH. Install Git for Windows.
    pause
    exit /b 1
)

git fetch origin pull/3/head:pr-3 2>nul
if errorlevel 1 (
    echo [WARN] Could not fetch PR #3 from origin. Falling back to local main.
)

git checkout pr-3 2>nul
if errorlevel 1 (
    echo [INFO] No remote PR; checking out local main.
    git checkout main
    git pull
)
echo.

REM ── Step 2: install dependencies ──
echo [2/6] Installing Python dependencies...
python -m pip install --upgrade pip
if errorlevel 1 goto :error

python -m pip install -r requirements.txt
if errorlevel 1 goto :error

python -m pip install pyinstaller
if errorlevel 1 goto :error
echo.

REM ── Step 3: build folder variant (fast startup, recommended for testing) ──
echo [3/6] Building folder variant (fast startup)...
set CCDS_ONEFILE=
pyinstaller --noconfirm --clean build.spec
if errorlevel 1 goto :error
echo.

REM ── Step 4: build one-file variant ──
echo [4/6] Building one-file variant (portable .exe)...
set CCDS_ONEFILE=1
pyinstaller --noconfirm --clean build.spec
if errorlevel 1 goto :error
set CCDS_ONEFILE=
echo.

REM ── Step 5: optionally build NSIS installer ──
echo [5/6] Optional: build NSIS installer?
set /p BUILD_NSIS="    Type Y to build the Setup installer (requires NSIS), else N: "
if /i "%BUILD_NSIS%"=="Y" (
    where makensis >nul 2>&1
    if errorlevel 1 (
        echo [INFO] NSIS not found. Install with: choco install nsis -y --no-progress
        echo        Or download from https://nsis.dev/
        goto :skip_nsis
    )
    makensis /DPRODUCT_VERSION=1.0.26 installer.nsi
    if errorlevel 1 goto :error
)
:skip_nsis
echo.

REM ── Step 6: summary ──
echo [6/6] Build complete. Artifacts:
echo.
if exist "dist\CC-Desktop-Switch\CC-Desktop-Switch.exe" (
    echo   [folder]   dist\CC-Desktop-Switch\CC-Desktop-Switch.exe
)
if exist "dist\CC-Desktop-Switch.exe" (
    echo   [onefile]  dist\CC-Desktop-Switch.exe
)
if exist "CC-Desktop-Switch-Setup-1.0.26.exe" (
    echo   [installer] CC-Desktop-Switch-Setup-1.0.26.exe
)
echo.

echo ========================================
echo   Next steps:
echo   1. Close any running CC Desktop Switch.
echo   2. Run dist\CC-Desktop-Switch\CC-Desktop-Switch.exe
echo      OR  dist\CC-Desktop-Switch.exe
echo   3. Open the kilo provider form.
echo   4. Add modelCapabilities for minimax/minimax-m3:
echo        supports1m: true, supportsImages: true
echo   5. Click "Apply to Claude Desktop".
echo   6. Quit Claude Desktop fully (tray ^> Quit), reopen.
echo   7. Verify:
echo        reg query "HKCU\SOFTWARE\Policies\Claude" /v inferenceModels
echo      should now show "supports1m":true on claude-opus-4-7.
echo ========================================
echo.
pause
exit /b 0

:error
echo.
echo [BUILD FAILED] See output above for the failing step.
pause
exit /b 1