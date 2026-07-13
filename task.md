# Server Admin Utility

## Overview

Implement a production-quality Bash utility called `server-admin` for administering Ubuntu Server (24.04+) machines used as GPU servers.

The goal is to automate repetitive Linux administration tasks that are currently performed manually when provisioning new servers and users.

The utility should be modular, maintainable, well documented, and safe to run on production machines.

---

# Environment

The servers have the following characteristics:

- Ubuntu Server 24.04 LTS
- OpenSSH
- Tailscale
- UFW
- Docker (future)
- NVIDIA GPU (future)
- Users authenticate exclusively with SSH public keys.
- Password SSH authentication is disabled.
- Root login is disabled.
- Only Tailscale clients can SSH into the server.

The SSH configuration already contains:

```text
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no

AllowUsers ...
```

Users are allowed through the `AllowUsers` directive.

---

# Project Structure

```
server-admin/
│
├── install.sh
├── server-admin
├── README.md
│
└── lib/
    ├── common.sh
    ├── add_user.sh
    ├── verify_user.sh
    ├── remove_user.sh
    ├── list_users.sh
    ├── show_keys.sh
    ├── doctor.sh
    └── info.sh
```

Every command should live inside its own module.

The root executable should simply dispatch commands.

---

# Bash Requirements

Use

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

Every script must use:

- proper exit codes
- functions
- error handling
- readable code
- comments

Do NOT write one giant script.

---

# Install Script

Running

```bash
sudo ./install.sh
```

should

- create

```
/opt/server-admin
```

- copy all project files

- install executable

```
/usr/local/bin/server-admin
```

After installation the following commands should work globally:

```bash
sudo server-admin add-user
sudo server-admin verify-user
sudo server-admin doctor
```

---

# Command Dispatcher

The executable

```
server-admin
```

must dispatch subcommands like

```bash
server-admin add-user

server-admin verify-user

server-admin remove-user

server-admin doctor

server-admin list-users

server-admin show-keys

server-admin info
```

Also support

```bash
server-admin help
```

and

```bash
server-admin version
```

---

# Common Library

Implement common reusable functions.

Examples

- colored output
- pass()
- warn()
- fail()
- die()
- section()
- require_root()
- require_command()
- ask_yes_no()
- etc.

Avoid duplicated code.

---

# add-user

Interactive command.

Workflow:

Prompt

```
Username:
```

Create the Linux user using

```
adduser --allow-bad-names
```

Allow usernames like

```
firstname.lastname
```

The normal Ubuntu password prompt should appear.

Then ask

```
Administrator (sudo privileges)? [Y/n]
```

If yes

```
usermod -aG sudo
```

Otherwise create a normal user.

Then prompt

```
Paste SSH public key:
```

The script must validate that it looks like an SSH key.

Supported key types

- ssh-ed25519
- ssh-rsa
- ecdsa
- sk-ssh-ed25519

Create

```
~/.ssh
```

Create

```
authorized_keys
```

Install key.

Correct permissions

```
700 .ssh

600 authorized_keys
```

Correct ownership

```
username:username
```

Update

```
AllowUsers
```

in

```
/etc/ssh/sshd_config
```

If the user already exists inside AllowUsers

do nothing.

Otherwise append him.

Validate

```
sshd -t
```

Reload ssh

```
systemctl reload ssh
```

Never restart if validation fails.

Print a nice summary.

---

# verify-user

Usage

```bash
sudo server-admin verify-user

or

sudo server-admin verify-user viktor.kostadinoski
```

Prompt if username missing.

Checks

## User

- exists
- login shell
- sudo membership

## Home

- exists
- owner
- permissions

## SSH

- .ssh exists
- .ssh permissions = 700
- authorized_keys exists
- authorized_keys permissions = 600
- ownership
- contains at least one key
- keys parsable with

```
ssh-keygen -lf
```

## SSH Configuration

Use ONLY

```
sshd -T
```

Never parse sshd_config manually.

Verify

- PasswordAuthentication
- PubkeyAuthentication
- PermitRootLogin
- AllowTcpForwarding
- AllowUsers

IMPORTANT

Ubuntu outputs

```
allowusers user1
allowusers user2
allowusers user3
```

NOT

```
allowusers user1 user2 user3
```

Support this correctly.

Also support

```
sshd_config.d
```

Do NOT parse files.

Use

```
sshd -T
```

because it returns the effective configuration.

---

## Services

Verify

- ssh
- tailscaled

Verify port 22 listening.

---

## Firewall

Verify

UFW active

Verify

incoming SSH is ONLY allowed over tailscale0.

No unrestricted SSH rules.

---

## Tailscale

Verify

tailscaled running

tailscale0 exists

tailscale status succeeds

Print Tailscale IP.

---

Produce output like

```
=============================

Verifying

viktor.kostadinoski

=============================

✔ User exists

✔ Home directory

✔ SSH key installed

✔ Password auth disabled

✔ Root login disabled

✔ User allowed

✔ SSH running

✔ Tailscale running

✔ Firewall configured

=============================

PASS

=============================
```

---

# remove-user

Prompt

```
Username:
```

Confirm deletion.

Ask

```
Delete home directory?

[Y/n]
```

Remove user.

Remove from AllowUsers.

Reload SSH.

---

# list-users

List

```
username

uid

sudo

shell
```

Display as table.

---

# show-keys

For every user

Show

```
username

number of keys

fingerprints
```

Use

```
ssh-keygen -lf
```

---

# doctor

Check entire server.

Ubuntu version

Kernel

Hostname

IP

Tailscale IP

Internet

SSH

Docker

Docker Compose

NVIDIA driver

CUDA

nvidia-smi

Disk

RAM

GPU

tailscaled

UFW

Print green PASS / yellow WARN / red FAIL.

This becomes the server health check.

---

# info

Display

Hostname

OS

Kernel

CPU

Memory

Disk

GPU

Docker

SSH

Tailscale

UFW

Current users

---

# Non-interactive Mode

Support

```bash
server-admin add-user \
    --username viktor.kostadinoski \
    --sudo \
    --key ~/Downloads/key.pub
```

Also

```bash
--no-sudo
```

---

# Coding Style

Requirements

- Production quality
- Modular
- Bash best practices
- No duplicated code
- Clear comments
- Consistent formatting
- Safe defaults
- Idempotent where possible
- Validate before changing system configuration
- Never restart ssh if validation fails
- Meaningful exit codes

---

# README

Write a complete README including

Installation

Usage

Examples

Command descriptions

Screenshots/examples of output

Troubleshooting

Security notes

Project structure

License (MIT)

---

# Goal

The final result should feel like a small professional Linux administration CLI tool that can be installed on every Ubuntu GPU server and used for provisioning users, verifying SSH configuration, and monitoring server health.