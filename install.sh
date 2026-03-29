#!/usr/bin/env bash
set -euo pipefail

# Developer install: clone (or use cwd), editable install, deploy Fusion bridge add-in.
# Default: try pip install --user -e . (no venv). If blocked (e.g. Homebrew PEP 668), uses .venv.
# Override:
#   FUSION_CAM_INSTALL_USE_VENV=1  — always use .venv + pip install -e .
# Usage (from repo root after clone):
#   bash install.sh
# Or:
#   curl -fsSL https://raw.githubusercontent.com/BJam/fusion-cam-cli/main/install.sh | bash

REPO_URL="${FUSION_CAM_REPO_URL:-https://github.com/bjam/fusion-cam-cli.git}"
CLONE_DIR="${FUSION_CAM_CLONE_DIR:-}"
USE_VENV="${FUSION_CAM_INSTALL_USE_VENV:-}"

info()  { echo "  ✓ $*"; }
err()   { echo "  ✗ $*" >&2; }

user_scripts_bin() {
    python3 -c "import site, os; print(os.path.join(site.getuserbase(), 'bin'))"
}

fusion_cam_executable() {
    local bin_dir
    bin_dir="$(user_scripts_bin)"
    echo "${bin_dir}/fusion-cam"
}

# Canonical user bin (single PATH entry for Cursor / shells).
user_local_bin() {
    echo "${HOME}/.local/bin"
}

# Symlink fusion-cam here so `which fusion-cam` works once ~/.local/bin is on PATH.
link_fusion_cam_shim() {
    local target="$1"
    local dir sh abs
    dir="$(user_local_bin)"
    sh="${dir}/fusion-cam"
    mkdir -p "$dir"
    if [[ "$target" != /* ]]; then
        abs="${PWD}/${target}"
    else
        abs="$target"
    fi
    if [[ ! -e "$abs" ]]; then
        err "Cannot link fusion-cam: not found at $abs"
        exit 1
    fi
    ln -sf "$abs" "$sh"
    info "fusion-cam → $sh"
}

ensure_repo() {
    if [[ -f pyproject.toml ]] && grep -q 'name = "fusion-cam-cli"' pyproject.toml 2>/dev/null; then
        return 0
    fi
    if [[ -z "$CLONE_DIR" ]]; then
        err "Not in the fusion-cam-cli repo root (no pyproject.toml). Set FUSION_CAM_CLONE_DIR or clone first:"
        err "  git clone $REPO_URL && cd fusion-cam-cli && bash install.sh"
        exit 1
    fi
    if [[ ! -d "$CLONE_DIR" ]]; then
        info "Cloning into $CLONE_DIR"
        git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
    fi
    cd "$CLONE_DIR"
}

do_venv_install() {
    if [[ ! -d .venv ]]; then
        info "Creating .venv"
        python3 -m venv .venv
    fi
    local venv_py="${PWD}/.venv/bin/python3"
    if [[ ! -x "$venv_py" ]]; then
        err ".venv is missing python3 (expected $venv_py). Remove .venv and retry: rm -rf .venv && bash install.sh"
        exit 1
    fi
    info "Upgrading pip (minimal)"
    "$venv_py" -m pip install -q --upgrade pip
    echo ""
    echo "── pip install -e . (venv) ──"
    "$venv_py" -m pip install -e .
}

main() {
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║  Fusion 360 CAM CLI — developer install      ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""

    ensure_repo

    if ! command -v python3 &>/dev/null; then
        err "python3 not found. Install Python 3.10+ and retry."
        exit 1
    fi

    local fusion_cam=""
    local installed_mode=""

    if [[ -n "$USE_VENV" && "$USE_VENV" != "0" ]]; then
        info "Using virtual environment (FUSION_CAM_INSTALL_USE_VENV is set)"
        do_venv_install
        fusion_cam="${PWD}/.venv/bin/fusion-cam"
        installed_mode="venv"
    else
        info "Trying editable install for your user (no venv) …"
        echo ""
        echo "── pip install --user -e . ──"
        if python3 -m pip install -q --user -e . 2>/dev/null; then
            fusion_cam="$(fusion_cam_executable)"
            if [[ -f "$fusion_cam" ]]; then
                installed_mode="user"
                info "User install OK"
            fi
        fi
        if [[ -z "$installed_mode" ]]; then
            echo ""
            info "User install unavailable (common with Homebrew Python / PEP 668). Using .venv."
            do_venv_install
            fusion_cam="${PWD}/.venv/bin/fusion-cam"
            installed_mode="venv"
        fi
    fi

    echo ""
    echo "── Link fusion-cam into ~/.local/bin ──"
    link_fusion_cam_shim "$fusion_cam"

    echo ""
    echo "── fusion-cam --install (Fusion bridge add-in) ──"
    "$fusion_cam" --install

    echo ""
    info "Done."
    echo ""
    echo "Next steps:"
    echo "  1. Open Fusion 360 → Scripts and Add-ins → run add-in: fusion-bridge"
    echo "  2. Use the CLI:  fusion-cam ping"
    if [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
        echo "     If \`fusion-cam\` is not found, add ~/.local/bin to PATH, e.g.:"
        echo "       export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo "     (put that in ~/.zshrc or ~/.bashrc for new terminals / Cursor)"
    fi
    echo "  3. Cursor: keep .cursor/rules/fusion-cam-cli.mdc for agent guidance"
    echo "  4. Force venv: FUSION_CAM_INSTALL_USE_VENV=1 bash install.sh"
    echo ""
}

main
