#!/usr/bin/env python3
"""
Lethal Company Mod Patcher (Python Alternative)
Synchronizes custom mods, configs, and patchers from a remote GitHub repository.
"""

import os
import sys
import shutil
import zipfile
import tempfile
import subprocess
from pathlib import Path
import urllib.request
import urllib.error

# ==============================================================================
# REPOSITORY CONFIGURATION
# Configure your GitHub username, repository name, and branch below.
# ==============================================================================
REPO_USER = "hayagerwin"
REPO_NAME = "lc-mods-patcher"
BRANCH = "main"

# ==============================================================================
# TERMINAL FORMATTING HELPERS
# ==============================================================================
class Style:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    BOLD = "\033[1m"
    RESET = "\033[0m"

# Enable ANSI colors on Windows if possible
if sys.platform == "win32":
    os.system("")

def log_header(title: str):
    print(f"\n{Style.BOLD}{Style.CYAN}{'=' * 75}{Style.RESET}")
    print(f"{Style.BOLD}{Style.CYAN}{title.center(75)}{Style.RESET}")
    print(f"{Style.BOLD}{Style.CYAN}{'=' * 75}{Style.RESET}\n")

def log_step(step: str, message: str):
    print(f"{Style.BOLD}{Style.BLUE}[{step}]{Style.RESET} {message}")

def log_success(message: str):
    print(f"\n{Style.BOLD}{Style.GREEN}[SUCCESS]{Style.RESET} {message}")

def log_error(message: str):
    print(f"\n{Style.BOLD}{Style.RED}[ERROR]{Style.RESET} {message}")

def log_info(message: str):
    print(f"  {Style.YELLOW}->{Style.RESET} {message}")

def clear_screen():
    """Clears the terminal screen for a clean interface."""
    os.system("cls" if sys.platform == "win32" else "clear")


# ==============================================================================
# CORE OPERATIONS
# ==============================================================================
def check_self_update(script_url: str):
    """Checks if a newer version of lethal_company_patcher.py exists on GitHub and self-updates."""
    if os.environ.get("_LC_PATCHER_SELF_UPDATED") == "1":
        return

    current_script = Path(__file__).resolve()
    # Cleanup legacy migration script if present (for players outside git repo)
    if not (current_script.parent / ".git").is_dir():
        legacy_bat = current_script.parent / "sync_mods.bat"
        legacy_py = current_script.parent / "sync_mods.py"
        for legacy in [legacy_bat, legacy_py]:
            if legacy.is_file() and legacy != current_script:
                try:
                    legacy.unlink()
                except Exception:
                    pass

    try:
        req = urllib.request.Request(
            script_url,
            headers={
                "User-Agent": "LethalCompanyModPatcher/1.0",
                "Cache-Control": "no-cache",
                "Pragma": "no-cache"
            }
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            remote_bytes = response.read()

        if not remote_bytes:
            return

        remote_text = remote_bytes.decode("utf-8", errors="ignore").replace("\r\n", "\n").strip()
        local_text = current_script.read_text(encoding="utf-8", errors="ignore").replace("\r\n", "\n").strip()

        if remote_text != local_text:
            print(f"{Style.BOLD}{Style.CYAN}[UPDATE]{Style.RESET} A newer version of lethal_company_patcher.py was detected.")
            log_info("Updating script to the latest version...")

            current_script.write_bytes(remote_bytes)
            log_info("Restarting patcher...\n")

            env = os.environ.copy()
            env["_LC_PATCHER_SELF_UPDATED"] = "1"
            exit_code = subprocess.call([sys.executable, str(current_script)] + sys.argv[1:], env=env)
            sys.exit(exit_code)

    except urllib.error.HTTPError:
        pass
    except urllib.error.URLError:
        pass
    except Exception:
        pass


def get_config_path() -> Path:
    """Returns the persistent config path for storing the game location."""
    if sys.platform == "win32":
        appdata = os.environ.get("LOCALAPPDATA")
        if appdata:
            return Path(appdata) / "LCModsPatcher" / "lc_game_path.txt"
    return Path.home() / ".config" / "lc-mods-patcher" / "lc_game_path.txt"


def save_cached_game_dir(game_dir: Path):
    """Saves the verified game directory to the config file."""
    try:
        cfg = get_config_path()
        cfg.parent.mkdir(parents=True, exist_ok=True)
        cfg.write_text(str(game_dir.resolve()), encoding="utf-8")
    except Exception:
        pass


def find_lethal_company_root(target: Path | str | None, max_sub_depth: int = 3) -> Path | None:
    """
    Given a target path (file or directory), attempts to locate the directory containing 'Lethal Company.exe'.
    Checks:
    1. If target is 'Lethal Company.exe' directly or another file in the game root.
    2. If target directory directly contains 'Lethal Company.exe'.
    3. If target's parent or grandparent contains 'Lethal Company.exe' (e.g. user selected BepInEx).
    4. If any subfolder within target (up to max_sub_depth) contains 'Lethal Company.exe' (e.g. nested unzipped archive).
    """
    if not target:
        return None

    try:
        p = Path(target).resolve()
    except Exception:
        return None

    if not p.exists():
        return None

    # Case A: target is a file
    if p.is_file():
        if p.name.lower() == "lethal company.exe":
            return p.parent
        if (p.parent / "Lethal Company.exe").is_file():
            return p.parent
        p = p.parent

    # Case B: target directly contains Lethal Company.exe
    if (p / "Lethal Company.exe").is_file():
        return p

    # Case C: check parent directories (up to 2 levels up, in case user passed BepInEx / Lethal Company_Data)
    curr = p.parent
    for _ in range(2):
        if (curr / "Lethal Company.exe").is_file():
            return curr
        if curr == curr.parent:
            break
        curr = curr.parent

    # Case D: check subdirectories (breadth-first scan up to max_sub_depth)
    if max_sub_depth > 0:
        try:
            # Check immediate children first (depth 1)
            subdirs = [d for d in p.iterdir() if d.is_dir()]
            for sub in subdirs:
                if (sub / "Lethal Company.exe").is_file():
                    return sub

            # Check deeper children (depth 2..max_sub_depth)
            if max_sub_depth >= 2:
                for root, dirs, _ in os.walk(p, followlinks=False):
                    try:
                        rel_parts = Path(root).relative_to(p).parts
                    except ValueError:
                        break
                    depth = len(rel_parts)
                    if depth >= max_sub_depth:
                        dirs.clear()
                        continue
                    for d in dirs:
                        cand = Path(root) / d
                        if (cand / "Lethal Company.exe").is_file():
                            return cand
        except (PermissionError, OSError):
            pass

    return None


def resolve_game_directory() -> Path | None:
    """Resolves Lethal Company root directory with flexible subfolder scanning and selection."""
    script_dir = Path(__file__).resolve().parent

    # Case 1: In-Place Execution (Script is placed directly inside game directory)
    if (script_dir / "Lethal Company.exe").is_file():
        return script_dir

    # Case 2: External Execution - Scan for available installations
    candidates: list[tuple[Path, str]] = []
    seen: set[str] = set()

    def add_candidate(path: Path | str | None, label: str):
        if not path:
            return
        found = find_lethal_company_root(path, max_sub_depth=2)
        if found:
            resolved_key = str(found.resolve()).lower()
            if resolved_key not in seen and (found / "Lethal Company.exe").is_file():
                seen.add(resolved_key)
                candidates.append((found.resolve(), label))

    # Check if script_dir contains game in a nested folder (e.g. extracted patcher + game archive)
    sub_game = find_lethal_company_root(script_dir, max_sub_depth=2)
    if sub_game and sub_game != script_dir:
        add_candidate(sub_game, "Inside Current Directory")

    # Check saved configs (local and global)
    local_cfg = script_dir / "lc_game_path.txt"
    if local_cfg.is_file():
        try:
            saved = local_cfg.read_text(encoding="utf-8").strip()
            add_candidate(saved, "Previously Used")
        except Exception:
            pass

    global_cfg = get_config_path()
    if global_cfg.is_file():
        try:
            saved = global_cfg.read_text(encoding="utf-8").strip()
            add_candidate(saved, "Previously Used")
        except Exception:
            pass

    # Check common paths & Steam across available drives
    drive_letters = ["C", "D", "E", "F", "G", "H"]
    for drive in drive_letters:
        drive_path = Path(f"{drive}:/")
        if not drive_path.exists():
            continue

        common_paths = [
            drive_path / "Games/Lethal Company",
            drive_path / "SteamLibrary/steamapps/common/Lethal Company",
            drive_path / "Steam/steamapps/common/Lethal Company",
            drive_path / "Program Files (x86)/Steam/steamapps/common/Lethal Company",
            drive_path / "Program Files/Steam/steamapps/common/Lethal Company",
        ]
        for cp in common_paths:
            add_candidate(cp, "Installed Path")

        # Scan drive Games directory for custom *lethal* folders
        games_folder = drive_path / "Games"
        if games_folder.is_dir():
            try:
                for item in games_folder.iterdir():
                    if item.is_dir() and "lethal" in item.name.lower():
                        add_candidate(item, f"Found on {drive}:/Games")
            except Exception:
                pass

    # Check user directories (Downloads, Desktop, Documents)
    for base_dir in [Path.home() / "Downloads", Path.home() / "Desktop", Path.home() / "Documents"]:
        if base_dir.is_dir():
            try:
                for item in base_dir.iterdir():
                    if item.is_dir() and "lethal" in item.name.lower():
                        add_candidate(item, f"Found in {base_dir.name}")
            except Exception:
                pass

    # If multiple candidates found, let the user choose
    if len(candidates) > 1:
        print(f"{Style.BOLD}{Style.CYAN}Multiple Lethal Company folders were detected on your PC:{Style.RESET}\n")
        for i, (path, label) in enumerate(candidates, 1):
            print(f"  {Style.GREEN}[{i}]{Style.RESET} {path}  {Style.YELLOW}({label}){Style.RESET}")
        custom_idx = len(candidates) + 1
        print(f"  {Style.GREEN}[{custom_idx}]{Style.RESET} Enter / Drag-and-drop / Browse for a different folder...\n")

        while True:
            try:
                choice = input(f"Select which folder to patch [1-{custom_idx}] (Default: 1): ").strip()
            except (KeyboardInterrupt, EOFError):
                return None

            if not choice or choice == "1":
                return candidates[0][0]

            if choice == str(custom_idx):
                return prompt_custom_directory()

            try:
                idx = int(choice)
                if 1 <= idx <= len(candidates):
                    return candidates[idx - 1][0]
            except ValueError:
                pass
            print(f"{Style.RED}Invalid option. Please enter a number between 1 and {custom_idx}.{Style.RESET}")

    # If single candidate found
    if len(candidates) == 1:
        single_path, single_label = candidates[0]
        return prompt_single_candidate(single_path, single_label)

    return prompt_custom_directory()


def prompt_single_candidate(candidate_path: Path, label: str) -> Path | None:
    """Displays auto-detected installation with clear Enter/Change choices."""
    print(f"{Style.BOLD}{Style.CYAN}Found Lethal Company installation:{Style.RESET}")
    print(f"  {Style.BOLD}{Style.GREEN}[+] {candidate_path}{Style.RESET} {Style.YELLOW}({label}){Style.RESET}\n")
    print(f"{Style.BOLD}{Style.CYAN}{'-' * 75}{Style.RESET}")
    print(f"  * Press {Style.BOLD}{Style.GREEN}[ENTER]{Style.RESET} to continue with this folder (Recommended)")
    print(f"  * Or type {Style.BOLD}[C]{Style.RESET} to change, browse, or drag-and-drop a different folder")
    print(f"{Style.BOLD}{Style.CYAN}{'-' * 75}{Style.RESET}\n")

    try:
        user_input = input("Press [ENTER] to continue, or type 'C' to change: ").strip().strip('"').strip("'")
    except (KeyboardInterrupt, EOFError):
        return None

    if not user_input or user_input.lower() in ("y", "yes"):
        return candidate_path

    if user_input.lower() in ("c", "change", "n", "no"):
        return prompt_custom_directory()

    if user_input.lower() in ("b", "browse"):
        print(f"  {Style.CYAN}-> Opening Windows folder browser...{Style.RESET}")
        picked = pick_folder_dialog()
        if picked:
            resolved = find_lethal_company_root(picked, max_sub_depth=3)
            if resolved:
                return resolved
        return prompt_custom_directory()

    # In case the user dragged and dropped a folder path directly into this prompt
    resolved = find_lethal_company_root(user_input, max_sub_depth=3)
    if resolved:
        return resolved

    print(f"{Style.RED}[ERROR] \"Lethal Company.exe\" was not found in: \"{user_input}\" or its subfolders.{Style.RESET}\n")
    return prompt_custom_directory()


def pick_folder_dialog() -> Path | None:
    """Opens a native Windows FolderBrowserDialog to pick a folder."""
    try:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        selected = filedialog.askdirectory(title="Select your Lethal Company game folder")
        root.destroy()
        if selected:
            return Path(selected)
    except Exception:
        pass
    return None


def prompt_custom_directory() -> Path | None:
    """Interactively prompts the user to input, drag-and-drop, or browse for their game folder."""
    print(f"\n{Style.BOLD}{Style.YELLOW}[!] Please specify your Lethal Company game folder.{Style.RESET}")
    print('  Option 1: Drag-and-drop your game folder or "Lethal Company.exe" here.')
    print("  Option 2: Type 'B' and press Enter to browse with Windows folder picker.")
    print("  Option 3: Type the full folder path and press Enter.")

    while True:
        try:
            user_input = input(f"\n{Style.BOLD}> {Style.RESET}").strip().strip('"').strip("'")
        except (KeyboardInterrupt, EOFError):
            return None

        if not user_input:
            return None

        if user_input.lower() in ("b", "browse"):
            print(f"  {Style.CYAN}-> Opening Windows folder browser...{Style.RESET}")
            picked = pick_folder_dialog()
            if picked:
                resolved = find_lethal_company_root(picked, max_sub_depth=3)
                if resolved:
                    return resolved
                else:
                    log_error(f'"Lethal Company.exe" was not found in: "{picked}" or its subfolders.')
            else:
                log_info("Folder selection cancelled.")
            print("Please try again, drag-and-drop a folder, or press Ctrl+C to cancel.")
            continue

        resolved = find_lethal_company_root(user_input, max_sub_depth=3)
        if resolved:
            return resolved
        else:
            log_error(f'"Lethal Company.exe" was not found in: "{user_input}" or its subfolders.')
            print("Please verify the folder and try again (or press Ctrl+C to cancel).")


def download_file_with_progress(url: str, destination: Path, show_progress: bool = True) -> bool:
    """Downloads a file from a URL to a local destination with optional progress feedback."""
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "LethalCompanyModPatcher/1.0"}
        )
        with urllib.request.urlopen(req) as response:
            total_size = response.headers.get("content-length")
            total_size = int(total_size) if total_size else None
            downloaded = 0
            block_size = 1024 * 64  # 64 KB chunks

            with open(destination, "wb") as out_file:
                while True:
                    buffer = response.read(block_size)
                    if not buffer:
                        break
                    downloaded += len(buffer)
                    out_file.write(buffer)

                    if show_progress:
                        if total_size:
                            percent = (downloaded / total_size) * 100
                            bar_length = 35
                            filled_length = int(bar_length * downloaded // total_size)
                            bar = "=" * filled_length + "-" * (bar_length - filled_length)
                            downloaded_mb = downloaded / (1024 * 1024)
                            total_mb = total_size / (1024 * 1024)
                            print(
                                f"\r      [{bar}] {percent:5.1f}% ({downloaded_mb:.2f}/{total_mb:.2f} MB)",
                                end="",
                                flush=True,
                            )
                        else:
                            downloaded_mb = downloaded / (1024 * 1024)
                            print(f"\r      Downloaded {downloaded_mb:.2f} MB...", end="", flush=True)

            if show_progress:
                print()  # Newline after progress bar
            return True

    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        log_error(f"HTTP Error {e.code}: {e.reason}")
        return False
    except urllib.error.URLError as e:
        log_error(f"Network error while reaching GitHub: {e.reason}")
        return False
    except Exception as e:
        log_error(f"Unexpected download failure: {e}")
        return False


def stage_display_patch_info(patch_info_url: str, game_dir: Path):
    """Fetches and displays the latest patch version, release date, and changelog diff."""
    # Read local installed version if available
    local_ver = "none"
    installed_file = game_dir / "BepInEx" / "patch_installed.txt"
    if installed_file.is_file():
        try:
            txt = installed_file.read_text(encoding="utf-8", errors="ignore").strip()
            if txt:
                local_ver = txt.splitlines()[0].strip()
        except Exception:
            pass

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_info = Path(temp_dir) / "patch_info.txt"
        success = download_file_with_progress(f"{patch_info_url}?t={os.urandom(4).hex()}", temp_info, show_progress=False)
        if success and temp_info.is_file():
            content = temp_info.read_text(encoding="utf-8", errors="ignore").strip()
            if not content:
                return

            sections = []
            cur_ver = None
            cur_head = None
            cur_lines = []

            for line in content.splitlines():
                trimmed = line.strip()
                if trimmed.startswith("=== [") and "]" in trimmed:
                    if cur_ver:
                        sections.append((cur_ver, cur_head, cur_lines))
                    cur_ver = trimmed.split("[")[1].split("]")[0].strip()
                    cur_head = trimmed
                    cur_lines = []
                elif cur_ver:
                    cur_lines.append(line)

            if cur_ver:
                sections.append((cur_ver, cur_head, cur_lines))

            if not sections:
                return

            latest_ver = sections[0][0]

            print(f"{Style.BOLD}{Style.CYAN}{'=' * 75}{Style.RESET}")
            print(f"{Style.BOLD}{Style.CYAN}{'LATEST PATCH DETAILS & CHANGELOG'.center(75)}{Style.RESET}")
            print(f"{Style.BOLD}{Style.CYAN}{'=' * 75}{Style.RESET}")

            if local_ver.lower() == latest_ver.lower():
                print(f"{Style.BOLD}{Style.GREEN}[STATUS]{Style.RESET} You are currently UP TO DATE on {latest_ver}.")
                print("Showing latest release notes:")
                print(f"{Style.BOLD}{Style.YELLOW}{sections[0][1]}{Style.RESET}")
                for l in sections[0][2]:
                    if l.strip().startswith("*"):
                        print(f"   {Style.GREEN}*{Style.RESET}{l.strip()[1:]}")
                    elif l.strip():
                        print(f"  {l.strip()}")
            else:
                if local_ver and local_ver != "none":
                    print(f"{Style.BOLD}{Style.YELLOW}[STATUS]{Style.RESET} Updating from {local_ver} -> {latest_ver}")
                    print(f"{Style.BOLD}{Style.GREEN}New changes since your installed version ({local_ver}):{Style.RESET}\n")
                else:
                    print(f"{Style.BOLD}{Style.GREEN}[STATUS]{Style.RESET} Installing latest patch: {latest_ver}\n")

                for ver, head, lines in sections:
                    if local_ver and ver.lower() == local_ver.lower():
                        break
                    print(f"{Style.BOLD}{Style.YELLOW}{head}{Style.RESET}")
                    for l in lines:
                        if l.strip().startswith("*"):
                            print(f"   {Style.GREEN}*{Style.RESET}{l.strip()[1:]}")
                        elif l.strip():
                            print(f"  {l.strip()}")
                    print()

            print(f"{Style.BOLD}{Style.CYAN}{'=' * 75}{Style.RESET}\n")

            try:
                bepinex_dir = game_dir / "BepInEx"
                if bepinex_dir.is_dir():
                    installed_file.write_text(latest_ver, encoding="utf-8")
            except Exception:
                pass


def stage_cleanup_obsolete(game_dir: Path, delete_list_url: str):
    """Stage 1: Downloads delete_list.txt and removes specified obsolete files and folders."""
    log_step("1/3", "Checking for obsolete files and folders to remove...")
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_delete_list = Path(temp_dir) / "delete_list.txt"
        success = download_file_with_progress(delete_list_url, temp_delete_list, show_progress=False)

        if not success or not temp_delete_list.is_file():
            log_info("No deletion manifest found on remote or nothing to remove. Proceeding.")
            return

        deleted_count = 0
        with open(temp_delete_list, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                item = line.strip()
                # Skip comments and empty lines
                if not item or item.startswith("#"):
                    continue

                target_path = game_dir / Path(item)

                if target_path.is_dir():
                    try:
                        shutil.rmtree(target_path)
                        log_info(f"Removed obsolete directory: {item}")
                        deleted_count += 1
                    except Exception as e:
                        print(f"      [!] Warning: Failed to remove directory '{item}': {e}")
                elif target_path.is_file():
                    try:
                        target_path.unlink()
                        log_info(f"Removed obsolete file: {item}")
                        deleted_count += 1
                    except Exception as e:
                        print(f"      [!] Warning: Failed to remove file '{item}': {e}")

        if deleted_count == 0:
            log_info("No obsolete items matched local files. Clean state verified.")
        else:
            log_info(f"Cleaned up {deleted_count} obsolete item(s).")


def stage_download_patch(patch_url: str, output_path: Path) -> bool:
    """Stage 2: Downloads patch.zip with progress."""
    log_step("2/3", f"Downloading latest mod patch (patch.zip)...")
    print(f"      Repository: {REPO_USER}/{REPO_NAME} ({BRANCH})")
    
    success = download_file_with_progress(patch_url, output_path)
    if not success or not output_path.is_file() or output_path.stat().st_size == 0:
        log_error("Failed to download mod archive from GitHub.")
        print(f"\n  Please verify:\n    1. Username: {REPO_USER}\n    2. Repository: {REPO_NAME}\n    3. Branch: {BRANCH}")
        print("    4. Ensure 'patch.zip' exists in the target branch.")
        return False
    return True


def stage_extract_patch(game_dir: Path, zip_path: Path) -> bool:
    """Stage 3: Extracts patch.zip directly into the game root, overwriting files."""
    log_step("3/3", "Extracting mod files and updating game directory...")
    try:
        with zipfile.ZipFile(zip_path, "r") as archive:
            # Extract all files and directories, overwriting existing
            archive.extractall(path=game_dir)
        log_info("Archive extracted and files updated successfully.")
        return True
    except Exception as e:
        log_error(f"Extraction failed: {e}")
        print("  Make sure Lethal Company is closed and files are not locked.")
        return False


def run_optimizer_flow(game_dir: Path):
    """Executes the low-spec performance optimizer."""
    log_header("Running Low-Spec Performance Optimizer")
    
    script_dir = Path(__file__).resolve().parent
    local_ps = script_dir / "optimizer" / "optimize.ps1"
    ps_url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/optimizer/optimize.ps1"
    opt_zip_url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/optimizer/optimizer_plugins.zip"

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_ps = Path(temp_dir) / "optimize.ps1"
        target_ps = local_ps if local_ps.is_file() else temp_ps

        if not target_ps.is_file():
            log_step("1/2", "Downloading latest optimization definitions...")
            download_file_with_progress(ps_url, temp_ps, show_progress=False)
            target_ps = temp_ps

        if not target_ps.is_file():
            log_error("Failed to load optimize.ps1. Please check your network connection.")
            input("\nPress Enter to return...")
            return

        try:
            subprocess.run([
                "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", str(target_ps), "-Mode", "Optimize", "-GameDir", str(game_dir)
            ], check=True)
        except Exception as e:
            log_error(f"Failed to execute optimize.ps1: {e}")

        # Download & install FPS Counter overlay plugin if available
        print()
        log_step("2/2", "Checking FPS Counter overlay plugin...")
        temp_opt_zip = Path(temp_dir) / "optimizer_plugins.zip"
        if download_file_with_progress(opt_zip_url, temp_opt_zip, show_progress=False):
            try:
                with zipfile.ZipFile(temp_opt_zip, "r") as archive:
                    archive.extractall(path=game_dir)
                log_info("FPS Counter plugin synchronized.")
            except Exception:
                pass

    log_success("Performance optimizations have been applied successfully!\n")
    print("  * Gameplay camera scale set to 0.7x (16:9 aspect lock)")
    print("  * Heavy 3D OpenBodyCam rendering disabled")
    print("  * Ship cameras capped to 5 FPS")
    print("  * Low-spec shadow maps and fog budget applied")
    print("  * FPS Counter overlay active (Toggle in-game with [F8])\n")
    input("Press Enter to continue...")


def run_revert_optimizer_flow(game_dir: Path):
    """Reverts graphics and camera performance optimizations back to standard defaults."""
    log_header("Reverting Performance Optimizations")
    
    script_dir = Path(__file__).resolve().parent
    local_ps = script_dir / "optimizer" / "optimize.ps1"
    ps_url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/optimizer/optimize.ps1"

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_ps = Path(temp_dir) / "optimize.ps1"
        target_ps = local_ps if local_ps.is_file() else temp_ps

        if not target_ps.is_file():
            download_file_with_progress(ps_url, temp_ps, show_progress=False)
            target_ps = temp_ps

        if target_ps.is_file():
            try:
                subprocess.run([
                    "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                    "-File", str(target_ps), "-Mode", "Revert", "-GameDir", str(game_dir)
                ], check=True)
                log_success("Graphics and camera settings restored to defaults.\n")
            except Exception as e:
                log_error(f"Failed to revert settings: {e}")
        else:
            log_error("Could not load optimize.ps1 to revert.")

    input("Press Enter to continue...")


def run_patcher_flow(game_dir: Path):
    """Executes the standard 3-stage mod patching & updating flow."""
    clear_screen()
    log_header("Lethal Company Mod Patcher")
    print(f"{Style.BOLD}{Style.GREEN}[+] Target Game Directory:{Style.RESET} {game_dir}\n")

    delete_list_url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/delete_list.txt"
    patch_zip_url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/patch.zip"
    patch_info_url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/patch_info.txt"

    # Display Latest Patch Details & Changelog
    stage_display_patch_info(patch_info_url, game_dir)

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_patch_zip = Path(temp_dir) / "patch.zip"

        # Stage 1: Clean up obsolete files
        stage_cleanup_obsolete(game_dir, delete_list_url)
        print()

        # Stage 2: Download patch archive
        if not stage_download_patch(patch_zip_url, temp_patch_zip):
            input("\nPress Enter to exit...")
            sys.exit(1)
        print()

        # Stage 3: Extract and overwrite
        if not stage_extract_patch(game_dir, temp_patch_zip):
            input("\nPress Enter to exit...")
            sys.exit(1)

    log_success("Lethal Company mods have been successfully synchronized!\n")
    try:
        user_choice = input("Press [ENTER] to launch Lethal Company, or close this window to exit: ").strip()
    except (KeyboardInterrupt, EOFError):
        print()
        sys.exit(0)

    if user_choice.lower() in ("q", "quit", "exit", "n", "no"):
        sys.exit(0)

    print()
    log_info("Launching Lethal Company...")
    try:
        exe_path = game_dir / "Lethal Company.exe"
        if sys.platform == "win32":
            os.chdir(str(game_dir))
            os.startfile(str(exe_path))
        else:
            subprocess.Popen([str(exe_path)], cwd=str(game_dir))
    except Exception as e:
        log_error(f"Failed to launch Lethal Company: {e}")
        input("\nPress Enter to exit...")
        sys.exit(1)

    sys.exit(0)


def main():
    log_header("Lethal Company Mod Patcher")

    # Step 0: Self-update check (always runs FIRST before anything else)
    script_url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/lethal_company_patcher.py"
    check_self_update(script_url)

    # Step 1: Game Directory Detection
    game_dir = resolve_game_directory()

    if not game_dir or not (game_dir / "Lethal Company.exe").is_file():
        log_error('Could not locate "Lethal Company.exe"!')
        print("\nPlease make sure you have Lethal Company installed (Steam, Online-Fix, or standalone),")
        print("and run this script from inside the game folder or provide the correct path when prompted.\n")
        input("Press Enter to exit...")
        sys.exit(1)

    save_cached_game_dir(game_dir)

    # Main Action Menu Loop
    while True:
        clear_screen()
        log_header("Lethal Company Mod Patcher & Toolset")
        print(f"{Style.BOLD}{Style.GREEN}[+] Target Game Directory:{Style.RESET} {game_dir}\n")

        print(f"{Style.CYAN}{'-' * 75}{Style.RESET}")
        print("  Select an action:")
        print(f"    {Style.BOLD}{Style.GREEN}[ENTER]{Style.RESET} -> {Style.GREEN}Update & Apply Latest Mods{Style.RESET} (Default / Recommended)")
        print(f"    {Style.BOLD}{Style.YELLOW}[1]{Style.RESET}     -> {Style.YELLOW}Run Performance Optimizer{Style.RESET} (Low-Spec PC / HDD FPS Boost)")
        print(f"    {Style.BOLD}{Style.YELLOW}[2]{Style.RESET}     -> {Style.YELLOW}Revert Optimizer Settings{Style.RESET} (Restore Default Graphics)")
        print(f"    {Style.BOLD}{Style.CYAN}[C]{Style.RESET}     -> {Style.CYAN}Change / Browse Game Directory{Style.RESET}")
        print(f"    {Style.BOLD}{Style.RED}[Q]{Style.RESET}     -> {Style.RED}Exit{Style.RESET}")
        print(f"{Style.CYAN}{'-' * 75}{Style.RESET}\n")

        try:
            choice = input("Enter choice (Default: [ENTER] to Update): ").strip()
        except (KeyboardInterrupt, EOFError):
            print()
            sys.exit(0)

        if not choice or choice.lower() in ("u", "update", "p", "patch", "y", "yes"):
            run_patcher_flow(game_dir)
            break
        elif choice == "1" or choice.lower() in ("opt", "optimize"):
            run_optimizer_flow(game_dir)
        elif choice == "2" or choice.lower() in ("revert", "restore"):
            run_revert_optimizer_flow(game_dir)
        elif choice.lower() in ("c", "change"):
            new_dir = prompt_manual_directory_picker()
            if new_dir and (new_dir / "Lethal Company.exe").is_file():
                game_dir = new_dir
                save_cached_game_dir(game_dir)
        elif choice == "0" or choice.lower() in ("q", "quit", "exit"):
            sys.exit(0)


if __name__ == "__main__":
    main()

