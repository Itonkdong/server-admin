#!/usr/bin/env bash
set -Eeuo pipefail

create_shared_project() {
  local name='' group='' path='' raw_users='' answer user existing duplicate
  local -a requested_users=() users=() parsed_users=()

  while (($#)); do
    case "$1" in
      --name) name=${2:?Missing value for --name}; shift 2 ;;
      --group) group=${2:?Missing value for --group}; shift 2 ;;
      --path) path=${2:?Missing value for --path}; shift 2 ;;
      --user) requested_users+=("${2:?Missing value for --user}"); shift 2 ;;
      --users)
        raw_users=${2:?Missing value for --users}
        raw_users=${raw_users//,/ }
        read -r -a parsed_users <<< "$raw_users"
        requested_users+=("${parsed_users[@]}")
        shift 2
        ;;
      -h|--help)
        cat <<'EOF'
Usage: sudo server-admin create-shared-project [options]

Options:
  --name NAME          Project name
  --group GROUP        Shared Linux group (default: project name)
  --path PATH          Shared directory (default: /srv/projects/NAME)
  --user USER          Add a user; may be specified multiple times
  --users LIST         Comma- or space-separated list of users
EOF
        return 0
        ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  require_root
  require_command groupadd
  require_command usermod
  command -v setfacl >/dev/null 2>&1 ||
    die 'setfacl is required. Install it with: sudo apt install acl'

  if [[ -z $name ]]; then read -r -p 'Project name: ' name; fi
  [[ $name =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || die 'Project name contains unsupported characters.'

  if [[ -z $group ]]; then
    read -r -p "Linux group [$name]: " answer
    group=${answer:-$name}
  fi
  [[ $group =~ ^[a-z_][a-z0-9_-]*$ && ${#group} -le 32 ]] || die 'Group must be a valid Linux group name of at most 32 characters.'

  if [[ -z $path ]]; then
    read -r -p "Shared directory [/srv/projects/$name]: " answer
    path=${answer:-/srv/projects/$name}
  fi
  [[ $path == /* && $path != / ]] || die 'Shared directory must be an absolute path other than /.'
  [[ ! -L $path ]] || die 'Refusing to modify a symlinked shared directory.'

  if ((${#requested_users[@]} == 0)); then
    read -r -p 'Users (comma- or space-separated): ' raw_users
    raw_users=${raw_users//,/ }
    read -r -a requested_users <<< "$raw_users"
  fi

  for user in "${requested_users[@]}"; do
    [[ -n $user ]] || continue
    duplicate=0
    for existing in "${users[@]}"; do
      [[ $existing == "$user" ]] && duplicate=1
    done
    (( duplicate )) && continue
    user_exists "$user" || die "Linux user does not exist: $user"
    users+=("$user")
  done
  ((${#users[@]} >= 2)) || die 'A shared project requires at least two existing users.'

  if getent group "$group" >/dev/null 2>&1; then
    pass "Using existing group: $group"
  else
    groupadd "$group"
    pass "Created group: $group"
  fi

  for user in "${users[@]}"; do
    usermod -aG "$group" "$user"
    pass "Added $user to $group"
  done

  install -d -m 2770 -o root -g "$group" "$path"
  chgrp -R "$group" "$path"
  chmod -R g+rwX,o-rwx "$path"
  find "$path" -type d -exec chmod g+s {} +

  # Apply access ACLs to existing content and inheritable ACLs to directories.
  setfacl -R -m "g:$group:rwX,m::rwX,o::---" "$path"
  find "$path" -type d -exec setfacl -m \
    "d:u::rwx,d:g::rwx,d:g:$group:rwx,d:m::rwx,d:o::---" {} +

  section 'Shared project ready'
  printf 'Name: %s\nGroup: %s\nDirectory: %s\nUsers: %s\n' \
    "$name" "$group" "$path" "${users[*]}"
  pass 'Setgid group inheritance enabled'
  pass 'Default read/write ACLs enabled'
  warn 'Users must log out and reconnect before new group membership is active.'
}
