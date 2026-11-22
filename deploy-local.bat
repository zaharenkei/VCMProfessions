@echo off
setlocal

set "SOURCE=%~dp0Contents\mods\VCMProfessions"
set "MODS_DIR=%USERPROFILE%\Zomboid\mods"
set "DEST_DIR=%MODS_DIR%\VCMProfessions"

if not exist "%SOURCE%\mod.info" (
    echo Source mod folder not found: "%SOURCE%"
    exit /b 1
)

if not exist "%~dp0LICENSE" (
    echo License file not found: "%~dp0LICENSE"
    exit /b 1
)

if not exist "%MODS_DIR%" (
    echo Mods directory not found: "%MODS_DIR%"
    exit /b 1
)

robocopy "%SOURCE%" "%DEST_DIR%" /E /R:2 /W:1
if errorlevel 8 (
    echo Copy failed. Check the source and deployment destination.
    exit /b 1
)

copy /Y "%~dp0LICENSE" "%DEST_DIR%\LICENSE" >nul
if errorlevel 1 (
    echo Could not copy the license file.
    exit /b 1
)

echo Deployed VCMProfessions to: "%DEST_DIR%"
exit /b 0
