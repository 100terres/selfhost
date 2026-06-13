#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this uninstaller using sudo: sudo ./uninstall.sh"
  exit 1
fi

SERVICE_NAME="selfhost-ipc-worker.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
IPC_DATA_DIR="/var/lib/selfhost-ipc-worker"
SOCKET_PATH="$IPC_DATA_DIR/selfhost_ipc_worker.sock"
LOCK_FILE="$IPC_DATA_DIR/selfhost_ipc_handler.lock"

echo "[1/4] Stopping service..."
systemctl stop "$SERVICE_NAME" 2>/dev/null

echo "[2/4] Disabling service..."
systemctl disable "$SERVICE_NAME" 2>/dev/null

echo "[3/4] Removing service file..."
rm -f "$SERVICE_FILE"
systemctl daemon-reload

echo "[4/4] Cleaning up..."
rm -f "$SOCKET_PATH" "$LOCK_FILE"
rm -rf "$IPC_DATA_DIR"

echo "Done!"
