# fusion-cam (quick playbook)

Use when the agent should call the Fusion CAM CLI. **Persistent guidance** lives in **`.cursor/rules/fusion-cam-cli.mdc`** (project rule); this command is an optional **on-demand** reminder.

- **Fusion 360** running with **fusion-bridge**; **`fusion-cam`** on PATH (see README Quick install).
- Run **`fusion-cam` only in the terminal**; **stdout is one JSON object** — parse it (`success` / `error` / `code`).
- **Writes** need **`--mode full`** on the same command as the subcommand.
- Prefer compact JSON; use `--pretty` when debugging.
- Full detail: **`fusion-cam --help`** and **`.cursor/rules/fusion-cam-cli.mdc`**.
