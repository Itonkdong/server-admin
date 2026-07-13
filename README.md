# Server Setup Tools

Small, modular administration utility for Ubuntu 24.04+ GPU servers.

## Quick start on a new server

```bash
sudo apt update
sudo apt install -y git openssh-server openssh-client curl ufw
git clone https://github.com/itonkdong/server-setup-tools.git
cd server-admin
sudo ./install.sh
server-admin version
```
 Tailscale should be installed
and authenticated before using this tool in production.

## Installation

```bash
sudo ./install.sh
server-admin version
```

The installer copies the application to `/opt/server-admin` and creates
`/usr/local/bin/server-admin`. Update an existing installation with:

```bash
cd server-admin
git pull
sudo ./install.sh
```

## Usage

```text
server-admin add-user [--username NAME] [--sudo|--no-sudo] [--key FILE]
server-admin verify-user [NAME]
server-admin remove-user [NAME]
server-admin list-users
server-admin show-keys
server-admin doctor
server-admin info
```

`add-user` is interactive by default. A non-interactive example is:

```bash
sudo server-admin add-user --username firstname.lastname --sudo --key ~/Downloads/key.pub
```

## Commands

- `add-user` creates a public-key-only user, optionally grants sudo, and safely updates `AllowUsers`.
- `verify-user` checks the account, SSH files, effective `sshd -T` settings, and services.
- `remove-user` deletes an account and removes it from `AllowUsers`.
- `doctor` reports host health; `info` prints a concise inventory.

Create a user interactively:

```bash
sudo server-admin add-user
```

Or provide all inputs explicitly:

```bash
sudo server-admin add-user \
  --username firstname.lastname \
  --sudo \
  --key ~/.ssh/id_ed25519.pub
```

Use `--no-sudo` for a regular user. The command installs the key, updates
`AllowUsers`, validates SSH with `sshd -t`, and reloads SSH only after success.

Verify and inspect the server:

```bash
sudo server-admin verify-user firstname.lastname
sudo server-admin doctor
sudo server-admin info
```

Remove a user with confirmation:

```bash
sudo server-admin remove-user firstname.lastname
```

Example output:

```text
✔ Home directory
✔ SSH key installed
✔ Password auth disabled
PASS
```

## Troubleshooting and security

Run administration commands with `sudo`. SSH configuration is validated with `sshd -t` before reload; backups are written beside `/etc/ssh/sshd_config` when `AllowUsers` changes. The utility never parses included SSH configuration files and uses effective `sshd -T` output for verification. Review UFW rules and Tailscale ACLs independently before production use.

If the command is not found after installation, refresh the shell command cache:

```bash
hash -r
server-admin version
```

If SSH validation fails, the configuration is not reloaded. Inspect the error
with `sudo sshd -t`, correct the configuration, and retry the command.

## Project structure

`server-admin` dispatches commands; each command is implemented in `lib/`; `common.sh` contains shared validation and output helpers.

## License

MIT License. See the MIT license text at <https://opensource.org/license/mit/>.
