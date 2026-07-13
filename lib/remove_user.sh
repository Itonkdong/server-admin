#!/usr/bin/env bash
set -Eeuo pipefail
remove_user() { require_root; local u=${1:-}; [[ -n $u ]] || read -r -p 'Username: ' u; user_exists "$u" || die 'User does not exist'; yes_no "Delete $u?" || exit 0; local del=''; yes_no 'Delete home directory?' && del=--remove-home || true; userdel ${del:-} "$u"; ssh_remove_allowuser "$u"; pass "Removed $u"; }
