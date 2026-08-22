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
        print(f"  {Style.GREEN}[{custom_idx}]{Style.RESET} Enter / Drag-and-drop a different folder...\n")

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
        print(f"{Style.BOLD}{Style.CYAN}Found Lethal Company installation:{Style.RESET}")
        print(f"  {Style.GREEN}->{Style.RESET} {single_path} {Style.YELLOW}({single_label}){Style.RESET}\n")
        try:
            user_input = input(f"Press [Enter] to use this folder, or enter/drag-and-drop a different folder: ").strip().strip('"').strip("'")
        except (KeyboardInterrupt, EOFError):
            return None

        if not user_input:
            return single_path

        resolved = find_lethal_company_root(user_input, max_sub_depth=3)
        if resolved:
            return resolved
        print(f"{Style.RED}[ERROR] \"Lethal Company.exe\" was not found in: \"{user_input}\" or its subfolders.{Style.RESET}\n")

    return prompt_custom_directory()


def prompt_custom_directory() -> Path | None:
    """Interactively prompts the user to input or drag-and-drop their game folder."""
    print(f"\n{Style.BOLD}{Style.YELLOW}[!] Please specify your Lethal Company game folder.{Style.RESET}")
    print('Enter or drag-and-drop your game folder (where "Lethal Company.exe" is located):')

    while True:
        try:
            user_input = input("\n> ").strip().strip('"').strip("'")
        except (KeyboardInterrupt, EOFError):
            return None

        if not user_input:
            return None

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
    print(f"{Style.BOLD}{Style.GREEN}[+] Selected Game Directory:{Style.RESET} {game_dir}\n")

    delete_list_url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/delete_list.txt"
    patch_zip_url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/patch.zip"

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


if __name__ == "__main__":
    main()
