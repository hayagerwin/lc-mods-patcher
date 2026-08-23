import os
import glob
import zipfile
import shutil

game_root = r"c:\Games\Lethal Company"
patcher_dir = r"C:\Reedsoft\LCModsPatcher"
zip_path = os.path.join(patcher_dir, "patch.zip")
bepinex_dir = os.path.join(game_root, "BepInEx")

print("=== [LCModsPatcher] Dynamic Modular Mod Sync & Packager ===")

# 1. Dynamically discover and sync all custom C# project builds
for item in os.listdir(game_root):
    proj_dir = os.path.join(game_root, item)
    if os.path.isdir(proj_dir) and not item.startswith(".") and item not in ["BepInEx", "Lethal Company_Data", "MonoBleedingEdge"]:
        csproj_files = glob.glob(os.path.join(proj_dir, "*.csproj"))
        if csproj_files:
            mod_name = os.path.splitext(os.path.basename(csproj_files[0]))[0]
            built_dll = os.path.join(proj_dir, "bin", "Release", "netstandard2.1", f"{mod_name}.dll")
            if os.path.isfile(built_dll):
                target_plugin_dir = os.path.join(bepinex_dir, "plugins", f"REED-{mod_name}")
                os.makedirs(target_plugin_dir, exist_ok=True)
                target_dll = os.path.join(target_plugin_dir, f"{mod_name}.dll")
                shutil.copy2(built_dll, target_dll)
                print(f"[+] Auto-synced build: {built_dll} -> {target_dll}")

# 2. Read existing entries from current patch.zip to preserve third-party mods
entries_to_pack = set()
backup_zip = zip_path + ".bak"
if os.path.isfile(zip_path):
    shutil.copy2(zip_path, backup_zip)
    with zipfile.ZipFile(zip_path, "r") as z:
        for name in z.namelist():
            entries_to_pack.add(name)

# 3. Dynamically discover all REED custom plugins and patchers from disk
for root, dirs, files in os.walk(os.path.join(bepinex_dir, "plugins")):
    for dir_name in dirs:
        if dir_name.startswith("REED-"):
            plugin_folder = os.path.join(root, dir_name)
            for froot, _, ffiles in os.walk(plugin_folder):
                for file_name in ffiles:
                    full_path = os.path.join(froot, file_name)
                    rel_path = os.path.relpath(full_path, game_root).replace(os.sep, "/")
                    entries_to_pack.add(rel_path)

# Add patchers
patchers_dir = os.path.join(bepinex_dir, "patchers")
if os.path.isdir(patchers_dir):
    for froot, _, ffiles in os.walk(patchers_dir):
        for file_name in ffiles:
            full_path = os.path.join(froot, file_name)
            rel_path = os.path.relpath(full_path, game_root).replace(os.sep, "/")
            entries_to_pack.add(rel_path)

# 4. Rebuild patch.zip
sorted_entries = sorted(list(entries_to_pack))
with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for entry in sorted_entries:
        disk_path = os.path.join(game_root, entry.replace("/", os.sep))
        if os.path.isfile(disk_path):
            z.write(disk_path, arcname=entry)
            print(f"Packed from disk: {entry}")
        elif os.path.isfile(backup_zip):
            with zipfile.ZipFile(backup_zip, "r") as zb:
                if entry in zb.namelist():
                    z.writestr(entry, zb.read(entry))
                    print(f"Preserved from backup: {entry}")

if os.path.isfile(backup_zip):
    os.remove(backup_zip)

print(f"[+] Total entries packed: {len(sorted_entries)}")
print("[+] patch.zip rebuilt successfully!")
