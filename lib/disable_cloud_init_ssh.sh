#!/usr/bin/env bash
set -Eeuo pipefail

disable_cloud_init_ssh() {
  require_root
  require_command sshd

  local config='/etc/ssh/sshd_config.d/50-cloud-init.conf'
  local disabled="${config}.disabled"

  if [[ ! -e $config ]]; then
    if [[ -e $disabled ]]; then
      pass 'Cloud-init SSH configuration is already disabled'
    else
      pass 'Cloud-init SSH configuration is not present'
    fi
    return 0
  fi

  [[ -f $config ]] || die "$config exists but is not a regular file."
  [[ ! -e $disabled ]] || die "Refusing to overwrite existing file: $disabled"

  # Validate the current configuration before making any change.
  sshd -t || die 'Current SSH configuration is invalid; no change was made.'
  mv -- "$config" "$disabled"

  if ! sshd -t; then
    mv -- "$disabled" "$config"
    fail 'SSH configuration became invalid; the cloud-init file was restored.'
    return 1
  fi

  systemctl reload ssh
  pass "Disabled $config"
  pass 'SSH configuration validated and reloaded'
}
