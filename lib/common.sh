#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP_VERSION="1.0.0"
readonly APP_ROOT="${SERVER_ADMIN_ROOT:-/opt/server-admin}"
readonly SSH_CONFIG="/etc/ssh/sshd_config"
readonly C_RESET=$'\033[0m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_BLUE=$'\033[34m'
pass() { printf '%s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s⚠%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
fail() { printf '%s✖%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
section() { printf '\n%s== %s ==%s\n' "$C_BLUE" "$*" "$C_RESET"; }
die() { fail "$*"; exit 1; }
require_root() { [[ $EUID -eq 0 ]] || die 'This command must be run as root (use sudo).'; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
yes_no() { local answer; read -r -p "$1 [Y/n] " answer || return 1; [[ -z $answer || $answer =~ ^[Yy]([Ee][Ss])?$ ]]; }
user_exists() { id "$1" >/dev/null 2>&1; }
authorized_file() { printf '%s/.ssh/authorized_keys' "$(getent passwd "$1" | cut -d: -f6)"; }
key_is_valid() { [[ $1 =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-[^[:space:]]+|sk-ssh-ed25519[^[:space:]]*)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$ ]]; }
effective() { sshd -T 2>/dev/null; }
allow_user() { effective | awk -v u="$1" '$1=="allowusers" && $2==u { found=1 } END { exit !found }'; }
ssh_update_allowusers() {
  local user=$1 tmp backup line found=0
  tmp=$(mktemp); backup="${SSH_CONFIG}.server-admin.$(date +%Y%m%d%H%M%S).bak"
  cp -a "$SSH_CONFIG" "$backup"
  while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*AllowUsers([[:space:]]|$) ]]; then
      [[ $line =~ (^|[[:space:]])$user($|[[:space:]]) ]] && found=1
      [[ $line =~ ^[[:space:]]*# ]] || line="$line $user"
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$SSH_CONFIG"
  if (( ! found )); then printf '\nAllowUsers %s\n' "$user" >> "$tmp"; fi
  install -m 0644 "$tmp" "$SSH_CONFIG"; rm -f "$tmp"
  if ! sshd -t; then cp -a "$backup" "$SSH_CONFIG"; rm -f "$backup"; return 1; fi
  systemctl reload ssh
}
ssh_remove_allowuser() {
  local user=$1 tmp line
  tmp=$(mktemp)
  while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*AllowUsers[[:space:]] ]]; then
      line=$(awk -v u="$user" '{ printf "%s", $1; for(i=2;i<=NF;i++) if($i!=u) printf " %s",$i; print "" }' <<<"$line")
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$SSH_CONFIG"
  install -m 0644 "$tmp" "$SSH_CONFIG"; rm -f "$tmp"
  sshd -t || die 'SSH configuration became invalid; restore the latest server-admin backup.'
  systemctl reload ssh
}
print_result() { if "$@"; then pass "$1"; return 0; else fail "$1"; return 1; fi; }
