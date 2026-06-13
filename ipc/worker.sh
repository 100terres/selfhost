#!/bin/bash

IPC_DATA_DIR="/var/lib/selfhost-ipc-worker"
SOCKET_PATH="$IPC_DATA_DIR/selfhost_ipc_worker.sock"
LOCK_FILE="$IPC_DATA_DIR/selfhost_ipc_handler.lock"

rm -f "$SOCKET_PATH" "$LOCK_FILE"
trap 'rm -f "$SOCKET_PATH" "$LOCK_FILE"; echo -e "\n[Selfhost IPC Worker] Stopped."; exit' INT TERM EXIT

echo "[Selfhost IPC Worker] Listening on $SOCKET_PATH..."

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
socat -t 300 UNIX-LISTEN:"$SOCKET_PATH",fork,reuseaddr SYSTEM:"bash $DIR/handler.sh"
