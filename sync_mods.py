#!/usr/bin/env python3
"""
Lethal Company Mod Synchronizer (Python Alternative)
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
    """Checks if a newer version of sync_mods.py exists on GitHub and self-updates."""
    if os.environ.get("_SYNC_MODS_SELF_UPDATED") == "1":
        return

    current_script = Path(__file__).resolve()
    try:
        req = urllib.request.Request(
            script_url,
            headers={"User-Agent": "LethalCompanyModPatcher/1.0"}
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            remote_bytes = response.read()

        if not remote_bytes:
            return

        remote_text = remote_bytes.decode("utf-8", errors="ignore").replace("\r\n", "\n").strip()
        local_text = current_script.read_text(encoding="utf-8", errors="ignore").replace("\r\n", "\n").strip()

        if remote_text != local_text:
            print(f"{Style.BOLD}{Style.CYAN}[UPDATE]{Style.RESET} A newer version of sync_mods.py was detected.")
            log_info("Updating script to the latest version...")

            current_script.write_bytes(remote_bytes)
            log_info("Restarting synchronizer...\n")

            env = os.environ.copy()
            env["_SYNC_MODS_SELF_UPDATED"] = "1"
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


def find_game_directory() -> Path | None:
    """Detects Lethal Company root directory from script folder, configs, or common locations."""
    script_dir = Path(__file__).resolve().parent

    # 1. Check current script directory
    if (script_dir / "Lethal Company.exe").is_file():
        return script_dir

    # 2. Check local config in script directory
    local_cfg = script_dir / "lc_game_path.txt"
    if local_cfg.is_file():
        try:
            saved = Path(local_cfg.read_text(encoding="utf-8").strip())
            if (saved / "Lethal Company.exe").is_file():
                return saved
        except Exception:
            pass

    # 3. Check global config in AppData / ~/.config
    global_cfg = get_config_path()
    if global_cfg.is_file():
        try:
            saved = Path(global_cfg.read_text(encoding="utf-8").strip())
            if (saved / "Lethal Company.exe").is_file():
                return saved
        except Exception:
            pass

    # 4. Check common non-Steam (Online-Fix, Repacks) and Steam paths
    candidates = [
        Path("C:/Games/Lethal Company"),
        Path("D:/Games/Lethal Company"),
        Path("E:/Games/Lethal Company"),
        Path("F:/Games/Lethal Company"),
        Path.home() / "Downloads" / "Lethal Company",
        Path.home() / "Desktop" / "Lethal Company",
        Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / "Steam/steamapps/common/Lethal Company",
        Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Steam/steamapps/common/Lethal Company",
        Path("D:/SteamLibrary/steamapps/common/Lethal Company"),
        Path("E:/SteamLibrary/steamapps/common/Lethal Company"),
        Path("F:/SteamLibrary/steamapps/common/Lethal Company"),
    ]

    for candidate in candidates:
        if (candidate / "Lethal Company.exe").is_file():
            return candidate

    # 5. Wildcard search in Downloads and Desktop
    for base_dir in [Path.home() / "Downloads", Path.home() / "Desktop"]:
        if base_dir.is_dir():
            try:
                for folder in base_dir.glob("Lethal*"):
                    if folder.is_dir() and (folder / "Lethal Company.exe").is_file():
                        return folder
            except Exception:
                pass

    return None


def prompt_game_directory() -> Path | None:
    """Interactively prompts the user to input or drag-and-drop their game folder."""
    print(f"{Style.BOLD}{Style.YELLOW}[!] Lethal Company folder was not automatically detected.{Style.RESET}")
    print("\nPlease enter or drag-and-drop your Lethal Company game folder")
    print('(where "Lethal Company.exe" is located, e.g. C:\\Games\\Lethal Company):')

    while True:
        try:
            user_input = input("\n> ").strip().strip('"').strip("'")
        except (KeyboardInterrupt, EOFError):
            return None

        if not user_input:
            return None

        p = Path(user_input).resolve()
        # If user dragged the executable directly
        if p.name.lower() == "lethal company.exe" and p.is_file():
            p = p.parent

        if (p / "Lethal Company.exe").is_file():
            return p
        else:
            log_error(f'"Lethal Company.exe" was not found in: "{p}"')
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
    log_header("Lethal Company Mod Synchronizer")

    script_url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/sync_mods.py"
    check_self_update(script_url)

    game_dir = find_game_directory()
    if not game_dir:
        game_dir = prompt_game_directory()

    if not game_dir or not (game_dir / "Lethal Company.exe").is_file():
        log_error('Could not locate "Lethal Company.exe"!')
        print("\nPlease make sure you have Lethal Company installed (Steam, Online-Fix, or standalone),")
        print("and run this script from inside the game folder or provide the correct path when prompted.\n")
        input("Press Enter to exit...")
        sys.exit(1)

    save_cached_game_dir(game_dir)
    print(f"{Style.BOLD}{Style.GREEN}[+] Target Game Directory:{Style.RESET} {game_dir}\n")

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
