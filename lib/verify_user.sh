#!/usr/bin/env bash
set -Eeuo pipefail

verify_one() {
  local u=$1 h f shell cfg bad=0 groups
  user_exists "$u" || { fail "$u: user does not exist"; return 1; }
  h=$(getent passwd "$u" | cut -d: -f6)
  shell=$(getent passwd "$u" | cut -d: -f7)
  f="$h/.ssh/authorized_keys"
  groups=$(id -nG "$u")

  echo "Verifying $u"
  [[ -n $shell && -x $shell ]] && pass "Login shell: $shell" || { fail 'Login shell invalid'; bad=1; }
  if grep -qw sudo <<<"$groups"; then pass 'Sudo membership'; else pass 'Sudo membership: no'; fi
  if getent group docker >/dev/null 2>&1; then
    grep -qw docker <<<"$groups" && pass 'Docker group membership' || { fail 'Docker group membership missing'; bad=1; }
  else
    warn 'Docker group unavailable'
  fi
  [[ -d $h ]] && pass 'Home directory' || { fail 'Home directory'; bad=1; }
  [[ -d $h/.ssh && $(stat -c %a "$h/.ssh") == 700 ]] && pass 'SSH directory' || { fail 'SSH directory permissions'; bad=1; }
  [[ -s $f && $(stat -c %a "$f") == 600 ]] && ssh-keygen -lf "$f" >/dev/null 2>&1 && pass 'SSH key installed' || { fail 'SSH key invalid or permissions wrong'; bad=1; }
  allow_user "$u" && pass 'User allowed' || { fail 'User not allowed'; bad=1; }

  cfg=$(effective)
  for setting in 'passwordauthentication no' 'pubkeyauthentication yes' 'permitrootlogin no'; do
    grep -qi "^$setting$" <<<"$cfg" && pass "$setting" || { fail "$setting"; bad=1; }
  done
  grep -q '^allowtcpforwarding ' <<<"$cfg" && pass 'SSH forwarding configured' || { fail 'SSH forwarding setting missing'; bad=1; }
  systemctl is-active --quiet ssh && pass 'SSH running' || { fail 'SSH not running'; bad=1; }
  systemctl is-active --quiet tailscaled && pass 'Tailscale running' || { fail 'Tailscale not running'; bad=1; }
  ((bad==0)) && { echo 'PASS'; return 0; }
  echo 'FAIL'
  return 1
}

verify_user() {
  require_root
  local u=${1:-} result=0
  if [[ $u == --all ]]; then
    while IFS=: read -r u _ uid _ _ _ _; do
      ((uid>=1000 && uid<60000)) || continue
      verify_one "$u" || result=1
      echo
    done < /etc/passwd
    return "$result"
  fi
  [[ -n $u ]] || read -r -p 'Username: ' u
  verify_one "$u"
}
