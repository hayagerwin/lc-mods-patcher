#!/usr/bin/env python3
"""
Lethal Company Mod Patcher - Migration Script
Automatically upgrades legacy sync_mods.py to lethal_company_patcher.py.
"""

import os
import sys
import subprocess
import urllib.request
import urllib.error
from pathlib import Path

REPO_USER = "hayagerwin"
REPO_NAME = "lc-mods-patcher"
BRANCH = "main"

def migrate():
    print("\n" + "=" * 75)
    print("       Lethal Company Mod Patcher - Automatic Migration Helper".center(75))
    print("=" * 75 + "\n")
    print('[*] "sync_mods.py" has been upgraded to "lethal_company_patcher.py".')
    print('[*] Downloading the latest patcher and migrating your installation...\n')

    script_dir = Path(__file__).resolve().parent
    new_script = script_dir / "lethal_company_patcher.py"
    current_script = Path(__file__).resolve()

    url = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/lethal_company_patcher.py"

    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "LethalCompanyModPatcher/1.0"}
        )
        with urllib.request.urlopen(req, timeout=15) as response:
            content = response.read()

        if content:
            new_script.write_bytes(content)
            print("[+] Successfully installed lethal_company_patcher.py!")

            # Remove legacy sync_mods.py if it's different from the target file
            if current_script != new_script and current_script.is_file():
                try:
                    current_script.unlink()
                except Exception:
                    pass

            print("[+] Launching lethal_company_patcher.py...\n")
            exit_code = subprocess.call([sys.executable, str(new_script)] + sys.argv[1:])
            sys.exit(exit_code)
        else:
            print("[ERROR] Downloaded file was empty.")
            input("\nPress Enter to exit...")
            sys.exit(1)

    except Exception as e:
        print(f"[ERROR] Migration failed: {e}")
        print(f"Please download lethal_company_patcher.py manually from GitHub.")
        input("\nPress Enter to exit...")
        sys.exit(1)

if __name__ == "__main__":
    migrate()
