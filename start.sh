#!/bin/bash

set -ex

# Validate GITHUB_USERNAME - must be alphanumeric or hyphens, typical for GitHub usernames
if [[ -z "${GITHUB_USERNAME:-}" || ! "$GITHUB_USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: GITHUB_USERNAME environment variable is not set, empty, or contains illegal characters."
    exit 1
fi

# Validate EVERGREEN_USER - must be alphanumeric and underscores only (adjust regex as needed)
if [[ -z "${EVERGREEN_USER:-}" || ! "$EVERGREEN_USER" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "Error: EVERGREEN_USER environment variable is not set, empty, or contains illegal characters."
    exit 1
fi

# Validate EVERGREEN_PASS - allow alphanumeric and typical special characters, adjust as needed
if [[ -z "${EVERGREEN_PASS:-}" || ! "$EVERGREEN_PASS" =~ ^[a-zA-Z0-9@#%^+=_-]+$ ]]; then
    echo "Error: EVERGREEN_PASS environment variable is not set, empty, or contains illegal characters."
    exit 1
fi

# Set up user from env vars if they don't exist
if ! id "${EVERGREEN_USER}" >/dev/null 2>&1; then
    echo "Creating sudo user..."
    adduser -D "${EVERGREEN_USER}"
    echo "${EVERGREEN_USER}:${EVERGREEN_PASS}" | chpasswd
    adduser "${EVERGREEN_USER}" wheel
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
fi

# Install OpenSSH server if not installed and generate host keys
if ! command -v sshd >/dev/null 2>&1; then
    echo "Installing OpenSSH server..."
    apk add --no-cache openssh
    rc-update add sshd
    mkdir -p /etc/ssh
fi

# Generate SSH host keys if they are not present
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# Ensure SSH server is running
if ! pgrep -x "sshd" >/dev/null; then
    echo "Starting SSH server..."
    /usr/sbin/sshd
fi

# Set up user from env vars if they don't exist
if ! id "${EVERGREEN_USER}" >/dev/null 2>&1; then
    echo "Creating sudo user..."
    adduser -D "${EVERGREEN_USER}"
    echo "${EVERGREEN_USER}:${EVERGREEN_PASS}" | chpasswd
    adduser "${EVERGREEN_USER}" wheel
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
fi

# Fetch SSH keys from GitHub for user in GITHUB_USERNAME
AUTHORIZED_KEYS_PATH="/home/${EVERGREEN_USER}/.ssh/authorized_keys"
if [ ! -f "${AUTHORIZED_KEYS_PATH}" ]; then
    echo "Setting up SSH keys for ${EVERGREEN_USER}..."
    mkdir -p "/home/${EVERGREEN_USER}/.ssh"
    wget -O "${AUTHORIZED_KEYS_PATH}" "https://github.com/${GITHUB_USERNAME}.keys"
    chown -R "${EVERGREEN_USER}:${EVERGREEN_USER}" "/home/${EVERGREEN_USER}/.ssh"
    chmod 600 "${AUTHORIZED_KEYS_PATH}"
fi

echo "Setup complete. Container is ready."
exec "$@"
