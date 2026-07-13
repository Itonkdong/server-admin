# Server Setup Tools

Small, modular administration utility for Ubuntu 24.04+ GPU servers.

## Quick start on a new server

```bash
sudo apt update
sudo apt install -y git openssh-server openssh-client curl ufw
git clone https://github.com/itonkdong/server-setup-tools.git
cd server-setup-tools
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
cd server-setup-tools
git pull
sudo ./install.sh
```

## Usage

```text
server-admin add-user [--username NAME] [--sudo|--no-sudo] [--key FILE]
server-admin disable-cloud-init-ssh
server-admin verify-user [NAME]
server-admin verify-user --all
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

- `add-user` creates a public-key-only user, optionally grants sudo, installs the supplied public key, and safely updates `AllowUsers`.
- `disable-cloud-init-ssh` disables `/etc/ssh/sshd_config.d/50-cloud-init.conf` when present, so cloud-init does not override SSH policy.
- `verify-user [NAME]` checks one account, its SSH files, effective `sshd -T` settings, and required services.
- `verify-user --all` performs the same verification for every regular user (UID 1000–59999).
- `remove-user [NAME]` confirms deletion, optionally removes the home directory, and removes the account from `AllowUsers`.
- `list-users` displays regular usernames, UIDs, sudo membership, and login shells in a table.
- `show-keys` displays each regular user’s authorized-key count and fingerprints using `ssh-keygen -lf`.
- `doctor` checks Ubuntu, networking, internet access, SSH, port 22, Tailscale, Docker, CUDA/NVIDIA, storage, memory, and UFW.
- `info` displays a labeled server inventory including OS, kernel, CPU, memory, disk, GPU, Docker, SSH, Tailscale, UFW, and users.
- `help` displays the command summary; `version` displays the installed server-admin version.

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
