#!/bin/bash

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
