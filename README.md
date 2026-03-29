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

## Cursor and AI assistants

For the best experience with Cursor or other assistants that run shell commands:

1. **Open this repository as the workspace** so Cursor loads **Project Rules** from `.cursor/rules/` (or confirm the rule appears under **Cursor Settings → Rules**).
2. **Install the CLI** as in [Quick install](#quick-install) and keep **Fusion 360** running with the **fusion-bridge** add-in started before the assistant runs terminal commands.
3. **Invoke `fusion-cam` only via the terminal** (not as imagined plain chat output). **Stdout is a single JSON object** — parse it; do not assume plain text.
4. Use **`--mode full`** on the same command for any write operation (see [Write (`--mode full`)](#write---mode-full)).
5. Prefer **compact JSON** (omit `--pretty`) unless you need indented output for debugging.

Full workflow, global flags, and the `debug` command are documented in **`fusion-cam --help`** and in **`.cursor/rules/fusion-cam-cli.mdc`**.

**Repo vs user rules:** Project rules under `.cursor/rules/` load when this repo is the workspace. If you work in other folders but still use `fusion-cam`, add a **user-level** rule in Cursor so the same guidance applies everywhere. To avoid maintaining two copies, point the user rule at the repo file with a **symlink** (exact path for user rules depends on your Cursor version — check **Settings → Rules**):

```bash
ln -sf /path/to/fusion-cam-cli/.cursor/rules/fusion-cam-cli.mdc /path/to/your/global/rules/fusion-cam-cli.mdc
```

Keep the **canonical file in this repository** (what git tracks). Do **not** commit a project rule that symlinks into `~/.cursor` — that path is machine-specific. Symlinks break if you move the clone; other machines need their own link or rely on the project rule only.

### Other assistants (Claude Code, local LLMs, etc.)

**`.cursor/rules/*.mdc`** is loaded by **Cursor**; other apps generally do **not** read it unless they explicitly support that path.

The same **workflow** still applies: install `fusion-cam`, keep **Fusion 360** and **fusion-bridge** running, run **`fusion-cam` from a real terminal**, treat **stdout as one JSON object**, and use **`--mode full`** for writes. Details: **`fusion-cam --help`** and this section above.

To give non-Cursor tools project context, add a short file they already load (for example **`CLAUDE.md`** or **`AGENTS.md`** at the repo root, depending on the product) that either repeats the bullet list above or points here plus **`.cursor/rules/fusion-cam-cli.mdc`** for the full contract. Prefer **one** canonical copy of the long rule in git (the `.mdc` file) and a **brief** pointer elsewhere so you are not duplicating large blocks in multiple places.

## License

[MIT](LICENSE)
