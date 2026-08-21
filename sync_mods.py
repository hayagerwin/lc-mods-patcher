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
from pathlib import Path
import urllib.request
import urllib.error

# ==============================================================================
# REPOSITORY CONFIGURATION
# Configure your GitHub username, repository name, and branch below.
# ==============================================================================
REPO_USER = "YourGitHubUsername"
REPO_NAME = "YourModRepository"
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
def verify_environment(game_dir: Path) -> bool:
    """Verifies that the script is located in the Lethal Company root directory."""
    exe_path = game_dir / "Lethal Company.exe"
    if not exe_path.is_file():
        log_error('"Lethal Company.exe" was not found in this folder!')
        print(f"\nPlease place and run this script directly inside your Lethal Company root folder:")
        print(f"  Current directory: {game_dir}")
        print(f"  Expected location: steamapps/common/Lethal Company/\n")
        return False
    return True


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
    game_dir = Path(__file__).resolve().parent

    log_header("Lethal Company Mod Synchronizer")

    if not verify_environment(game_dir):
        input("\nPress Enter to exit...")
        sys.exit(1)

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
    input("Press Enter to close...")


if __name__ == "__main__":
    main()
