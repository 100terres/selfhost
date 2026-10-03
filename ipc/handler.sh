#!/bin/bash

IPC_DATA_DIR="/var/lib/selfhost-ipc-worker"
LOCK_FILE="$IPC_DATA_DIR/selfhost_ipc_handler.lock"

read -r SIGNAL
SIGNAL=$(echo "$SIGNAL" | xargs)

if [ "$SIGNAL" = "DEPLOY_WIDGETS" ]; then
  echo "[Selfhost IPC Handler] DEPLOY_WIDGETS received..." >&2

  exec 200>"$LOCK_FILE"
  flock 200

  echo "[Selfhost IPC Handler] Executing DEPLOY_WIDGETS..." >&2
  ORIGINAL_DIR="$(pwd)"
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$DIR/../services/widgets"
  bash "./deploy.sh" >&2
  DEPLOY_WIDGETS_EXIT_CODE=$?
  cd "$ORIGINAL_DIR"

  echo "[Selfhost IPC Handler] DEPLOY_WIDGETS done. exit code: $DEPLOY_WIDGETS_EXIT_CODE" >&2

  if [ $DEPLOY_WIDGETS_EXIT_CODE -eq 0 ]; then
    echo "STATUS:SUCCESS"
  else
    echo "STATUS:FAILED"
  fi
elif [ "$SIGNAL" = "DEPLOY_OPENPGPKEY_100TERRES_COM" ]; then
  echo "[Selfhost IPC Handler] DEPLOY_OPENPGPKEY_100TERRES_COM received..." >&2

  exec 200>"$LOCK_FILE"
  flock 200

  echo "[Selfhost IPC Handler] Executing DEPLOY_OPENPGPKEY_100TERRES_COM..." >&2
  ORIGINAL_DIR="$(pwd)"
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$DIR/../services/openpgpkey-100terres-com"
  bash "./deploy.sh" >&2
  DEPLOY_OPENPGPKEY_100TERRES_COM_EXIT_CODE=$?
  cd "$ORIGINAL_DIR"

  echo "[Selfhost IPC Handler] DEPLOY_OPENPGPKEY_100TERRES_COM done. exit code: $DEPLOY_OPENPGPKEY_100TERRES_COM_EXIT_CODE" >&2

  if [ $DEPLOY_OPENPGPKEY_100TERRES_COM_EXIT_CODE -eq 0 ]; then
    echo "STATUS:SUCCESS"
  else
    echo "STATUS:FAILED"
  fi
elif [ "$SIGNAL" = "DEPLOY_100TERRES_COM" ]; then
  echo "[Selfhost IPC Handler] DEPLOY_100TERRES_COM received..." >&2

  exec 200>"$LOCK_FILE"
  flock 200

  echo "[Selfhost IPC Handler] Executing DEPLOY_100TERRES_COM..." >&2
  ORIGINAL_DIR="$(pwd)"
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$DIR/../services/100terres-com"
  bash "./deploy.sh" >&2
  DEPLOY_100TERRES_COM_EXIT_CODE=$?
  cd "$ORIGINAL_DIR"

  echo "[Selfhost IPC Handler] DEPLOY_100TERRES_COM done. exit code: $DEPLOY_100TERRES_COM_EXIT_CODE" >&2

  if [ $DEPLOY_100TERRES_COM_EXIT_CODE -eq 0 ]; then
    echo "STATUS:SUCCESS"
  else
    echo "STATUS:FAILED"
  fi
else
  echo "[Selfhost IPC Handler] Unknown $SIGNAL task" >&2
  echo "STATUS:UNKNOWN_TASK"
fi
