# MacSteamTools

[🇮🇩 Bahasa Indonesia](README.md) | [🇬🇧 English](README_en.md)

> ⚠️ **Disclaimer**: MacSteamTools is a **manager for OpenSteamTools** on macOS. This app is **not** Steam itself — Steam for Windows must already be installed inside [CrossOver](https://www.codeweavers.com/crossover). This application is not affiliated with Valve, Steam, or CodeWeavers.

---

MacSteamTools is a native macOS launcher & manager that simplifies the installation of **[BetterSteamTools](https://github.com/madoiscool/BetterSteamTools)** and the management of Lua files from **[ManifestHub](https://github.com/steamtools-games/ManifestHub3)** in CrossOver.

## ✅ Requirements

- macOS 13 (Ventura) or later
- [CrossOver](https://www.codeweavers.com/crossover) installed
- **Steam Windows** installed inside a CrossOver bottle

## 🚀 How to Use

### 1. Initial Setup
1. Open `MacSteamTools.app`
2. In the **Settings** page, select the CrossOver **bottle** where Steam is installed
3. The app will automatically detect the Steam folder — if not, click **Change…** to select it manually
4. Make sure Steam is **closed** before proceeding

### 2. Install BetterSteamTools Modules
1. In **Settings → Steam Modules**, click **Install modules**
2. The app will automatically:
   - Download the latest release from GitHub
   - Set 3 Library DLLs in winecfg (`native,builtin`)
   - Install the DLL files into the Steam folder
3. Restart Steam in CrossOver

### 3. Install Lua for Games
1. Open the **Games** page
2. Search for a game name or Steam App ID
3. Click **Download Lua** on the desired game
4. The Lua file will automatically be saved to `Steam/config/stplug-in/`
5. Restart Steam to apply changes

### 4. Manage Installed Games
- Open the **Dashboard** page to see all installed Luas 
- Click the red "trash" icon on a game card to remove its Lua
- To uninstall everything at once, use **Settings → Danger Zone → Uninstall**

---

## 📦 Dependency Used

| Component | Source |
|-----------|--------|
| DLL Modules (BetterSteamTools) | [madoiscool/BetterSteamTools](https://github.com/madoiscool/BetterSteamTools) via GitHub Releases API |
| Game catalog & search | [ManifestHub3](https://github.com/steamtools-games/ManifestHub3) via `steamtools.games/api/search` |
| Lua file per game | `raw.githubusercontent.com/steamtools-games/ManifestHub3/<AppID>/<AppID>.lua` |
| Game cover art | Steam CDN (`cdn.cloudflare.steamstatic.com`) |

---

## 🔧 winecfg Libraries

Before DLLs are installed, the app automatically configures the Wine registry:

| Library | Value |
|---------|-------|
| `dwmapi` | `native,builtin` |
| `xinput1_4` | `native,builtin` |
| `OpenSteamTool` | `native,builtin` |

These settings can be viewed in **winecfg → Libraries**. The **Check status** button in Settings reads the actual registry status.

---

## 💾 Backup & Security

- Every DLL or Lua installation creates an automatic backup in `Steam/MacSteamTools Backups/<ID>/`
- `files.json` maps destination files to their old copies for manual recovery
- DLLs are validated for MZ headers before installation
- Lua installations are validated for App ID before being saved


---

## 🏗️ Build

```sh
bash scripts/build.sh   # Build & package .app to dist/
bash scripts/test.sh    # Run test suite
```

Built using native macOS SwiftUI, AppKit, Foundation, and CryptoKit. Requires no Node.js, Python, or any external dependencies.

---

## 🌐 Multi-Language

UI text is stored in the `Language/` folder:
- `Language/id/index.json` — Indonesian (default)
- `Language/en/index.json` — English

To add a new language: create a new folder (e.g., `Language/ja/index.json`), add a case to the `AppLanguage` enum in `Localization.swift`, and rebuild.

---

## ⚠️ Important Notes

- This app only works with **CrossOver** — it does not support standard Wine or Whisky (for now)
- Steam **must** be installed inside a CrossOver bottle, not native macOS
- Always close Steam before installing modules or Lua
- Game compatibility depends on the availability of Lua files in ManifestHub — not all games are available
- This app is open-source and is not officially associated with the BetterSteamTools or ManifestHub projects
