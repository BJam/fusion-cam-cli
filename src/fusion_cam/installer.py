"""
Install / uninstall the Fusion bridge add-in (fusion-bridge) for the fusion-cam CLI.

Copies the bundled add-in into Fusion 360's AddIns directory. Does not install
a standalone binary.
"""

from __future__ import annotations

import json
import os
import platform
import shutil
import sys
from pathlib import Path


def _get_version() -> str:
    from .version_info import __version__

    return __version__


def _get_install_dir() -> str:
    system = platform.system()
    if system == "Darwin":
        return os.path.join(
            os.path.expanduser("~"),
            "Library",
            "Application Support",
            "fusion-cam-cli",
        )
    elif system == "Windows":
        return os.path.join(
            os.environ.get(
                "LOCALAPPDATA", os.path.join(os.path.expanduser("~"), "AppData", "Local")
            ),
            "fusion-cam-cli",
        )
    return os.path.join(
        os.environ.get("XDG_DATA_HOME", os.path.join(os.path.expanduser("~"), ".local", "share")),
        "fusion-cam-cli",
    )


INSTALL_DIR = _get_install_dir()


def _get_fusion_addins_dir() -> str:
    system = platform.system()
    if system == "Darwin":
        return os.path.join(
            os.path.expanduser("~"),
            "Library",
            "Application Support",
            "Autodesk",
            "Autodesk Fusion 360",
            "API",
            "AddIns",
        )
    elif system == "Windows":
        return os.path.join(
            os.environ.get("APPDATA", ""),
            "Autodesk",
            "Autodesk Fusion 360",
            "API",
            "AddIns",
        )
    return os.path.join(os.path.expanduser("~"), "fusion-cam-cli", "fusion-bridge")


ADDIN_DEST = os.path.join(_get_fusion_addins_dir(), "fusion-bridge")


def _package_dir() -> Path:
    return Path(__file__).resolve().parent


def _get_bundled_addin_dir() -> str | None:
    """Wheel: bridge_addon next to package. Dev: repo fusion-bridge/."""
    pkg = _package_dir()
    embedded = pkg / "bridge_addon"
    if (embedded / "fusion-bridge.manifest").is_file():
        return str(embedded)
    # src/fusion_cam/installer.py -> parents: fusion_cam, src, repo
    repo = pkg.parent.parent
    root_bridge = repo / "fusion-bridge"
    if (root_bridge / "fusion-bridge.manifest").is_file():
        return str(root_bridge)
    return None


def _prompt(message: str, default: str = "y", valid: set | None = None) -> str:
    while True:
        try:
            answer = input(f"  {message} [{default}]: ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            sys.exit(1)
        result = answer or default
        if valid is None or result in valid:
            return result
        print(f"  Invalid choice '{result}'. Please enter one of: {', '.join(sorted(valid))}")


def _get_fusion_base_dir() -> str:
    system = platform.system()
    if system == "Darwin":
        return os.path.join(
            os.path.expanduser("~"),
            "Library",
            "Application Support",
            "Autodesk",
            "Autodesk Fusion 360",
        )
    elif system == "Windows":
        return os.path.join(
            os.environ.get("APPDATA", ""),
            "Autodesk",
            "Autodesk Fusion 360",
        )
    return ""


def _check_fusion_installed() -> bool:
    fusion_dir = _get_fusion_base_dir()
    if not fusion_dir:
        return True
    return os.path.isdir(fusion_dir)


def _extract_addin() -> str:
    source = _get_bundled_addin_dir()
    if not source or not os.path.isdir(source):
        print("  ERROR: Add-in source not found (expected bundled bridge or repo fusion-bridge/).")
        sys.exit(1)
    try:
        shutil.copytree(source, ADDIN_DEST, dirs_exist_ok=True)
    except (OSError, PermissionError) as e:
        print(f"  ERROR: Cannot extract add-in to {ADDIN_DEST}: {e}")
        sys.exit(1)
    return ADDIN_DEST


def _version_file() -> str:
    return os.path.join(INSTALL_DIR, "version.json")


def _write_installed_version(version: str) -> None:
    path = _version_file()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump({"version": version}, f, indent=2)
            f.write("\n")
    except OSError:
        pass


def run_uninstall() -> None:
    print()
    print("╔══════════════════════════════════════════════╗")
    print("║     Fusion CAM CLI — Uninstall               ║")
    print("╚══════════════════════════════════════════════╝")
    print()
    confirm = _prompt("  Remove fusion-bridge add-in from Fusion's AddIns folder? (y/n)", "n", {"y", "n"})
    if confirm.lower() != "y":
        print("  Cancelled.")
        return

    print()
    print("── Removing Fusion bridge add-in ──")
    removed_any = False
    if os.path.isdir(ADDIN_DEST):
        removed_any = True
        try:
            shutil.rmtree(ADDIN_DEST)
            print(f"  Removed {ADDIN_DEST}")
        except OSError as e:
            print(f"  ERROR: Cannot remove add-in at {ADDIN_DEST}: {e}")
    if not removed_any:
        print(f"  Add-in not found at {ADDIN_DEST}")

    vf = _version_file()
    if os.path.isfile(vf):
        try:
            os.remove(vf)
        except OSError:
            pass
    if os.path.isdir(INSTALL_DIR):
        try:
            os.rmdir(INSTALL_DIR)
        except OSError:
            pass

    print()
    print("── Uninstall complete! ──")
    print()
    print("  In Fusion: UTILITIES > ADD-INS — remove fusion-bridge from the list if needed.")
    print()


def run_install() -> None:
    version = _get_version()
    print()
    print("╔══════════════════════════════════════════════╗")
    print("║     Fusion CAM CLI — Install bridge add-in ║")
    print("╚══════════════════════════════════════════════╝")
    print()
    print(f"  CLI / package version: {version}")
    print(f"  Add-in destination:     {ADDIN_DEST}")
    print()

    if not _check_fusion_installed():
        print("  WARNING: Fusion 360 default data folder not found.")
        print(f"    Expected: {_get_fusion_base_dir()}")
        skip = _prompt("  Install add-in files anyway? (y/n)", "n", {"y", "n"})
        if skip.lower() != "y":
            print("  Cancelled.")
            return

    print()
    print("── Extracting Fusion bridge add-in ──")
    addin_path = _extract_addin()
    print(f"  Add-in installed to: {addin_path}")

    _write_installed_version(version)

    print()
    print("── Next steps ──")
    print()
    print("  1. Open Fusion 360")
    print('  2. UTILITIES > ADD-INS — find "fusion-bridge" under My Add-Ins → Run')
    print("  3. In Cursor: use the terminal — `fusion-cam ping` (after pip install -e .)")
    print("  4. Optional: enable .cursor/rules in this repo for agent hints")
    print()
    print("  Uninstall:  fusion-cam --uninstall")
    print()
