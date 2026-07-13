#!/usr/bin/env bash
set -Eeuo pipefail
info() {
  section 'Server information'
  printf 'Hostname: %s\nOS: %s\nKernel: %s\nCPU: %s cores\nMemory: %s\n' \
    "$(hostname)" "$(. /etc/os-release; echo "$PRETTY_NAME")" "$(uname -r)" \
    "$(nproc)" "$(free -h | awk '/Mem:/ {print $2}')"

  echo 'Disk:'
  df -h /

  if command -v nvidia-smi >/dev/null 2>&1; then
    echo 'GPU:'
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
    if command -v nvcc >/dev/null 2>&1; then
      echo "CUDA: $(nvcc --version | awk -F'release ' '/release/ {print $2}' | awk -F, '{print $1}')"
    else
      echo 'CUDA: compiler unavailable'
    fi
  else
    echo 'GPU: unavailable'
  fi

  if command -v docker >/dev/null 2>&1; then
    echo "Docker: $(docker --version)"
  else
    echo 'Docker: unavailable'
  fi
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "Docker Compose: $(docker compose version --short 2>/dev/null || docker compose version)"
  else
    echo 'Docker Compose: unavailable'
  fi

  printf 'SSH service: %s\n' "$(systemctl is-active ssh 2>/dev/null || echo unavailable)"
  printf 'Tailscale service: %s\n' "$(systemctl is-active tailscaled 2>/dev/null || echo unavailable)"
  if command -v tailscale >/dev/null 2>&1; then
    printf 'Tailscale IP: %s\n' "$(tailscale ip -4 2>/dev/null || echo unavailable)"
  else
    echo 'Tailscale IP: unavailable'
  fi
  if command -v ufw >/dev/null 2>&1; then
    printf 'UFW: %s\n' "$(ufw status 2>/dev/null | head -1)"
  else
    echo 'UFW: unavailable'
  fi

  echo 'Users:'
  source "$SERVER_ADMIN_ROOT/lib/list_users.sh"
  list_users
}
