@echo off
setlocal

set "SOURCE=%~dp0Contents\mods\VCMProfessions"
set "DEST=%USERPROFILE%\Zomboid\Workshop\VCMProfessions"

if not exist "%SOURCE%\mod.info" (
    echo Source mod folder not found: "%SOURCE%"
    exit /b 1
)

if not exist "%~dp0preview.png" (
    echo Workshop preview image not found: "%~dp0preview.png"
    exit /b 1
)

if not exist "%~dp0LICENSE" (
    echo License file not found: "%~dp0LICENSE"
    exit /b 1
)

robocopy "%SOURCE%" "%DEST%\Contents\mods\VCMProfessions" mod.info registries.lua VCMProfessions*.lua Sandbox.json UI.json sandbox-options.txt VCMProfessions*.txt *.png /S /R:2 /W:1 /XD ".git" ".github" "tests" /XF "preview.png"
set "ROBOCOPY_EXIT=%ERRORLEVEL%"
if %ROBOCOPY_EXIT% GEQ 8 (
    echo Copy failed with robocopy exit code %ROBOCOPY_EXIT%.
    exit /b %ROBOCOPY_EXIT%
)

if exist "%DEST%\Contents\mods\VCMProfessions\42.22\media\scripts\VCMProfessionsBase.txt" (
    del "%DEST%\Contents\mods\VCMProfessions\42.22\media\scripts\VCMProfessionsBase.txt"
    if exist "%DEST%\Contents\mods\VCMProfessions\42.22\media\scripts\VCMProfessionsBase.txt" (
        echo Could not remove the obsolete Unemployed override.
        exit /b 1
    )
)

copy /Y "%~dp0LICENSE" "%DEST%\Contents\mods\VCMProfessions\LICENSE" >nul
if errorlevel 1 (
    echo Could not copy the license file.
    exit /b 1
)

copy /Y "%~dp0preview.png" "%DEST%\preview.png" >nul
if errorlevel 1 (
    echo Could not copy the Workshop preview image.
    exit /b 1
)

echo Workshop files deployed to: "%DEST%"
exit /b 0
