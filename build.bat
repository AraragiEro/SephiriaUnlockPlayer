@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title SephiriaUnlocker - 一键编译+部署

echo ============================================
echo   SephiriaUnlocker 16人联机解锁 Mod
echo   一键编译 ^& 部署
echo ============================================
echo.

:: ── 1. 自动检测游戏路径 ──────────────────────────
set GAME_PATH=
set STEAM_PATH=

:: 1a. Steam 注册表
for /f "skip=2 tokens=2,*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul') do set "STEAM_PATH=%%B"
if not defined STEAM_PATH (
    for /f "skip=2 tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Valve\Steam" /v InstallPath 2^>nul') do set "STEAM_PATH=%%B"
)

:: 1b. libraryfolders.vdf（通过 PowerShell 解析所有库文件夹）
if defined STEAM_PATH (
    if exist "!STEAM_PATH!\steamapps\libraryfolders.vdf" (
        (
            echo $steam = $env:STEAM_PATH
            echo $vdf = "$steam\steamapps\libraryfolders.vdf"
            echo $v = Get-Content $vdf -Raw -EA 0
            echo if ($v^) {
            echo   foreach ($m in [regex]::Matches($v,'\x22path\x22\s+\x22([^\x22]+)\x22')^) {
            echo     $l = $m.Groups[1].Value -replace '\\\\','\'
            echo     $t = "$l\steamapps\common\Sephiria\Sephiria.exe"
            echo     if (Test-Path $t^) { Write-Output $l; exit 0 }
            echo   }
            echo }
            echo exit 1
        ) > "%TEMP%\find_sephiria.ps1"

        for /f "usebackq delims=" %%P in (`powershell -NoProfile -File "%TEMP%\find_sephiria.ps1"`) do (
            set "GAME_PATH=%%P\steamapps\common\Sephiria"
            del "%TEMP%\find_sephiria.ps1" 2>nul
            goto :found
        )
        del "%TEMP%\find_sephiria.ps1" 2>nul
    )
    :: 也检查 Steam 自身安装目录
    if not defined GAME_PATH (
        if exist "!STEAM_PATH!\steamapps\common\Sephiria\Sephiria.exe" (
            set "GAME_PATH=!STEAM_PATH!\steamapps\common\Sephiria"
            goto :found
        )
    )
)

:: 1c. 兜底：全盘扫描
for %%D in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    for %%P in ("%%D:\SteamLibrary\steamapps\common\Sephiria" "%%D:\Program Files (x86)\Steam\steamapps\common\Sephiria" "%%D:\Program Files\Steam\steamapps\common\Sephiria" "%%D:\Steam\steamapps\common\Sephiria") do (
        if exist "%%~P\Sephiria.exe" (
            set "GAME_PATH=%%~P"
            goto :found
        )
    )
)

echo [错误] 未找到 Sephiria 游戏安装目录
echo 请手动编辑 SephiriaUnlocker\GamePath.props 设置路径
pause
exit /b 1

:found
echo [√] 找到游戏: !GAME_PATH!

:: ── 2. 写入 GamePath.props ────────────────────
echo ^<?xml version="1.0" encoding="utf-8"?^> > "%~dp0GamePath.props"
echo ^<!-- 自动检测的游戏路径 --^> >> "%~dp0GamePath.props"
echo ^<Project^> >> "%~dp0GamePath.props"
echo   ^<PropertyGroup^> >> "%~dp0GamePath.props"
echo     ^<SephiriaGamePath^>!GAME_PATH!^</SephiriaGamePath^> >> "%~dp0GamePath.props"
echo   ^</PropertyGroup^> >> "%~dp0GamePath.props"
echo ^</Project^> >> "%~dp0GamePath.props"

:: ── 3. 编译 ──────────────────────────────────
echo.
echo [*] 正在编译...
cd /d "%~dp0"
dotnet build -c Release

if %ERRORLEVEL% neq 0 (
    echo [失败] 编译出错，请检查上方错误信息
    pause
    exit /b 1
)
echo [√] 编译成功

:: ── 4. 部署到 AddOns 文件夹 ──────────────────
set ADDONS=!GAME_PATH!\AddOns\SephiriaUnlocker
if not exist "!ADDONS!" mkdir "!ADDONS!"

:: 复制 Mod DLL
copy /Y "%~dp0bin\Release\netstandard2.1\SephiriaUnlocker.dll" "!ADDONS!\" >nul
echo [√] SephiriaUnlocker.dll

:: 复制 HarmonyX + MonoMod DLL（如果 libs 目录存在）
if exist "%~dp0..\libs\0Harmony.dll" (
    copy /Y "%~dp0..\libs\0Harmony.dll" "!ADDONS!\" >nul 2>nul
)
:: 复制 BepInEx core DLLs（如果存在）
if exist "%~dp0..\bepinex-core\" (
    for %%F in ("%~dp0..\bepinex-core\*.dll") do (
        copy /Y "%%F" "!ADDONS!\" >nul 2>nul
    )
)

:: 复制/创建 metadata.json
if not exist "!ADDONS!\metadata.json" (
    echo {"modName":"SephiriaUnlocker","modVersion":"1.0.0","modAuthor":"SephiriaUnlocker Team","dllFile":"SephiriaUnlocker.dll","entryClass":"SephiriaUnlocker.SephiriaUnlockerMod"} > "!ADDONS!\metadata.json"
    echo [√] metadata.json
)

echo.
echo ============================================
echo   [完成] 编译并部署成功！
echo   目标: !ADDONS!
echo ============================================
echo.
echo 启动游戏即可生效。大厅成员选项将显示 2-16 人。
pause
