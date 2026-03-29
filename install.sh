#!/usr/bin/env bash
set -euo pipefail

# Developer install: clone (or use cwd), venv, editable install, deploy Fusion bridge add-in.
# Usage (from repo root after clone):
#   bash install.sh
# Or:
#   curl -fsSL https://raw.githubusercontent.com/BJam/fusion-cam-cli/main/install.sh | bash

REPO_URL="${FUSION_CAM_REPO_URL:-https://github.com/bjam/fusion-cam-cli.git}"
CLONE_DIR="${FUSION_CAM_CLONE_DIR:-}"

info()  { echo "  ✓ $*"; }
err()   { echo "  ✗ $*" >&2; }

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

    if [[ ! -d .venv ]]; then
        info "Creating .venv"
        python3 -m venv .venv
    fi

    # Use venv interpreters explicitly so we never hit Homebrew's PEP 668
    # "externally-managed-environment" if `python`/`pip` on PATH are not the venv's.
    venv_py="${PWD}/.venv/bin/python3"
    if [[ ! -x "$venv_py" ]]; then
        err ".venv is missing python3 (expected $venv_py). Remove .venv and retry: rm -rf .venv && bash install.sh"
        exit 1
    fi

    info "Upgrading pip (minimal)"
    "$venv_py" -m pip install -q --upgrade pip

    echo ""
    echo "── pip install -e . ──"
    "$venv_py" -m pip install -e .

    echo ""
    echo "── fusion-cam --install (Fusion bridge add-in) ──"
    "${PWD}/.venv/bin/fusion-cam" --install

    echo ""
    info "Done."
    echo ""
    echo "Next steps:"
    echo "  1. Open Fusion 360 → Scripts and Add-ins → run add-in: fusion-bridge"
    echo "  2. Use the CLI:  source .venv/bin/activate && fusion-cam ping"
    echo "  3. Cursor: keep .cursor/rules/fusion-cam-cli.mdc for agent guidance"
    echo ""
}

main
