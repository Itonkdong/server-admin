#!/usr/bin/env bash
set -Eeuo pipefail
show_keys() { while IFS=: read -r u _ uid _ _ h _; do ((uid>=1000 && uid<60000)) || continue; f="$h/.ssh/authorized_keys"; echo "$u"; [[ -r $f ]] || { echo '  0 keys'; continue; }; n=$(grep -cE '^(ssh-|ecdsa-|sk-)' "$f" || true); echo "  $n keys"; ssh-keygen -lf "$f" 2>/dev/null | sed 's/^/  /' || true; done < /etc/passwd; }
