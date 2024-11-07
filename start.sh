#!/bin/bash

# Check if necessary environment variables are set
if [[ -z "$GITHUB_USERNAME" ]]; then
    echo "Error: GITHUB_USERNAME environment variable is not set."
    exit 1
fi

if [[ -z "$EVERGREEN_USER" ]]; then
    echo "Error: EVERGREEN_USER environment variable is not set."
    exit 1
fi

if [[ -z "$EVERGREEN_PASS" ]]; then
    echo "Error: EVERGREEN_PASS environment variable is not set."
    exit 1
fi

# Check for and install openssh if not installed
if ! command -v sshd >/dev/null 2>&1; then
    echo "Installing OpenSSH server..."
    apk add --no-cache openssh
    rc-update add sshd
    mkdir -p /etc/ssh
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

# Install Python 3 if not installed
if ! command -v python3 >/dev/null 2>&1; then
    echo "Installing Python 3..."
    apk add --no-cache python3
fi

echo "Setup complete. Container is ready."
exec "$@"
