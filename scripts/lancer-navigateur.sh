#!/usr/bin/env bash
# Ouvre le client web dans Chrome/Chromium avec Web Bluetooth et Web Serial.
# Pas de xdg-open : Firefox n'a pas Web Bluetooth.
# Usage : bash scripts/lancer-navigateur.sh [URL]
set -euo pipefail

URL="${1:-http://127.0.0.1:5173/}"
PROFILE="${HOME}/.config/station-meteo-chromium"

# Pas de --enable-blink-features ni --enable-experimental-web-platform-features :
# Chromium les classe « non pris en charge » et affiche l'infobarre jaune.
# http://127.0.0.1 est déjà un contexte sécurisé (Web Bluetooth / Web Serial).
# --enable-features reste un flag supporté (BLE Linux, permissions persistantes).
FLAGS=(
  --enable-features=WebBluetooth,WebBluetoothNewPermissionsBackend,WebSerial
  --no-first-run
  --no-default-browser-check
)

is_snap() {
  local bin="$1"
  local resolved
  resolved="$(readlink -f "$bin" 2>/dev/null || echo "$bin")"
  [[ "$bin" == /snap/* || "$resolved" == /snap/* ]]
}

find_chromium() {
  local candidate name
  # Binaire réel en premier : le wrapper (/usr/bin/chromium) injecte
  # /etc/chromium.d et ~/.config/chromium-flags.conf, souvent
  # --enable-blink-features (infobarre « flag non pris en charge »).
  local binaries=(
    /opt/google/chrome/chrome
    /usr/lib/chromium/chromium
    /usr/lib/chromium-browser/chromium-browser
  )
  for candidate in "${binaries[@]}"; do
    if [[ -x "$candidate" ]] && ! is_snap "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  local names=(
    google-chrome-stable
    google-chrome
    chromium
    chromium-browser
    brave-browser
    microsoft-edge-stable
    microsoft-edge
  )
  for name in "${names[@]}"; do
    candidate="$(command -v "$name" 2>/dev/null || true)"
    if [[ -z "$candidate" ]]; then
      continue
    fi
    if is_snap "$candidate"; then
      echo "Note : ${name} est un Snap (Bluetooth souvent bloqué) — ignoré." >&2
      continue
    fi
    echo "$candidate"
    return 0
  done
  for candidate in \
    /opt/google/chrome/google-chrome \
    /usr/bin/google-chrome-stable \
    /usr/bin/google-chrome \
    /usr/bin/chromium \
    /usr/bin/chromium-browser
  do
    if [[ -x "$candidate" ]] && ! is_snap "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

wait_for_url() {
  local url="$1" i=0
  while (( i < 50 )); do
    if command -v curl >/dev/null 2>&1 && curl -fsS -o /dev/null --max-time 1 "$url" 2>/dev/null; then
      return 0
    fi
    sleep 0.4
    i=$((i + 1))
  done
  return 0
}

bluetoothctl power on >/dev/null 2>&1 || true

echo "Attente de ${URL}…"
wait_for_url "$URL"

if BROWSER="$(find_chromium)"; then
  mkdir -p "${PROFILE}"
  echo "Navigateur : ${BROWSER} (profil station-meteo, Web Bluetooth / Web Serial)"
  echo "  ${URL}"
  # Un Chromium déjà ouvert avec ce profil ignore les nouveaux flags.
  if pgrep -f -- "--user-data-dir=${PROFILE}" >/dev/null 2>&1; then
    echo "Fermeture de l'ancienne fenêtre (profil dédié)…"
    pkill -f -- "--user-data-dir=${PROFILE}" 2>/dev/null || true
    sleep 0.6
  fi
  # Le wrapper Chromium réinjecte $CHROMIUM_FLAGS (souvent blink-features).
  unset CHROMIUM_FLAGS
  exec "${BROWSER}" --user-data-dir="${PROFILE}" --new-window "${FLAGS[@]}" "${URL}"
fi

echo "" >&2
echo "Aucun Chrome/Chromium (apt) détecté. Firefox n'a PAS Web Bluetooth." >&2
echo "  Debian :  sudo apt install chromium" >&2
echo "  Ubuntu :  installez Google Chrome (.deb), pas le Snap chromium-browser" >&2
echo "Puis relancez l'icône Station météo, ou :" >&2
echo "  bash \"$0\" ${URL}" >&2
if command -v notify-send >/dev/null 2>&1; then
  notify-send "Station météo" "Installez Google Chrome ou Chromium (apt) pour le Bluetooth. Firefox ne convient pas." || true
fi
exit 1
