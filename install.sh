#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run: sudo ./install.sh' >&2; exit 1; }
src=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); install -d -m 755 /opt/server-admin /opt/server-admin/lib
cp -a "$src/server-admin" "$src/README.md" /opt/server-admin/
cp -a "$src/lib/." /opt/server-admin/lib/
chmod 755 /opt/server-admin/server-admin; chmod 755 /opt/server-admin/lib/*.sh
ln -sfn /opt/server-admin/server-admin /usr/local/bin/server-admin
echo 'Installed server-admin to /usr/local/bin/server-admin'
