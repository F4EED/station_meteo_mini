#!/usr/bin/env bash
# Lance le client web station météo + Chromium (Web Serial / Web Bluetooth).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB="$ROOT/station_meteo_client_web"
HOST="${STMET_HOST:-127.0.0.1}"
PORT="${STMET_PORT:-5173}"
URL="http://${HOST}:${PORT}/"

if [[ ! -d "$WEB" ]]; then
  echo "Clone manquant : $WEB" >&2
  echo "git clone https://github.com/F4EED/station_meteo_client_web.git" >&2
  exit 1
fi

if curl -sf -o /dev/null --max-time 1 "$URL"; then
  echo "Serveur déjà prêt : $URL"
else
  cd "$WEB"
  if [[ ! -d node_modules ]]; then
    corepack enable >/dev/null 2>&1 || true
    pnpm install
  fi
  pnpm --filter meshtastic-web dev --host "$HOST" --port "$PORT" &
  for i in $(seq 1 60); do
    if curl -sf -o /dev/null --max-time 1 "$URL"; then
      break
    fi
    sleep 1
  done
fi

echo "Prêt : $URL"

if [[ "${STMET_NO_BROWSER:-}" == "1" ]]; then
  exit 0
fi

bin=""
for c in chromium chromium-browser google-chrome; do
  if command -v "$c" >/dev/null 2>&1; then
    bin="$c"
    break
  fi
done
if [[ -n "$bin" ]]; then
  "$bin" --new-window --enable-features=WebBluetooth,WebSerial --enable-experimental-web-platform-features "$URL" >/dev/null 2>&1 &
else
  echo "Chromium introuvable — ouvre $URL à la main." >&2
fi
