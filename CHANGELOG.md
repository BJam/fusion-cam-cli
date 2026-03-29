# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Distribution** — PyPI / metadata project name is **`fusion-cam-cli`**; **`fusion-cam --install` / `--uninstall`** only manage the **`fusion-bridge`** add-in and `fusion-cam-cli` metadata (no IDE config edits; no automatic removal of other add-in folders). TCP port: **`FUSION_CAM_BRIDGE_PORT`** only, default **9876** (legacy env alias removed).
- **`install.sh` / `install.ps1`** — Try **`pip install --user -e .`** first; if blocked (e.g. Homebrew PEP 668), **fall back to `.venv`**. No user-scope **`pip install --upgrade pip`** (often fails on managed Pythons). Set **`FUSION_CAM_INSTALL_USE_VENV=1`** to always use `.venv`. After install, **`fusion-cam` is linked into `~/.local/bin`** (macOS/Linux: symlink; Windows: `fusion-cam.cmd`) so one **`PATH`** entry can expose the CLI globally.

### Breaking

- **Bundled stdio server removed** — Use the **`fusion-cam`** CLI only (package `fusion_cam` under `src/fusion_cam/`).
- **GitHub release binaries removed** — No PyInstaller artifacts or `release.yml` workflow. Install with `pip install -e .` (or future PyPI) and `fusion-cam --install` for the bridge add-in.
- **Layout** — Importable package is `fusion_cam`; entry point `fusion-cam = fusion_cam.cli:main`. Root `fusion_cam.py` and old server layout paths are gone.

### Fixed

- **Edit dialog guard** -- All write operations (update parameters, assign material,
  create material, generate toolpaths, post-process) now detect when an edit dialog
  is open in Fusion 360 and return a clear error instead of making changes that would
  be silently lost if the user cancels the dialog. Checks `activeCommand` to ensure
  no command transaction is in progress before writing.

## [0.1.0] - 2026-02-15

### Added

- Initial public release
- **Programmatic CAM interface** with 18 tools (14 read, 4 write)
- **Bridge add-in** for Fusion 360 (folder id is now `fusion-bridge`; see newer changelog entries)

#### Read Tools
- `ping` -- health check for add-in connection
- `list_documents` -- list all open Fusion 360 documents
- `get_document_info` -- document metadata (name, units, CAM counts)
- `get_setups` -- setups with machine info, stock dimensions, body materials
- `get_operations` -- operations with feeds, speeds, tools, engagement, coolant, notes
- `get_operation_details` -- full parameter dump with computed metrics (chip load, surface speed, stepover ratio)
- `get_tools` -- tool inventory with holder info and operation usage
- `get_machining_time` -- estimated cycle times per setup/operation
- `get_toolpath_status` -- toolpath generation status and validity
- `get_nc_programs` -- list NC programs with operations, post-processor config, and output settings
- `list_material_libraries` -- browse material libraries
- `get_material_properties` -- read physical/mechanical material properties
- `generate_toolpaths` -- trigger toolpath generation for operations or setups
- `post_process` -- post-process operations to generate NC/G-code files

#### Write Tools (requires `--mode full`)
- `update_operation_parameters` -- update feeds, speeds, and engagement parameters
- `assign_body_material` -- assign physical material to a body
- `create_custom_material` -- create custom material from existing template
- `update_setup_machine_params` -- update machine-level parameters on a setup

#### Operation Parameters
- Feeds: cutting, entry, exit, plunge, ramp, retract, transition, per-tooth
- Speeds: spindle RPM, ramp spindle speed, direction
- Engagement: stepover, stepdown, finish stepover/stepdown, optimal load, load deviation
- Strategy: tolerance, stock to leave, direction, compensation, zigzag
- Heights: clearance, retract, feed, top, bottom (values and offsets)
- Linking: lead-in/lead-out, ramp type/angle/diameter, entry/exit positions
- Drilling: cycle type, dwell time, peck depth, break-through
- Passes: number of stepdowns, finishing passes, multiple depths
- Tool geometry: diameter, flutes, lengths, corner radius, taper/tip angles
- Tool holder: description, diameter, length
- Coolant mode per operation
- Operation notes

#### Computed Metrics
- Surface speed (m/min, SFM)
- Chip load per tooth (mm, inches)
- Stepover-to-diameter ratio
