#!/bin/bash

# This is only an example, of how to trigger a task

IPC_DATA_DIR="/var/lib/selfhost-ipc-worker"
SOCKET_PATH="$IPC_DATA_DIR/selfhost_ipc_worker.sock"

if [ ! -S "$SOCKET_PATH" ]; then
  echo "Error: Worker daemon is not running at $SOCKET_PATH"
  exit 1
fi

echo "[Trigger] Sending task initialization signal via socat..."

RESPONSE=$(echo "DEPLOY_WIDGETS" | socat -t 300 - UNIX-CONNECT:"$SOCKET_PATH")

echo "[Trigger] Worker completed operations."
echo "[Trigger] Final Response: $RESPONSE"

if [ "$RESPONSE" = "STATUS:SUCCESS" ]; then
  echo "Outcome: Success! Continuing local script operations."
else
  echo "Outcome: Task failed or denied. Terminating."
  exit 1
fi
