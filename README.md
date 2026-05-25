# SephiriaUnlocker 16人联机解锁

将 Sephiria（赛菲莉亚）联机人数上限从 4 人提升到 16 人。游戏内可自由选择 2-16 人，无需配置文件，无需 BepInEx。

## 快速开始

```powershell
cd SephiriaUnlocker
.\deploy.ps1
```

脚本自动完成：检测游戏路径 → 获取 HarmonyX → 编译 → 部署。

**无需手动下载依赖 DLL。** 脚本会自动从以下来源获取 `0Harmony.dll`：
1. 优先从已安装的 SephiriaReconnect 获取（同版本，避免冲突）
2. 否则从 NuGet 下载 HarmonyX v2.16.1（独立版，无需其他依赖）

如果自动检测游戏路径失败，编辑 `GamePath.props` 或使用 `-GamePath` 参数指定。

## 安装（手动）

将以下 **3 个文件**放入 `<游戏目录>\AddOns\SephiriaUnlocker\`：

| 文件 | 说明 |
|------|------|
| `metadata.json` | AddOn 元数据（自动生成） |
| `SephiriaUnlocker.dll` | 主 Mod（编译产出） |
| `0Harmony.dll` | HarmonyX 运行时（脚本自动获取） |

> 如果你也安装了 SephiriaReconnect，仅需 `SephiriaUnlocker.dll` + `metadata.json` 即可——两个 Mod 共用同一个 `0Harmony.dll`。

## 配置

**不需要配置文件。** 进入游戏 → 多人模式 → 创建大厅 → 成员选项即可选择 2-16 人。

## 编译（开发者）

### 前置要求
- [.NET SDK 8.0+](https://dotnet.microsoft.com/download)
- Sephiria 游戏已安装

### 一键脚本
```powershell
cd SephiriaUnlocker
.\deploy.ps1
```
自动：检测路径 → 获取 HarmonyX → 编译 → 部署。

### 手动步骤
1. 编辑 `GamePath.props`，设置 `<SephiriaGamePath>`
2. 编译：
   ```powershell
   cd SephiriaUnlocker
   dotnet build -c Release
   ```
3. 复制到 AddOns：
   ```powershell
   Copy-Item bin\Release\netstandard2.1\SephiriaUnlocker.dll <游戏>\AddOns\SephiriaUnlocker\ -Force
   ```
4. 获取 `0Harmony.dll`（从已安装的 SephiriaReconnect 复制，或从 NuGet 下载 HarmonyX v2.16.1）

### 依赖说明
本项目唯一的外部依赖是 **HarmonyX**（`0Harmony.dll`），源码中**不包含**此文件。部署时由 `deploy.ps1` 自动获取。编译时从 `libs\0Harmony.dll` 引用——你可从任一来源复制一份到此目录。

## 卸载

删除 `<游戏目录>\AddOns\SephiriaUnlocker\` 文件夹即可恢复 4 人上限。

## 故障排除

1. **成员选项还是只有 2-4**：确认 `Player.log` 中有 `All patches applied successfully`
2. **日志位置**：`%USERPROFILE%\AppData\LocalLow\TEAMHORAY\Sephiria\Player.log`
3. **游戏更新后失效**：重新运行 `build.bat`
4. **大厅 UI 显示限制**：UI 显示 4 个槽位是正常的，实际 16 人都能连接

## 技术架构

| 组件 | 文件 | 作用 |
|------|------|------|
| AddOn 入口 | `SephiriaUnlockerMod.cs` | 继承 `HorayModBase`，游戏自动加载 |
| 最大连接数 | `Patches/MirrorPatches.cs` | 传输层监控 + `maxConnections=16` |
| 选择器 | `SephiriaUnlockerMod.cs` | 修改 `Options.AllowedMultiplayerMember = 16` |
