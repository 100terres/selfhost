#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this installer using sudo: sudo ./install.sh"
  exit 1
fi

TEMPLATE_FILE="selfhost-ipc-worker.service.template"
TARGET_SERVICE="/etc/systemd/system/selfhost-ipc-worker.service"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_USER=${SUDO_USER:-$USER}
IPC_DATA_DIR="/var/lib/selfhost-ipc-worker"

if [ ! -f "$CURRENT_DIR/$TEMPLATE_FILE" ]; then
  echo "Error: Template file '$TEMPLATE_FILE' missing from this folder."
  exit 1
fi

echo "[1/3] Creating ipc directory..."
mkdir -p "$IPC_DATA_DIR"
chown -R "$REAL_USER":"$REAL_USER" "$IPC_DATA_DIR"

echo "[2/3] Generating service file from template..."
sed -e "s|{{WORKING_DIR}}|$CURRENT_DIR|g" \
    -e "s|{{USER}}|$REAL_USER|g" \
    "$CURRENT_DIR/$TEMPLATE_FILE" > "$TARGET_SERVICE"

echo "[3/3] Activating service..."
systemctl daemon-reload
systemctl enable selfhost-ipc-worker.service
systemctl restart selfhost-ipc-worker.service

echo "Done!"
