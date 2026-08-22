# Lethal Company Mod Patcher

A standalone, lightweight synchronization toolchain for updating custom **Lethal Company** mod files (`BepInEx/plugins`, `BepInEx/config`, `BepInEx/patchers`, etc.) directly from a remote GitHub repository.

---

## Features

- **Automatic Self-Update (Always Runs First)**:
  - Automatically checks for newer versions of `lethal_company_patcher.bat` or `lethal_company_patcher.py` on GitHub before checking directory or synchronizing mods.
  - Seamlessly updates itself and restarts if updates or bug fixes are detected on the remote repository.
- **Zero-Dependency Native Batch Script (`lethal_company_patcher.bat`)**:
  - Uses Windows 10/11 built-in `curl.exe` and `tar.exe`.
  - No PowerShell execution policy issues, no 7-Zip, and no Python installation required for players.
- **Python Alternative (`lethal_company_patcher.py`)**:
  - Written entirely with Python standard library (`urllib`, `zipfile`, `pathlib`, `shutil`, `subprocess`).
  - Cross-platform support and real-time chunked download progress bar.
- **Smart Game Directory Auto-Detection & Subfolder Flexibility**:
  - Automatically discovers your game directory across **Steam**, **Online-Fix**, and custom repack locations (`C:\Games\Lethal Company`, `Downloads\Lethal Company`, Desktop, Documents, etc.).
  - Deep nested subfolder resolution: seamlessly detects installations even when extracted inside extra folder layers (e.g. `Downloads/Lethal Company/Lethal Company/Lethal Company.exe` or `Downloads/Lethal.Company.v69/Lethal Company/`).
  - Forgiving drag-and-drop / manual inputs: whether you drag the `.exe`, the root folder, the outer extracted folder, or a subfolder like `BepInEx`, the patcher automatically locates the actual game directory.
  - If executed outside the game folder, it prompts you once and saves the verified location to `%LOCALAPPDATA%\LCModsPatcher` so future syncs are 1-click.
- **Robust Pipeline**:
  - **[0] Self-Update Check**: Checks for and applies script updates from the repository.
  - **[1] Game Directory Detection**: Resolves and verifies the Lethal Company root directory (`Lethal Company.exe`).
  - **[2] System Utilities Check**: Verifies `curl.exe` and `tar.exe`.
  - **[1/3] Deletion Stage**: Removes outdated/conflicting mods and folders defined in `delete_list.txt`.
  - **[2/3] Download Stage**: Fetches the latest `patch.zip` from GitHub with HTTP error detection (catches 404s cleanly).
  - **[3/3] Extraction Stage**: Extracts and silently overwrites updated mod files, cleaning up temp archives upon completion.
  - **[Launch]**: Prompts to launch `Lethal Company.exe` with the proper working directory or exit.

---

## Quick Start for Players

1. Download [`lethal_company_patcher.bat`](file:///c:/Reedsoft/lc-mods-patcher/lethal_company_patcher.bat) (or [`lethal_company_patcher.py`](file:///c:/Reedsoft/lc-mods-patcher/lethal_company_patcher.py)).
2. Run the script:
   - **Option A (Recommended)**: Place the script inside your Lethal Company game folder (Steam, Online-Fix, or standalone) and double-click `lethal_company_patcher.bat`.
   - **Option B (Run from anywhere)**: Run `lethal_company_patcher.bat` from your `Downloads` or Desktop folder. The script will automatically locate your game, or ask you to drag-and-drop your game folder once.
3. Once synchronization succeeds, press `Enter` to launch Lethal Company, or close the window to exit.

---

## Supported Editions & Paths

The synchronizer automatically supports both legitimate and standalone/Online-Fix copies:
- **Steam**: `C:\Program Files (x86)\Steam\steamapps\common\Lethal Company\`, library drives (`D:\SteamLibrary`, etc.)
- **Online-Fix / Repacks**: `C:\Games\Lethal Company\`, `D:\Games\Lethal Company\`, nested unzipped folders in `Downloads\`, `Desktop\`, or `Documents\` (e.g. `Downloads\Lethal Company\Lethal Company\`)
- **Custom / External**: Any folder or nested directory containing `Lethal Company.exe`

---

## Configuration for Repository Maintainers

### 1. Configure the Scripts
Open `lethal_company_patcher.bat` or `lethal_company_patcher.py` in a text editor and set your GitHub repository details at the top:

```bat
set "REPO_USER=YourGitHubUsername"
set "REPO_NAME=YourModRepository"
set "BRANCH=main"
```

```python
REPO_USER = "YourGitHubUsername"
REPO_NAME = "YourModRepository"
BRANCH = "main"
```

### 2. GitHub Repository Structure
Organize your GitHub repository as follows:

```
YourModRepository/
├── patch.zip             <-- Archive containing updated BepInEx files
├── delete_list.txt       <-- List of obsolete files/folders to delete (optional)
└── README.md
```

#### Creating `patch.zip`
Inside `patch.zip`, maintain relative paths matching the game root:
```
patch.zip
└── BepInEx/
    ├── plugins/
    │   ├── MoreCompany.dll
    │   └── ...
    ├── config/
    │   └── ...
    └── patchers/
        └── ...
```

#### Formatting `delete_list.txt`
Specify relative paths to remove before extracting the new patch:
```text
# Comments start with #
BepInEx/plugins/OldDeprecatedMod.dll
BepInEx/plugins/OutdatedFolder
BepInEx/config/removed_mod.cfg
```

---

## Error Handling & Safety

- **Smart Path Resolution**: If executed outside of the Lethal Company folder, the script automatically searches standard game locations or lets you drag-and-drop your game folder.
- **Working Directory Integrity**: Ensures game executable and Online-Fix / BepInEx libraries are loaded with the proper root working directory.
- **Spaces in Paths**: Paths with spaces (e.g. `BepInEx/plugins/Custom Mod Pack/`) are properly handled.
- **Directory vs File Detection**: Accurately differentiates folders (`rmdir /s /q`) from files (`del /f /q /a`).
- **Network Failures**: `curl -f` ensures that 404 responses or connection drops fail cleanly without writing corrupt files.
