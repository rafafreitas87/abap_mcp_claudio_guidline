# ABAP + ARC-1 + Claude Code — Setup Guideline

This repo is a **self-contained onboarding kit** for anyone who wants to develop **SAP ABAP**
(classic ABAP *and* RAP / ABAP Cloud) from inside **Claude Code**, driven by the **ARC-1** MCP
server / CLI.

It is written to be **read and executed by your Claude Code agent**. You do not have to run the
steps by hand — point Claude at this repo and let it set everything up on your machine, against
*your* SAP systems, users, and transports.

---

## Quick start (what to tell your Claude Code)

Clone this repo somewhere, open Claude Code in it, and paste:

> Read **`SETUP_FOR_CLAUDE.md`** and set up ARC-1 for ABAP work on my machine. Ask me for my SAP
> connection details when you need them. Never write my SAP password to a plaintext file.

Claude will then:

1. Install ARC-1 (Claude Code plugin **and/or** the `arc-1` CLI).
2. Help you register your SAP system(s) — connection details in files, **password only in the OS keychain**.
3. Verify the connection with a read-only call.
4. Load the ABAP skills and lessons before writing any code.

---

## What's in here

| File | Purpose |
|------|---------|
| [`SETUP_FOR_CLAUDE.md`](SETUP_FOR_CLAUDE.md) | **The main guideline.** Machine-readable, step-by-step. This is the one your Claude Code executes. |
| [`CLAUDE.md.snippet`](CLAUDE.md.snippet) | A rule block to paste into your global `~/.claude/CLAUDE.md` so *every* future session knows to use ARC-1 for ABAP. |
| [`templates/_template.env`](templates/_template.env) | Blank per-system connection file. Copy once per SAP system. |
| [`templates/arc1env.ps1`](templates/arc1env.ps1) | **Windows** multi-system helper (`Use-Arc1`, `Set-Arc1Secret`, `Get-Arc1Systems`). Password encrypted with DPAPI. |
| [`templates/arc1env.sh`](templates/arc1env.sh) | **macOS / Linux** equivalent helper. Password kept only in the live shell session. |
| [`reference/cheatsheet.md`](reference/cheatsheet.md) | Daily commands, the **write-gating** env vars, and the gotchas that waste the most time. |
| [`reference/analise-funcional-mm-readonly.md`](reference/analise-funcional-mm-readonly.md) | **Read-only quick guide for functional consultants** (PT-BR, MM focus): analyze SAP data with ARC-1, no writes. |

---

## Golden rules (non-negotiable)

- 🔑 **Never** put a SAP password in a `.env` file, a git repo, or any plaintext. Passwords live in
  the OS keychain (plugin path) or a per-user encrypted store / live session only (CLI path).
- 🧭 **Always connect a target system before** any read or write.
- 📚 **Consult the ABAP skills and lessons before coding** — don't reinvent patterns.
- 🚫 **`secrets/` is git-ignored.** Confirm it before your first commit.

---

*This is a personal, unofficial setup guide. ARC-1 is a third-party product; follow your own
company's security and change-management policies for any real SAP system.*
