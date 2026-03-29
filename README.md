# Fusion 360 CAM CLI (`fusion-cam`)

> **WARNING — This project is a work in progress.**
>
> 1. **APIs may change without notice.** Commands, behavior, and configuration are still evolving.
> 2. **In full mode, assistants can write data directly to your Fusion 360 document** — including feeds, speeds, and machining parameters. Incorrect changes could affect real toolpaths and G-code output.
> 3. **Windows installation and usage is lightly tested;** report issues if something breaks.

A **Python CLI** that talks to Fusion 360 CAM over a small **TCP JSON** protocol. The **fusion-bridge** add-in runs inside Fusion, listens on `127.0.0.1:9876`, and executes query scripts on the Fusion main thread. The add-in is generic TCP → Fusion API, not CAM-only.

Use it from a terminal, from scripts, or from agent tools that run shell commands (for example Cursor). There are **no GitHub release binaries** and **no PyInstaller build**; install with **pip** from a clone (or a future PyPI package).

## Architecture

```mermaid
flowchart LR
    Terminal -->|"fusion-cam (JSON stdout)"| CLI
    CLI -->|"TCP"| Bridge
    Bridge -->|"adsk.cam API"| Fusion_360
```

- **`fusion-cam`** — this repo, package `fusion_cam` under `src/fusion_cam/`. Stdlib only.
- **`fusion-bridge/`** — Fusion 360 add-in. Any local client can send Python over TCP.

## Commands (overview)

Read commands work in the default **read-only** mode. Writes need **`--mode full`** on the same invocation.

### Read

| Command | Description |
| ------- | ----------- |
| `ping` | Health check — bridge reachable |
| `list-documents` | Open documents and CAM summary |
| `get-document-info` | Active document metadata |
| `get-setups` | Setups, machine, stock, materials |
| `get-operations` | Operations, feeds, speeds, tools, coolant, notes |
| `get-operation-details` | Full parameter dump + computed metrics |
| `get-tools` | Tools in the document |
| `get-library-tools` | External tool libraries |
| `get-machining-time` | Estimated cycle times |
| `get-toolpath-status` | Toolpath validity / outdated |
| `get-nc-programs` | NC programs and post settings |
| `list-material-libraries` | Material libraries |
| `get-material-properties` | Material properties |

### Write (`--mode full`)

| Command | Description |
| ------- | ----------- |
| `update-operation-parameters` | Feeds, speeds, engagement |
| `assign-body-material` | Assign library material to a body |
| `create-custom-material` | Copy material and override properties |
| `update-setup-machine-params` | Machine limits on a setup |
| `generate-toolpaths` | Regenerate toolpaths |
| `post-process` | Post to NC/G-code |

Examples (same as `fusion-cam … --help` for each command):

```bash
fusion-cam generate-toolpaths --mode full --setup-name "Setup1"
fusion-cam post-process --mode full --setup-name "Setup1" --output-folder /tmp/nc
```

Use `fusion-cam COMMAND --help` for flags and examples. Output is **one JSON object** on stdout: `{"success": true, "data": ...}` or `{"success": false, "error": "...", "code": "..."}`.

## Prerequisites

1. **Fusion 360** — [Autodesk](https://www.autodesk.com/products/fusion-360/overview)
2. **Python 3.10+** on the machine where you run the CLI

## Quick install

### Option A — Virtual environment (isolated)

From a clone of this repository:

```bash
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -e .
fusion-cam --install        # copies bridge add-in into Fusion’s AddIns folder
```

### Option B — Editable install for your user (no venv; Cursor-friendly)

From the **repo root**, install once. Code changes in the clone are picked up immediately; `fusion-cam` is on your PATH whenever your shell includes Python’s **user scripts** directory (many setups already do).

```bash
cd /path/to/fusion-cam-cli
python3 -m pip install --user -e .
fusion-cam --install
```

If `fusion-cam` is not found, add the user base `bin` directory to PATH (one line for `~/.zshrc` / `~/.bashrc`):

```bash
export PATH="$(python3 -m site --user-base)/bin:$PATH"
```

Check where scripts go: `python3 -m site --user-base` (append `/bin` on macOS/Linux; on Windows, use the `Scripts` folder under that path).

**Windows (PowerShell):** same `pip install --user -e .`; if needed, prepend the `Scripts` path from `python -m site --user-base` to your user PATH.

Or run the helper script (expects you to already be in the repo, or set `FUSION_CAM_CLONE_DIR`). It tries **`pip install --user -e .`**, then **links `fusion-cam` into `~/.local/bin`** (Windows: `fusion-cam.cmd` in the same folder), then runs **`fusion-cam --install`**. **Homebrew Python** often blocks user installs (PEP 668); the script then **creates `.venv`**, links that executable into **`~/.local/bin`**, and continues. Add **`~/.local/bin`** to your **`PATH`** once (e.g. `export PATH="$HOME/.local/bin:$PATH"` in `~/.zshrc`) so **`which fusion-cam`** works in Cursor and new terminals. To **always** use a venv, set `FUSION_CAM_INSTALL_USE_VENV=1`.

```bash
bash install.sh
```

**Windows (PowerShell):** `.\install.ps1` (same try-user-then-venv; `$env:FUSION_CAM_INSTALL_USE_VENV='1'` forces venv)

Then in Fusion: **UTILITIES → ADD-INS** → run **fusion-bridge** (optionally **Run on Startup**).

## Manual add-in (contributors)

If you skip `fusion-cam --install`, add the repo folder `fusion-bridge/` via the green **+** next to My Add-Ins so Fusion loads it directly from git.

If you still have an older bridge add-in entry under Fusion’s AddIns, remove it in **UTILITIES → ADD-INS**, then run **`fusion-cam --install`** so **`fusion-bridge`** is the only copy.

## Configuration

### TCP port

Default **`9876`**. Override with **`FUSION_CAM_BRIDGE_PORT`** for both the CLI and the add-in.

### Machining time defaults

Same assumptions as before (feed scale, rapid rate, tool-change time); see `get-machining-time` help for details.

## How it works

1. The bridge starts a **localhost-only** TCP server.
2. The CLI loads query modules from `src/fusion_cam/queries/` and sends them to the bridge.
3. The bridge runs them on Fusion’s **main thread** and returns JSON.

Security model: only local processes can connect. Scripts are executed by design; treat the machine as trusted.

## Uninstall

```bash
fusion-cam --uninstall
```

Removes the copied add-in from Fusion’s AddIns folder and metadata under `fusion-cam-cli`.

## AI assistants

1. **Install** the CLI and add-in as in [Quick install](#quick-install). **Fusion 360** must be running with **fusion-bridge** started before any `fusion-cam` call.
2. Run **`fusion-cam` only through a real terminal** (agents should execute shell commands, not invent output). **Stdout is one JSON object** per invocation — parse `success`, `error`, and `code`.
3. Use **`--mode full`** on the same command for writes (see [Write (`--mode full`)](#write---mode-full)).
4. Prefer compact JSON; add **`--pretty`** when you need readable output.
5. **`fusion-cam --help`** documents subcommands, flags, and `debug`. For Cursor, this repo includes **`.cursor/rules/fusion-cam-cli.mdc`** and **`.cursor/commands/fusion-cam.md`** with the same guidance in agent-oriented form.

Other AI tools use the same setup and steps; point their project instructions at this section and **`fusion-cam --help`** (or add a short **`AGENTS.md`** / **`CLAUDE.md`** that links here).

## License

[MIT](LICENSE)
