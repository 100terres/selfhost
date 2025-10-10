#!/usr/bin/env bash

# run this file like:
# sudo sh ./setup.sh

set -e

mkdir -p data/.cache

chown -R 1001:1001 data
chmod 775 data/.cache
chmod g+s data/.cache
