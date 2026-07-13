#!/usr/bin/env bash
set -Eeuo pipefail
list_users() { printf '%-25s %-7s %-5s %s\n' USER UID SUDO SHELL; while IFS=: read -r u _ uid _ _ _ shell; do ((uid>=1000 && uid<60000)) || continue; groups "$u" 2>/dev/null|grep -qw sudo && s=yes || s=no; printf '%-25s %-7s %-5s %s\n' "$u" "$uid" "$s" "$shell"; done < /etc/passwd; }
