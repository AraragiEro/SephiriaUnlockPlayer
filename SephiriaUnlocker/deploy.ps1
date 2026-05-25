param(
    [string]$GamePath = $null
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
Set-Location $ScriptDir

Write-Host '=== SephiriaUnlocker 一键编译部署 ===' -ForegroundColor Cyan

# ── 1. 确定游戏路径 ──────────────────────────
if (-not $GamePath) {
    # 1a. GamePath.props（手动配置优先）
    $propsFile = Join-Path $ScriptDir 'GamePath.props'
    if (Test-Path $propsFile) {
        [xml]$props = Get-Content $propsFile
        $candidate = $props.Project.PropertyGroup.SephiriaGamePath
        if ($candidate -and (Test-Path (Join-Path $candidate 'Sephiria.exe'))) {
            $GamePath = $candidate
        }
    }
}

if (-not $GamePath) {
    # 1b. Steam 注册表 + libraryfolders.vdf（覆盖所有自定义库文件夹）
    $steamPath = $null
    try { $steamPath = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name 'SteamPath' -EA Stop).SteamPath } catch {}
    if (-not $steamPath) {
        try { $steamPath = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -Name 'InstallPath' -EA Stop).InstallPath } catch {}
    }

    if ($steamPath) {
        $vdfPath = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdfPath) {
            $vdfContent = Get-Content $vdfPath -Raw
            $libMatches = [regex]::Matches($vdfContent, '"path"\s+"([^"]+)"')
            foreach ($m in $libMatches) {
                $libPath = $m.Groups[1].Value -replace '\\\\', '\'
                $tryPath = Join-Path $libPath 'steamapps\common\Sephiria'
                if (Test-Path (Join-Path $tryPath 'Sephiria.exe')) { $GamePath = $tryPath; break }
            }
        }
        if (-not $GamePath) {
            $tryPath = Join-Path $steamPath 'steamapps\common\Sephiria'
            if (Test-Path (Join-Path $tryPath 'Sephiria.exe')) { $GamePath = $tryPath }
        }
    }
}

if (-not $GamePath) {
    # 1c. 兜底：扫描所有盘符的常见路径
    $patterns = @(
        '{0}:\SteamLibrary\steamapps\common\Sephiria',
        '{0}:\Program Files (x86)\Steam\steamapps\common\Sephiria',
        '{0}:\Program Files\Steam\steamapps\common\Sephiria',
        '{0}:\Steam\steamapps\common\Sephiria'
    )
    $drives = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used }).Name
    :driveLoop foreach ($drive in $drives) {
        foreach ($pattern in $patterns) {
            $tryPath = $pattern -f $drive
            if (Test-Path (Join-Path $tryPath 'Sephiria.exe')) { $GamePath = $tryPath; break driveLoop }
        }
    }
}

if (-not $GamePath) { Write-Host '[ERROR] 找不到游戏目录，请用 -GamePath 参数指定' -ForegroundColor Red; exit 1 }
Write-Host "[OK] 游戏目录: $GamePath"

$AddOnDir = "$GamePath\AddOns\SephiriaUnlocker"

# ── 2. 编译 ──────────────────────────────────
Write-Host "`n[*] 编译中..." -ForegroundColor Cyan
Set-Location "$ScriptDir\SephiriaUnlocker"
dotnet build -c Release
if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] 编译失败" -ForegroundColor Red; exit 1 }
Write-Host "[OK] 编译成功"

# ── 3. 获取 0Harmony.dll（动态获取） ──────────
Write-Host "`n[*] 获取 HarmonyX..." -ForegroundColor Cyan
$harmonySrc = $null

# 3a. 尝试从已安装的 SephiriaReconnect 获取
$reconnectDirs = Get-ChildItem "$GamePath\AddOns" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*Reconnect*" }
if ($reconnectDirs) {
    $reconnectHarmony = Join-Path $reconnectDirs[0].FullName '0Harmony.dll'
    if (Test-Path $reconnectHarmony) {
        $harmonySrc = $reconnectHarmony
        Write-Host "[OK] 从 SephiriaReconnect 获取 0Harmony.dll"
    }
}

# 3b. 从 NuGet 下载 HarmonyX 2.16.1（独立 ILMerge 版）
if (-not $harmonySrc) {
    $nugetUrl = 'https://www.nuget.org/api/v2/package/HarmonyX/2.16.1'
    $tempZip = "$env:TEMP\HarmonyX.nupkg"
    $tempDir = "$env:TEMP\HarmonyX-extract"
    Write-Host "[*] 下载 HarmonyX 2.16.1..."
    Invoke-WebRequest -Uri $nugetUrl -OutFile $tempZip -ErrorAction Stop
    Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
    $harmonyDll = Get-ChildItem "$tempDir\lib\netstandard2.0\0Harmony.dll" -ErrorAction SilentlyContinue
    if (-not $harmonyDll) { $harmonyDll = Get-ChildItem "$tempDir\lib\net35\0Harmony.dll" -ErrorAction SilentlyContinue }
    if ($harmonyDll) {
        $harmonySrc = $harmonyDll.FullName
        Write-Host "[OK] 从 NuGet 获取 HarmonyX 2.16.1"
    } else {
        Write-Host "[FAIL] 无法获取 0Harmony.dll" -ForegroundColor Red; exit 1
    }
}

# ── 4. 部署到 AddOns ──────────────────────────
Write-Host "`n[*] 部署到 AddOns..." -ForegroundColor Cyan
New-Item -Path $AddOnDir -ItemType Directory -Force | Out-Null

# 4a. 复制 Mod DLL
Copy-Item (Join-Path $ScriptDir 'bin\Release\netstandard2.1\SephiriaUnlocker.dll') $AddOnDir -Force
Write-Host "[OK] SephiriaUnlocker.dll"

# 4b. 复制 HarmonyX
Copy-Item $harmonySrc $AddOnDir -Force
Write-Host "[OK] 0Harmony.dll"

# 4c. 同步到 libs\（编译时需要）
$libsDir = Join-Path (Split-Path $ScriptDir -Parent) 'libs'
New-Item $libsDir -ItemType Directory -Force | Out-Null
Copy-Item $harmonySrc (Join-Path $libsDir '0Harmony.dll') -Force
Write-Host "[OK] libs\0Harmony.dll"

# 4c. metadata.json
$meta = '{"modName":"SephiriaUnlocker","modVersion":"0.12.0","modAuthor":"SephiriaUnlocker Team","dllFile":"SephiriaUnlocker.dll","entryClass":"SephiriaUnlocker.SephiriaUnlockerMod"}'
Set-Content -Path "$AddOnDir\metadata.json" -Value $meta -Encoding UTF8
Write-Host "[OK] metadata.json"

# ── 5. 完成 ──────────────────────────────────
Write-Host "`n=== 部署完成 ===" -ForegroundColor Green
Get-ChildItem $AddOnDir | Select-Object Name, Length | Format-Table -AutoSize
Write-Host "`n启动游戏即可生效。"
