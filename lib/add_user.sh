#!/usr/bin/env bash
set -Eeuo pipefail
add_user() {
 require_root; local username='' sudo_mode='' key_file='' key
 while (($#)); do case "$1" in --username) username=${2:?Missing username}; shift 2;; --sudo) sudo_mode=1; shift;; --no-sudo) sudo_mode=0; shift;; --key) key_file=${2:?Missing key file}; shift 2;; *) die "Unknown option: $1";; esac; done
 [[ -n $username ]] || read -r -p 'Username: ' username
 [[ $username =~ ^[a-zA-Z0-9._-]+$ ]] || die 'Invalid username.'
 user_exists "$username" && die "User already exists: $username"
 adduser --allow-bad-names "$username" || die 'User creation failed.'
 if [[ -n $key_file ]]; then [[ -r $key_file ]] || die "Cannot read key file: $key_file"; key=$(<"$key_file"); else
   read -r -p 'Paste SSH public key: ' key
 fi
 [[ -n ${sudo_mode:-} ]] || { yes_no 'Administrator (sudo privileges)?' && sudo_mode=1 || sudo_mode=0; }
 key_is_valid "$key" || die 'The supplied value does not look like a supported SSH public key.'
 (( sudo_mode )) && usermod -aG sudo "$username"
 if getent group docker >/dev/null 2>&1; then
   usermod -aG docker "$username"
   docker_access=1
 else
   docker_access=0
   warn 'Docker group is unavailable; user was not added to Docker access.'
 fi
 local home; home=$(getent passwd "$username" | cut -d: -f6); install -d -m 700 -o "$username" -g "$username" "$home/.ssh"
 printf '%s\n' "$key" > "$home/.ssh/authorized_keys"; chown "$username:$username" "$home/.ssh/authorized_keys"; chmod 600 "$home/.ssh/authorized_keys"
 ssh_update_allowusers "$username" || die 'SSH configuration validation failed; no reload was performed.'
 pass "Created $username"; (( sudo_mode )) && pass 'Sudo privileges: yes' || pass 'Sudo privileges: no'; pass 'SSH key installed and user allowed'
 (( docker_access )) && pass 'Docker group access: yes' || warn 'Docker group access: no'
}
