#!/usr/bin/env bash
# ARC-1 multi-system helper (macOS / Linux, bash/zsh)
# Install: source it from your shell rc:   . "$HOME/.arc1/arc1env.sh"
#
# Layout:
#   ~/.arc1/
#     arc1env.sh          <- this file
#     systems/<sid>.env   <- connection only (URL, client, user, flags) — NEVER the password
#
# Password policy: this helper never writes the password to a file.
#   - If the OS keychain is available it can store/read it there (set_arc1_secret).
#   - Otherwise use_arc1 prompts once per shell session and keeps it only in $SAP_PASSWORD.

ARC1_ROOT="$HOME/.arc1"

arc1_systems() {
  # shellcheck disable=SC2012
  ls "$ARC1_ROOT/systems"/*.env 2>/dev/null \
    | sed 's#.*/##; s#\.env$##' \
    | grep -v '^_template$'
}

# Store the password in the OS keychain (macOS `security`, or Linux `secret-tool`).
set_arc1_secret() {
  local sys="$1"
  [ -z "$sys" ] && { echo "usage: set_arc1_secret <nickname>"; return 1; }
  local pw
  printf "SAP password for '%s': " "$sys" >&2
  read -rs pw; echo >&2
  if command -v security >/dev/null 2>&1; then          # macOS
    security add-generic-password -U -s "arc1-$sys" -a "$USER" -w "$pw" >/dev/null \
      && echo "Password for '$sys' stored in macOS keychain."
  elif command -v secret-tool >/dev/null 2>&1; then      # Linux + libsecret
    printf '%s' "$pw" | secret-tool store --label="arc1-$sys" service "arc1-$sys" account "$USER" \
      && echo "Password for '$sys' stored via secret-tool."
  else
    echo "No OS keychain tool found; use_arc1 will prompt each session instead." >&2
  fi
  unset pw
}

# Try to read a stored password from the OS keychain; prints it on stdout, empty if none.
_arc1_read_secret() {
  local sys="$1"
  if command -v security >/dev/null 2>&1; then
    security find-generic-password -s "arc1-$sys" -a "$USER" -w 2>/dev/null
  elif command -v secret-tool >/dev/null 2>&1; then
    secret-tool lookup service "arc1-$sys" account "$USER" 2>/dev/null
  fi
}

use_arc1() {
  local sys="$1"
  [ -z "$sys" ] && { echo "usage: use_arc1 <nickname>"; return 1; }
  local envfile="$ARC1_ROOT/systems/$sys.env"
  if [ ! -f "$envfile" ]; then
    echo "System '$sys' not found. Available: $(arc1_systems | tr '\n' ' ')" >&2
    return 1
  fi
  # clear any previous SAP_* so systems never bleed into each other
  while IFS= read -r name; do unset "$name"; done < <(env | grep -o '^SAP_[A-Z_]*' )
  # load the system's .env (skip comments/blank lines)
  set -a
  # shellcheck disable=SC1090
  while IFS='=' read -r k v; do
    case "$k" in ''|\#*) continue;; esac
    export "${k// /}=$(echo "$v" | sed 's/^ *//; s/ *$//')"
  done < "$envfile"
  set +a
  # load the password: keychain first, else prompt (session only)
  local pw; pw="$(_arc1_read_secret "$sys")"
  if [ -z "$pw" ]; then
    printf "SAP password for '%s' (session only): " "$sys" >&2
    read -rs pw; echo >&2
  fi
  export SAP_PASSWORD="$pw"; unset pw
  if [ -n "$SAP_PASSWORD" ]; then
    echo "ARC-1 -> '$sys'  ($SAP_URL, client $SAP_CLIENT)  [password OK]"
  else
    echo "ARC-1 -> '$sys'  ($SAP_URL, client $SAP_CLIENT)  [NO password]"
  fi
}
