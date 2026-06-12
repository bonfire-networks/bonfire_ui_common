#!/bin/sh
# Build or watch the E2EE chat client, skipping gracefully when its repo isn't
# cloned (bare gitlink — see src-tauri/README.md). Usage: chat-client.sh build|watch
set -e
if [ ! -f assets/ap_c2s_client/js/package.json ]; then
  echo "ap_c2s_client not cloned at assets/ap_c2s_client — skipping chat client $1 (E2EE chat tab unavailable)"
  exit 0
fi
cd assets/ap_c2s_client/js
case "$1" in
  build) yarn install --immutable-cache && yarn build ;;
  watch) yarn watch ;;
  *) echo "usage: chat-client.sh build|watch" >&2; exit 1 ;;
esac
