#!/usr/bin/env bash
# Lance le client web de la mini station météo (Vite) et ouvre Chrome / Chromium.
# Copie bureau : ~/Bureau/start_StMet.sh  —  icône : creer-icone.sh
set -euo pipefail

PORT="${STMET_PORT:-5173}"
HOST="${STMET_HOST:-127.0.0.1}"
URL="http://${HOST}:${PORT}/"
NO_BROWSER="${STMET_NO_BROWSER:-0}"

DEFAULT_ROOT="/home/gmc-poste-2/Dev_Cursor/mestastic/Station-météo"

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
if [[ -d "$here/station_meteo_client_web/apps/web" ]]; then
  ROOT="$here"
elif [[ -d "${HOME}/Station-meteo/station_meteo_client_web/apps/web" ]]; then
  ROOT="${HOME}/Station-meteo"
else
  ROOT="$DEFAULT_ROOT"
fi

WEB="$ROOT/station_meteo_client_web"
LAUNCHER="$ROOT/scripts/lancer-navigateur.sh"

if [[ ! -d "$WEB/apps/web" ]]; then
  echo "Client web introuvable : $WEB" >&2
  echo "Installez avec : bash $ROOT/install.sh" >&2
  exit 1
fi

export PATH="/usr/bin:/usr/local/bin:${HOME}/.local/share/pnpm:${HOME}/.local/bin:${PATH}"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "pnpm introuvable. Relancez bash $ROOT/install.sh" >&2
  exit 1
fi

server_up() {
  curl -sf -o /dev/null --max-time 1 "$URL"
}

open_browser() {
  if [[ "$NO_BROWSER" == "1" ]]; then
    echo "STMET_NO_BROWSER=1 : navigateur non lancé. $URL"
    return 0
  fi
  if [[ -x "$LAUNCHER" ]]; then
    bash "$LAUNCHER" "$URL" >/dev/null 2>&1 &
    return 0
  fi
  echo "scripts/lancer-navigateur.sh absent. Ouvrir $URL à la main (Chrome / Chromium)." >&2
  return 1
}

if server_up; then
  echo "Serveur déjà actif : $URL"
  open_browser
  exit 0
fi

if [[ ! -d "$WEB/node_modules" ]]; then
  echo "pnpm install (première fois)…"
  (cd "$WEB" && pnpm install)
fi

echo "Démarrage client web → $URL"
cd "$WEB"
pnpm --filter meshtastic-web dev --host "$HOST" --port "$PORT" &
vite_pid=$!

cleanup() {
  kill "$vite_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

ok=0
for _ in $(seq 1 90); do
  if server_up; then
    ok=1
    break
  fi
  if ! kill -0 "$vite_pid" 2>/dev/null; then
    echo "Le serveur s’est arrêté." >&2
    exit 1
  fi
  sleep 0.5
done

if [[ "$ok" != "1" ]]; then
  echo "Timeout : $URL ne répond pas." >&2
  exit 1
fi

echo "Prêt : $URL"
open_browser
echo "Ctrl+C pour arrêter le serveur."
wait "$vite_pid"
