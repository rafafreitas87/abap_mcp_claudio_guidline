# ARC-1 daily cheatsheet

## Activate a system (do this in the SAME shell call as your arc1 command)

Windows:
```powershell
. $HOME\.arc1\arc1env.ps1; Use-Arc1 <nickname>; arc1 call SAPRead --arg type=SYSTEM --output json
```

macOS / Linux:
```bash
. $HOME/.arc1/arc1env.sh; use_arc1 <nickname>; arc1 call SAPRead --arg type=SYSTEM --output json
```

Helper commands:
- `Get-Arc1Systems` / `arc1_systems` — list configured systems
- `Use-Arc1 <sid>` / `use_arc1 <sid>` — switch the active system
- `Set-Arc1Secret <sid>` / `set_arc1_secret <sid>` — store/update the password

## Read / explore (always safe)
```bash
arc1 call SAPRead   --arg type=CLAS --arg name=ZCL_FOO --output json
arc1 call SAPSearch --arg query=ZCL_FOO*
arc1 call SAPContext --arg type=CLAS --arg name=ZCL_FOO      # dependencies / where-used
arc1 syntax CLAS ZCL_FOO                                     # syntax check (active version)
```

## Write (only with gating flags set INLINE, per call)
```bash
# Windows example — note flags are on the SAME line, they don't persist:
. $HOME\.arc1\arc1env.ps1; Use-Arc1 <nickname>; `
  $env:SAP_ALLOW_WRITES='true'; $env:SAP_ALLOWED_PACKAGES='ZPKG'; `
  $env:SAP_ALLOWED_TRANSPORTS='<TR>'; $env:SAP_ALLOW_TRANSPORT_WRITES='true'; `
  arc1 call SAPWrite --json payload.json
arc1 activate CLAS ZCL_FOO
```
- Build `payload.json` with a small Node script to avoid shell-escaping pain.
- `action=edit_method` → pass only the method **body** (no `METHOD`/`ENDMETHOD`) + `method=<name>`.
- Syntax runs against the **active** version — activate before trusting the result.

## The gotchas that waste the most time
1. **Env vars don't persist between shell calls.** Re-activate every call (see top).
2. **RISE / S/4 Cloud:** use `https://<host>` on **443**, never `:44300`.
3. **Write tools are hidden** until `SAP_ALLOW_WRITES=true` (+ package/transport flags) is set inline.
4. **Some connections are read-only by design** — the write flags are simply never provided. Respect it.
5. **`edit_class_definition`** may be blocked by Claude Code's own permission classifier (not ARC-1);
   `add_method` / `edit_method` / `edit_method_signature` are not.
6. **Never** store the SAP password in a `.env` or commit `secrets/`.
7. `npm install -g arc-1` can fail with `ENETUNREACH` on VPN — retry with VPN off.
