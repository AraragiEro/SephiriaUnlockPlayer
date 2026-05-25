# SephiriaUnlocker 16人联机解锁

将 Sephiria（赛菲莉亚）联机人数上限从 4 人提升到 16 人。游戏内可自由选择 2-16 人，无需配置文件，无需 BepInEx。

## 快速开始

**双击 `build.bat`**，自动完成：检测游戏路径 → 编译 → 部署。

首次运行会自动扫描所有盘符寻找游戏目录。如果找不到，编辑 `SephiriaUnlocker\GamePath.props` 填入你的游戏路径即可。

## 安装（手动）

将以下文件放入 `<游戏目录>\AddOns\SephiriaUnlocker\`：

| 文件 | 说明 |
|------|------|
| `metadata.json` | AddOn 元数据 |
| `SephiriaUnlocker.dll` | 主 Mod（编译产出） |
| `0Harmony.dll` | HarmonyX 运行时 |
| `MonoMod.*.dll` | MonoMod 依赖（约6个文件） |
| `Mono.Cecil.dll` | IL 操作库 |

**Mod 文件夹**中已包含所有依赖 DLL。如果从 GitHub 下载，直接复制 `SephiriaUnlocker/` 到 `AddOns/` 即可。

## 配置

**不需要配置文件。** 进入游戏 → 多人模式 → 创建大厅 → 成员选项即可选择 2-16 人。

## 编译（开发者）

### 前置要求
- [.NET SDK 8.0+](https://dotnet.microsoft.com/download)
- Sephiria 游戏已安装

### 步骤

**方式一：一键脚本**
```bat
build.bat
```

**方式二：手动**
1. 编辑 `SephiriaUnlocker\GamePath.props`，设置 `<SephiriaGamePath>` 为你的游戏目录
2. 放入依赖 DLL 到 `libs\`（从下方来源获取）
3. 编译：
   ```bat
   cd SephiriaUnlocker
   dotnet build -c Release
   ```
4. 将 `bin\Release\netstandard2.1\SephiriaUnlocker.dll` 复制到 `AddOns\SephiriaUnlocker\`

### 依赖 DLL 来源
从 [BepInEx 5.4.23 发行包](https://github.com/BepInEx/BepInEx/releases/download/v5.4.23.5/BepInEx_win_x64_5.4.23.5.zip) 的 `BepInEx/core/` 目录提取以下文件到 `libs/`：
- `0Harmony.dll`
- `MonoMod.RuntimeDetour.dll`
- `MonoMod.Utils.dll`
- `Mono.Cecil.dll`
- `Mono.Cecil.Mdb.dll`
- `Mono.Cecil.Pdb.dll`

> 注意：无需安装 BepInEx，只需提取这些 DLL。

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
| UI 扩展 | `Patches/UIPatches.cs` | 扩展成员选择器 2-4 → 2-16 |
| 网络层 | `Patches/MirrorPatches.cs` | 设置 `maxConnections=16` |
