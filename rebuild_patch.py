import os
import zipfile
import shutil

game_root = r"c:\Games\Lethal Company"
patcher_dir = r"C:\Reedsoft\LCModsPatcher"
zip_path = os.path.join(patcher_dir, "patch.zip")

# 1. Update LandingVoiceGuard DLL if compiled
lvg_src = os.path.join(game_root, r"LandingVoiceGuard\bin\Release\netstandard2.1\LandingVoiceGuard.dll")
lvg_dst = os.path.join(game_root, r"BepInEx\plugins\REED-LandingVoiceGuard\LandingVoiceGuard.dll")
if os.path.isfile(lvg_src):
    os.makedirs(os.path.dirname(lvg_dst), exist_ok=True)
    shutil.copy2(lvg_src, lvg_dst)
    print(f"[+] Synced {lvg_dst}")

# 2. Update MoonRouteBuffer DLL if compiled
mrb_src = os.path.join(game_root, r"MoonRouteBuffer\bin\Release\netstandard2.1\MoonRouteBuffer.dll")
mrb_dst = os.path.join(game_root, r"BepInEx\plugins\REED-MoonRouteBuffer\MoonRouteBuffer.dll")
if os.path.isfile(mrb_src):
    os.makedirs(os.path.dirname(mrb_dst), exist_ok=True)
    shutil.copy2(mrb_src, mrb_dst)
    print(f"[+] Synced {mrb_dst}")

# 3. Read existing entries from current patch.zip to preserve base mods
entries_to_pack = []
if os.path.isfile(zip_path):
    with zipfile.ZipFile(zip_path, "r") as z:
        for name in z.namelist():
            entries_to_pack.append(name)

# Ensure all REED custom mods are included
for mod_entry in [
    "BepInEx/plugins/REED-LandingVoiceGuard/LandingVoiceGuard.dll",
    "BepInEx/plugins/REED-LandingVoiceGuard/README.md",
    "BepInEx/plugins/REED-MoonRouteBuffer/MoonRouteBuffer.dll",
    "BepInEx/plugins/REED-MoonRouteBuffer/README.md",
    "BepInEx/plugins/REED-TerminalWASDNavigation/TerminalWASDNavigation.dll",
    "BepInEx/plugins/REED-FriendsBrowser/FriendsBrowser.dll"
]:
    if mod_entry not in entries_to_pack:
        entries_to_pack.append(mod_entry)

backup_zip = zip_path + ".bak"
if os.path.isfile(zip_path):
    shutil.copy2(zip_path, backup_zip)

with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for entry in entries_to_pack:
        disk_path = os.path.join(game_root, entry.replace("/", os.sep))
        if os.path.isfile(disk_path):
            z.write(disk_path, arcname=entry)
            print(f"Packed from game disk: {entry}")
        elif os.path.isfile(backup_zip):
            with zipfile.ZipFile(backup_zip, "r") as zb:
                if entry in zb.namelist():
                    z.writestr(entry, zb.read(entry))
                    print(f"Preserved from backup: {entry}")

if os.path.isfile(backup_zip):
    os.remove(backup_zip)

print("[+] patch.zip rebuilt successfully!")
