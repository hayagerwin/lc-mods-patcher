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

# Explicit configs and plugins
async_cfg = os.path.join(bepinex_dir, "config", "AsyncLoggers", "LogLevels.cfg")
if os.path.isfile(async_cfg):
    entries_to_pack.add("BepInEx/config/AsyncLoggers/LogLevels.cfg")

poltergeist_cfg = os.path.join(bepinex_dir, "config", "coderCleric.Poltergeist.cfg")
if os.path.isfile(poltergeist_cfg):
    entries_to_pack.add("BepInEx/config/coderCleric.Poltergeist.cfg")

fps_cfg = os.path.join(bepinex_dir, "config", "com.hayagerwin.lcfpscounter.cfg")
if os.path.isfile(fps_cfg):
    entries_to_pack.add("BepInEx/config/com.hayagerwin.lcfpscounter.cfg")

lvg_cfg = os.path.join(bepinex_dir, "config", "com.erwin.landingvoiceguard.cfg")
if os.path.isfile(lvg_cfg):
    entries_to_pack.add("BepInEx/config/com.erwin.landingvoiceguard.cfg")

lll_cfg = os.path.join(bepinex_dir, "config", "LethalLevelLoader.cfg")
if os.path.isfile(lll_cfg):
    entries_to_pack.add("BepInEx/config/LethalLevelLoader.cfg")

sponge_cfg = os.path.join(bepinex_dir, "config", "LethalSponge.cfg")
if os.path.isfile(sponge_cfg):
    entries_to_pack.add("BepInEx/config/LethalSponge.cfg")

cull_cfg = os.path.join(bepinex_dir, "config", "com.fumiko.CullFactory.cfg")
if os.path.isfile(cull_cfg):
    entries_to_pack.add("BepInEx/config/com.fumiko.CullFactory.cfg")

onlinefix_ini = os.path.join(game_root, "OnlineFix.ini")
if os.path.isfile(onlinefix_ini):
    entries_to_pack.add("OnlineFix.ini")

coroner_cfg_dir = os.path.join(bepinex_dir, "config", "EliteMasterEric-Coroner")
if os.path.isdir(coroner_cfg_dir):
    for f in os.listdir(coroner_cfg_dir):
        if f.endswith(".xml"):
            entries_to_pack.add(f"BepInEx/config/EliteMasterEric-Coroner/{f}")

for extra_plugin in ["EliteMasterEric-Coroner", "Turkeysteaks-CoronerIntegrations", "xilophor-StaticNetcodeLib", "fumiko-CullFactory"]:
    ep_dir = os.path.join(bepinex_dir, "plugins", extra_plugin)
    if os.path.isdir(ep_dir):
        for froot, _, ffiles in os.walk(ep_dir):
            for file_name in ffiles:
                full_path = os.path.join(froot, file_name)
                rel_path = os.path.relpath(full_path, game_root).replace(os.sep, "/")
                entries_to_pack.add(rel_path)

# Poltergeist sounds
poltergeist_sounds_dir = os.path.join(bepinex_dir, "plugins", "coderCleric-Poltergeist", "sounds")
if os.path.isdir(poltergeist_sounds_dir):
    for f in os.listdir(poltergeist_sounds_dir):
        full_p = os.path.join(poltergeist_sounds_dir, f)
        if os.path.isfile(full_p):
            entries_to_pack.add(f"BepInEx/plugins/coderCleric-Poltergeist/sounds/{f}")

# Patcher batch files placed in game root
for bat_file in ["lethal_company_patcher.bat", "update_patcher.bat"]:
    src_bat = os.path.join(patcher_dir, bat_file)
    if os.path.isfile(src_bat):
        dest_bat = os.path.join(game_root, bat_file)
        shutil.copy2(src_bat, dest_bat)
        entries_to_pack.add(bat_file)

# Prune any entries that are marked in delete_list.txt or no longer exist
delete_list_path = os.path.join(patcher_dir, "delete_list.txt")
if os.path.isfile(delete_list_path):
    with open(delete_list_path, "r", encoding="utf-8", errors="ignore") as f:
        del_lines = [line.strip().replace("\\", "/") for line in f if line.strip() and not line.startswith("#")]
    for del_item in del_lines:
        entries_to_pack = {e for e in entries_to_pack if not (e == del_item or e.startswith(del_item + "/"))}

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

# 5. Automatically bump patcher script build timestamp for seamless self-updates
import datetime, re
new_build_id = datetime.datetime.now().strftime("%Y%m%d%H%M%S")

bat_path = os.path.join(patcher_dir, "lethal_company_patcher.bat")
if os.path.isfile(bat_path):
    with open(bat_path, "r", encoding="utf-8", errors="ignore") as f:
        bat_code = f.read()
    bat_code = re.sub(r'set "PATCHER_VERSION=[0-9]+"', f'set "PATCHER_VERSION={new_build_id}"', bat_code)
    with open(bat_path, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(bat_code)
    print(f"[+] Bumped lethal_company_patcher.bat PATCHER_VERSION -> {new_build_id}")

py_path = os.path.join(patcher_dir, "lethal_company_patcher.py")
if os.path.isfile(py_path):
    with open(py_path, "r", encoding="utf-8", errors="ignore") as f:
        py_code = f.read()
    py_code = re.sub(r'PATCHER_VERSION = "[0-9]+"', f'PATCHER_VERSION = "{new_build_id}"', py_code)
    with open(py_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(py_code)
    print(f"[+] Bumped lethal_company_patcher.py PATCHER_VERSION -> {new_build_id}")

# Sync to user Documents if present
user_doc_bat = os.path.expandvars(r"%USERPROFILE%\Documents\lethal_company_patcher.bat")
if os.path.isfile(user_doc_bat):
    shutil.copy2(bat_path, user_doc_bat)
    print(f"[+] Synced latest patcher batch to: {user_doc_bat}")
