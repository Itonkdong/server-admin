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
  ssh_rewrite_allowusers add "$1"
}
ssh_remove_allowuser() {
  ssh_rewrite_allowusers remove "$1"
}
ssh_rewrite_allowusers() {
  local action=$1 user=$2 tmp backup line token
  local -a users=() parts=()
  declare -A seen=()
  tmp=$(mktemp); backup="${SSH_CONFIG}.server-admin.$(date +%Y%m%d%H%M%S).bak"
  cp -a "$SSH_CONFIG" "$backup"

  while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*AllowUsers([[:space:]]|$) ]]; then
      read -r -a parts <<< "$line"
      for token in "${parts[@]:1}"; do
        [[ -n ${seen[$token]+x} ]] || { users+=("$token"); seen[$token]=1; }
      done
      continue
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$SSH_CONFIG"

  if [[ $action == add && -z ${seen[$user]+x} ]]; then users+=("$user"); fi
  if [[ $action == remove ]]; then
    local -a remaining=()
    for token in "${users[@]}"; do [[ $token != "$user" ]] && remaining+=("$token"); done
    users=("${remaining[@]}")
  fi
  ((${#users[@]})) && printf '\nAllowUsers %s\n' "${users[*]}" >> "$tmp"

  install -m 0644 "$tmp" "$SSH_CONFIG"; rm -f "$tmp"
  if ! sshd -t; then cp -a "$backup" "$SSH_CONFIG"; rm -f "$backup"; return 1; fi
  systemctl reload ssh
}
print_result() { if "$@"; then pass "$1"; return 0; else fail "$1"; return 1; fi; }
