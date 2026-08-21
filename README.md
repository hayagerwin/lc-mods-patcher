# Lethal Company Mod Synchronizer

A standalone, lightweight synchronization toolchain for updating custom **Lethal Company** mod files (`BepInEx/plugins`, `BepInEx/config`, `BepInEx/patchers`, etc.) directly from a remote GitHub repository.

---

## Features

- **Zero-Dependency Native Batch Script (`sync_mods.bat`)**:
  - Uses Windows 10/11 built-in `curl.exe` and `tar.exe`.
  - No PowerShell execution policy issues, no 7-Zip, and no Python installation required for players.
- **Python Alternative (`sync_mods.py`)**:
  - Written entirely with Python standard library (`urllib`, `zipfile`, `pathlib`, `shutil`).
  - Cross-platform support and real-time chunked download progress bar.
- **Robust 3-Stage Pipeline**:
  - **Environment Check**: Confirms execution inside the game's root directory (`Lethal Company.exe`).
  - **[1/3] Deletion Stage**: Removes outdated/conflicting mods and folders defined in `delete_list.txt`.
  - **[2/3] Download Stage**: Fetches the latest `patch.zip` from GitHub with HTTP error detection (catches 404s cleanly).
  - **[3/3] Extraction Stage**: Extracts and silently overwrites updated mod files, cleaning up temp archives upon completion.

---

## Quick Start for Players

1. Download [`sync_mods.bat`](file:///c:/Reedsoft/LCModsPatcher/sync_mods.bat) (or [`sync_mods.py`](file:///c:/Reedsoft/LCModsPatcher/sync_mods.py)).
2. Place the script into your **Lethal Company root directory**:
   - *Typical Steam path*: `C:\Program Files (x86)\Steam\steamapps\common\Lethal Company\`
3. Double-click `sync_mods.bat` to update your mods.

---

## Configuration for Repository Maintainers

### 1. Configure the Scripts
Open `sync_mods.bat` or `sync_mods.py` in a text editor and set your GitHub repository details at the top:

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

- **Wrong Directory**: If executed outside of the Lethal Company folder, the script halts immediately with an informative message.
- **Spaces in Paths**: Paths with spaces (e.g. `BepInEx/plugins/Custom Mod Pack/`) are properly handled.
- **Directory vs File Detection**: Accurately differentiates folders (`rmdir /s /q`) from files (`del /f /q /a`).
- **Network Failures**: `curl -f` ensures that 404 responses or connection drops fail cleanly without writing corrupt files.
