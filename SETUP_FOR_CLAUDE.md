# SETUP_FOR_CLAUDE — Set up ARC-1 for ABAP work

**Audience: a Claude Code agent.** You are helping a developer configure ARC-1 so they can develop
SAP ABAP (classic + RAP / ABAP Cloud) from Claude Code. Follow these steps in order. Everything is
**parameterized** — the user runs their own SAP systems, users, clients, and transports, so **never
hardcode values from any example; always ask the user for their real values.**

> **Security guardrails you must respect the whole way through:**
> - Never write, echo, or store the SAP **password** in a plaintext file, in a `.env`, in git, or in
>   your own output. Passwords go only to the OS keychain or an encrypted/live-session store.
> - You may read and write ABAP source, but **treat writes to any SAP system as outward-facing**:
>   confirm the target system + transport with the user before the first write.
> - `secrets/` must be git-ignored before any commit.

---

## Step 0 — Detect the environment

Run these and record the answers (adapt to the shell you're in):

- OS / shell: Windows (PowerShell) vs macOS/Linux (bash/zsh).
- Is Node.js installed? `node -v` and `npm -v` (ARC-1 needs Node 18+; Node 20+ recommended).
- Is Claude Code CLI installed and reasonably current? `claude --version`.

If Node is missing, stop and tell the user to install Node LTS first.

---

## Step 1 — Install ARC-1

There are two ways to run ARC-1. **Install the plugin (Path A) for the smoothest Claude Code
experience.** Add the CLI (Path B) as well if the user has **more than one SAP system** or wants
fine-grained control of write-gating. They are not mutually exclusive.

### Path A — ARC-1 as a Claude Code plugin (recommended)

```bash
claude plugin marketplace add arc-mcp/arc-1
claude plugin install arc-1@arc-1
```

This bundles the MCP server (it runs via `npx -y arc-1`) plus the ABAP skills.

**Known install failure (deterministic — not VPN, not npm):** on an older Claude Code you get
`Unrecognized keys: "$schema", "displayName", "userConfig"`. That's a manifest-version mismatch.
Fix: `claude update`, restart Claude Code, then reinstall. (Confirmed broken on very old builds,
working on current ones.)

Configure the SAP connection for the plugin (this stores the **password in the OS keychain** — you,
the agent, must **not** fill the password yourself; let the user type it):

```bash
claude plugin configure arc-1@arc-1
```

It asks for `sap_url`, `sap_user`, `sap_password` (→ keychain). After configuring, the ARC-1 MCP
tools (`SAPRead`, `SAPSearch`, `SAPNavigate`, `SAPLint`, `SAPContext`, …) become available inside
Claude Code sessions.

### Path B — ARC-1 as a standalone CLI (for multi-system + write control)

```bash
npm install -g arc-1@latest
arc1 --version
```

> Gotcha: on some machines `npm install -g` is slow and fails with `ENETUNREACH` while a corporate
> VPN is on. If it fails, retry with the VPN off.

The CLI is driven through the Bash tool with `SAP_*` environment variables. To manage several
systems cleanly, install the multi-system helper in **Step 2**.

---

## Step 2 — Register the user's SAP system(s)

Ask the user, **for each system** they want to reach:

- A short **nickname** (SID-like, e.g. `dev`, `qas`, `s4d`) — used as the filename and switch key.
- `SAP_URL` — full base URL. **Include the port only if required.**
  - ⚠️ For **S/4HANA RISE / cloud** systems, use plain **`https://<host>` on port 443** — do **not**
    append `:44300`; that port does not pass the RISE load balancer.
- `SAP_CLIENT` — the client number.
- `SAP_USER` — the SAP user.
- The **password** — collected later, straight into the keychain / encrypted store (never a file).

### 2a — Set up the multi-system helper (recommended for Path B)

Create the config root `~/.arc1/` with `systems/` and `secrets/` subfolders, then copy the helper +
template from this repo:

**Windows (PowerShell):**
```powershell
New-Item -ItemType Directory -Force "$HOME\.arc1\systems","$HOME\.arc1\secrets" | Out-Null
Copy-Item .\templates\arc1env.ps1   "$HOME\.arc1\arc1env.ps1"
Copy-Item .\templates\_template.env "$HOME\.arc1\systems\_template.env"
# Dot-source the helper from the PowerShell profile so it loads every session:
Add-Content $PROFILE "`n. `"$HOME\.arc1\arc1env.ps1`""
. "$HOME\.arc1\arc1env.ps1"
```

**macOS / Linux (bash/zsh):**
```bash
mkdir -p "$HOME/.arc1/systems" "$HOME/.arc1/secrets"
cp ./templates/arc1env.sh   "$HOME/.arc1/arc1env.sh"
cp ./templates/_template.env "$HOME/.arc1/systems/_template.env"
# Source it from the shell rc so it loads every session:
echo '. "$HOME/.arc1/arc1env.sh"' >> "$HOME/.$(basename "$SHELL")rc"
. "$HOME/.arc1/arc1env.sh"
```

### 2b — Create one system file

Copy the template to `~/.arc1/systems/<nickname>.env` and fill in `SAP_URL`, `SAP_CLIENT`,
`SAP_USER` (and optional flags — see the template comments). **Leave the password out.**

```bash
cp ~/.arc1/systems/_template.env ~/.arc1/systems/<nickname>.env
# then edit <nickname>.env with the user's real URL / client / user
```

### 2c — Store the password (encrypted / never in a file)

- **Windows:** `Set-Arc1Secret <nickname>` — prompts hidden, encrypts with **DPAPI** (only this user
  on this machine can decrypt) into `~/.arc1/secrets/<nickname>.sec`.
- **macOS / Linux:** the bash helper prompts for the password **once per shell session** with
  `read -s` and keeps it only in the live `SAP_PASSWORD` env var (nothing written to disk). For
  durable storage, prefer the Path A plugin keychain.

Have the **user** type the password. Do not capture it into your context.

### 2d — Confirm `secrets/` is never committed

Ensure `~/.arc1/secrets/` is outside any git repo, and that this project's `.gitignore` excludes
`secrets/` and `*.sec`. (This repo already ships that `.gitignore`.)

---

## Step 3 — Activate a system and verify (read-only)

Switching systems loads that system's env + password into the current shell:

**Windows:** `Use-Arc1 <nickname>`   ·   **macOS/Linux:** `use_arc1 <nickname>`

Then a **read-only** smoke test:

```bash
arc1 call SAPRead --arg type=SYSTEM --output json
```

A successful response (system info / release) confirms the connection. If it fails: check URL/port
(RISE = 443, no :44300), client, user, password, and network/VPN.

> 🔴 **The #1 gotcha: environment variables do NOT persist between separate shell/Bash calls.**
> Every time you (the agent) start a new shell command that talks to a system, you must re-activate
> in the *same* command, e.g.:
> - Windows: `. $HOME\.arc1\arc1env.ps1; Use-Arc1 <nickname>; arc1 call SAPRead ...`
> - macOS/Linux: `. $HOME/.arc1/arc1env.sh; use_arc1 <nickname>; arc1 call SAPRead ...`

---

## Step 4 — Understand write-gating BEFORE writing code

For safety, ARC-1's **write** tools are hidden unless explicitly enabled. By default only read/query
tools register (`SAPRead`, `SAPSearch`, `SAPNavigate`, `SAPLint`, `SAPDiagnose`, `SAPContext`,
`SAPManage`, `SAPTransport`, `SAPGit`). To enable writes, set these env vars **inline in the same
shell call** that runs the write (they don't persist):

| Env var | Enables |
|---------|---------|
| `SAP_ALLOW_WRITES=true` | `SAPWrite`, `SAPActivate` |
| `SAP_ALLOWED_PACKAGES=<pkg,...>` | restricts writes to these packages |
| `SAP_ALLOWED_TRANSPORTS=<TR,...>` | restricts writes to these transport requests |
| `SAP_ALLOW_TRANSPORT_WRITES=true` | allow creating/modifying transport content |
| `SAP_ALLOW_FREE_SQL=true` | `SAPQuery` (free-form SQL, read-only DB) |
| `SAP_ALLOW_DATA_PREVIEW=true` | table/CDS data preview |

**Before the first write, confirm the target system + transport with the user.** Some connections
are intentionally **read-only** (the write flags are simply never set) — respect that.

Write mechanics that save time:
- Build the JSON payload with a small Node script rather than fighting shell escaping:
  `arc1 call SAPWrite --json <file>`.
- For method bodies, `action=edit_method` takes **only the body** (no `METHOD`/`ENDMETHOD`) plus
  `method=<name>` — cheap and reliable. `add_method` / `edit_method_signature` also work.
- After writing, **activate**: `arc1 activate CLAS <name>` (or the right object type). Syntax checks
  run against the **active** version, so a broken active object shows stale errors until you activate.
- `edit_class_definition` may be blocked by Claude Code's own auto-permission classifier (not by
  ARC-1). If so, the user must paste the DEFINITION changes or relax their permission mode;
  `add_method` / `edit_method` are not blocked.

---

## Step 5 — Use the ABAP skills and lessons (don't reinvent patterns)

The ARC-1 plugin ships a large catalog of ABAP skills. **Consult them before coding.** Highlights:

- **`abap-rap-adt`** — the umbrella skill for developing/inspecting/troubleshooting ABAP (RAP
  preferred, classic supported). Package-first discovery, RAP generators, clean-core rules,
  activation checks.
- **`arc-1:bootstrap-system-context`** — grounds you in a new/unfamiliar SAP system (release,
  components, RAP constraints) → writes a local `system-info.md`. Run this first against a new system.
- **`arc-1:explain-abap-code`**, **`arc-1:generate-rap-service`**, **`arc-1:generate-rap-logic`**,
  **`arc-1:migrate-custom-code`**, **`arc-1:sap-clean-core-atc`**, **`arc-1:generate-abap-unit-test`**,
  **`arc-1:sap-transport-review`**, and more — invoke the one that matches the task.

**Workflow for any ABAP task:**
1. Activate the correct target system (Step 3).
2. If the system is new to you, run `arc-1:bootstrap-system-context`.
3. Discover the package/objects first (`SAPSearch` / `SAPContext`) — understand before changing.
4. Consult the matching skill + any lessons-learned; follow the package's existing patterns.
5. Make the change, activate, run syntax/ATC (`SAPLint` / `arc1 syntax ...`), report results honestly.

---

## Step 6 — Make it permanent

Paste the block in [`CLAUDE.md.snippet`](CLAUDE.md.snippet) into the user's global
`~/.claude/CLAUDE.md` so every future session knows to route ABAP work through ARC-1 and to connect a
system first. Fill in the user's own system nicknames.

---

## Done — hand back to the user

Report to the user:
- Which install path(s) you set up (plugin / CLI / both).
- Which system nickname(s) are registered and verified.
- That the password is in the keychain / encrypted store (never a file).
- The one command they run to start working: activate a system, then go.
