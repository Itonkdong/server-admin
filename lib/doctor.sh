#!/usr/bin/env bash
set -Eeuo pipefail
doctor() {
  require_root
  local failed=0 ufw_rules
  section 'Server health'

  if grep -q 'Ubuntu' /etc/os-release; then pass 'Ubuntu'; else warn 'Ubuntu: not detected'; fi
  printf 'Kernel: %s\nHostname: %s\n' "$(uname -r)" "$(hostname)"

  echo 'Network interfaces:'
  ip -br addr show
  if curl -fsS --max-time 3 https://connectivitycheck.gstatic.com/generate_204 >/dev/null; then pass 'Internet connectivity'; else warn 'Internet connectivity'; fi

  if systemctl is-active --quiet ssh; then pass 'SSH service running'; else fail 'SSH service not running'; failed=1; fi
  if ss -ltnH '( sport = :22 )' | grep -q .; then pass 'Port 22 listening'; else fail 'Port 22 is not listening'; failed=1; fi
  if systemctl is-active --quiet tailscaled; then pass 'Tailscale service running'; else fail 'Tailscale service not running'; failed=1; fi
  if [[ -d /sys/class/net/tailscale0 ]]; then pass 'tailscale0 interface exists'; else fail 'tailscale0 interface missing'; failed=1; fi
  if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
    pass 'Tailscale status'; printf 'Tailscale IPv4: %s\n' "$(tailscale ip -4 2>/dev/null || echo unavailable)"
  else
    fail 'Tailscale status'; failed=1
  fi

  if command -v docker >/dev/null 2>&1; then pass "Docker: $(docker --version)"; else warn 'Docker unavailable'; fi
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then pass "Docker Compose: $(docker compose version --short 2>/dev/null || docker compose version)"; else warn 'Docker Compose unavailable'; fi

  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    pass 'NVIDIA driver'; printf 'GPU: %s\n' "$(nvidia-smi --query-gpu=name --format=csv,noheader | paste -sd ', ' -)"
    command -v nvcc >/dev/null 2>&1 && pass "CUDA: $(nvcc --version | awk -F'release ' '/release/ {print $2}' | awk -F, '{print $1}')" || warn 'CUDA compiler unavailable'
  else
    warn 'NVIDIA driver/GPU unavailable'
  fi

  echo 'Storage:'; df -h /
  echo 'Memory:'; free -h

  if command -v ufw >/dev/null 2>&1; then
    printf 'Firewall status: %s\n' "$(ufw status | head -1)"
    if ufw status | grep -q '^Status: active'; then
      pass 'UFW active'
      ufw_rules=$(ufw status | tail -n +4)
      if grep -Eiq '(^|[[:space:]])(22(/tcp)?|ssh)([[:space:]]|$).*tailscale0|tailscale0.*(22(/tcp)?|ssh)' <<<"$ufw_rules"; then
        pass 'SSH firewall rule references tailscale0'
      else
        warn 'Could not confirm an SSH-only tailscale0 rule'
      fi
      echo 'Firewall rules:'; [[ -n $ufw_rules ]] && printf '%s\n' "$ufw_rules" || echo '(none)'
    else
      warn 'UFW inactive'; failed=1
    fi
  else
    warn 'UFW unavailable'
  fi

  (( failed == 0 )) && pass 'Overall health checks passed' || { fail 'One or more critical checks failed'; return 1; }
}
