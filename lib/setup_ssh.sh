#!/usr/bin/env bash
set -Eeuo pipefail

ssh_setup_as_user() {
  local target=$1
  shift
  if [[ $EUID -eq 0 && $target != "$(id -un)" ]]; then
    runuser -u "$target" -- "$@"
  else
    "$@"
  fi
}

setup_ssh() {
  require_command ssh
  require_command ssh-keygen

  local target='' host='' remote_user='' host_alias='' port=''
  local key_name='' comment='' no_passphrase=0
  local home primary_group ssh_dir config_dir config_file host_file key_path safe_alias
  local generated=0 answer

  while (($#)); do
    case "$1" in
      --user) target=${2:?Missing value for --user}; shift 2 ;;
      --host) host=${2:?Missing value for --host}; shift 2 ;;
      --remote-user) remote_user=${2:?Missing value for --remote-user}; shift 2 ;;
      --alias) host_alias=${2:?Missing value for --alias}; shift 2 ;;
      --port) port=${2:?Missing value for --port}; shift 2 ;;
      --key-name) key_name=${2:?Missing value for --key-name}; shift 2 ;;
      --comment) comment=${2:?Missing value for --comment}; shift 2 ;;
      --no-passphrase) no_passphrase=1; shift ;;
      -h|--help)
        cat <<'EOF'
Usage: server-admin setup-ssh [options]

Options:
  --user USER          Local Linux account to configure (default: invoking user)
  --host HOST          Remote hostname or IP address
  --remote-user USER   Username on the remote host (default: local username)
  --alias ALIAS        Name used with the ssh command (default: HOST)
  --port PORT          Remote SSH port (default: 22)
  --key-name NAME      Key filename inside ~/.ssh (default: id_ed25519)
  --comment TEXT       Public-key comment (default: LOCAL_USER@HOST)
  --no-passphrase      Generate a key without prompting for a passphrase
EOF
        return 0
        ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  if [[ -z $target ]]; then
    if [[ -n ${SUDO_USER:-} && ${SUDO_USER} != root ]]; then
      target=$SUDO_USER
    elif [[ $EUID -ne 0 ]]; then
      target=$(id -un)
    else
      read -r -p 'Local Linux username: ' target
    fi
  fi
  user_exists "$target" || die "Linux user does not exist: $target"

  if [[ -z $host ]]; then read -r -p 'Remote SSH host: ' host; fi
  [[ $host =~ ^[A-Za-z0-9._:-]+$ && $host != -* ]] || die 'Invalid remote hostname or IP address.'

  if [[ -z $remote_user ]]; then
    read -r -p "Remote SSH username [$target]: " answer
    remote_user=${answer:-$target}
  fi
  [[ $remote_user =~ ^[A-Za-z0-9._-]+$ && $remote_user != -* ]] || die 'Invalid remote SSH username.'

  if [[ -z $host_alias ]]; then
    read -r -p "SSH host alias [$host]: " answer
    host_alias=${answer:-$host}
  fi
  [[ $host_alias =~ ^[A-Za-z0-9._-]+$ && $host_alias != -* ]] || die 'Invalid SSH host alias.'

  if [[ -z $port ]]; then
    read -r -p 'SSH port [22]: ' answer
    port=${answer:-22}
  fi
  [[ $port =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)) || die 'SSH port must be between 1 and 65535.'

  if [[ -z $key_name ]]; then
    read -r -p 'SSH key name [id_ed25519]: ' answer
    key_name=${answer:-id_ed25519}
  fi
  [[ $key_name =~ ^[A-Za-z0-9._-]+$ && $key_name != .* ]] || die 'Key name must be a safe filename without a path.'

  home=$(getent passwd "$target" | cut -d: -f6)
  primary_group=$(id -gn "$target")
  [[ -n $home && -d $home ]] || die "Home directory is unavailable for $target."
  ssh_dir="$home/.ssh"
  config_dir="$ssh_dir/config.d"
  config_file="$ssh_dir/config"
  key_path="$ssh_dir/$key_name"
  safe_alias=${host_alias//./-}; safe_alias=${safe_alias//:/-}
  host_file="$config_dir/server-admin-$safe_alias.conf"
  comment=${comment:-$target@$host}

  [[ ! -L $ssh_dir && ! -L $config_dir ]] || die 'Refusing to use a symlinked SSH configuration directory.'
  [[ ! -L $config_file && ! -L $host_file ]] || die 'Refusing to modify a symlinked SSH configuration file.'
  [[ ! -L $key_path && ! -L $key_path.pub ]] || die 'Refusing to use a symlinked SSH key path.'
  install -d -m 700 -o "$target" -g "$primary_group" "$ssh_dir" "$config_dir"

  if [[ -e $key_path || -e $key_path.pub ]]; then
    [[ -f $key_path && -f $key_path.pub ]] || die "Incomplete key pair exists for $key_path; no files were changed."
    warn "Using existing SSH key: $key_path"
  else
    if (( no_passphrase )); then
      ssh_setup_as_user "$target" ssh-keygen -t ed25519 -f "$key_path" -C "$comment" -N ''
    else
      ssh_setup_as_user "$target" ssh-keygen -t ed25519 -f "$key_path" -C "$comment"
    fi
    generated=1
  fi

  chmod 600 "$key_path"; chmod 644 "$key_path.pub"
  chown "$target:$primary_group" "$key_path" "$key_path.pub"

  if [[ -f $config_file ]] && ! grep -Eq '^[[:space:]]*Include[[:space:]]+~/.ssh/config.d/\*([[:space:]]|$)' "$config_file"; then
    local config_tmp
    config_tmp=$(mktemp)
    printf 'Include ~/.ssh/config.d/*\n\n' > "$config_tmp"
    cat "$config_file" >> "$config_tmp"
    install -m 600 -o "$target" -g "$primary_group" "$config_tmp" "$config_file"
    rm -f "$config_tmp"
  elif [[ ! -e $config_file ]]; then
    printf 'Include ~/.ssh/config.d/*\n' > "$config_file"
    chown "$target:$primary_group" "$config_file"; chmod 600 "$config_file"
  fi

  local host_tmp
  host_tmp=$(mktemp)
  cat > "$host_tmp" <<EOF
Host $host_alias
    HostName $host
    User $remote_user
    Port $port
    IdentityFile ~/.ssh/$key_name
    IdentitiesOnly yes
EOF
  install -m 600 -o "$target" -g "$primary_group" "$host_tmp" "$host_file"
  rm -f "$host_tmp"
  chmod 700 "$ssh_dir" "$config_dir"; chmod 600 "$config_file" "$host_file"

  ssh_setup_as_user "$target" ssh -G "$host_alias" >/dev/null || die 'Generated SSH client configuration is invalid.'

  (( generated )) && pass "Generated SSH key: $key_path" || pass "SSH key ready: $key_path"
  pass "Configured SSH host: $host_alias ($remote_user@$host:$port)"
  pass "Ownership and permissions set for $target"
  section 'Public key'
  printf '%s\n' "$(<"$key_path.pub")"
  section 'Next steps'
  printf '1. Add the public key above to the remote account or service.\n'
  printf '2. For a Linux host, add it to ~%s/.ssh/authorized_keys.\n' "$remote_user"
  printf '3. Test the configured connection: ssh %s\n' "$host_alias"
}
