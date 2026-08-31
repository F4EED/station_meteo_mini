#!/usr/bin/env bash
# =============================================================================
# Mini station météo — installation du client / configurateur web (Linux)
#
#   wget -O install.sh https://raw.githubusercontent.com/F4EED/station_meteo_mini/main/install.sh
#   bash install.sh
#
# Relancer : icône « Station météo » sur le Bureau, ou  ~/start_StMet.sh
# =============================================================================
set -euo pipefail

MINI_REPO="https://github.com/F4EED/station_meteo_mini.git"
WEB_REPO="https://github.com/F4EED/station_meteo_client_web.git"
PNPM_VERSION="11.9.0"

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/start_StMet.sh" && -f "${SCRIPT_DIR}/README.md" ]]; then
  INSTALL_DIR="${SCRIPT_DIR}"
else
  INSTALL_DIR="${HOME}/Station-meteo"
fi

echo ""
echo "========================================"
echo "  Station météo — installation Linux"
echo "========================================"
echo "  Dossier : ${INSTALL_DIR}"
echo "  (quelques minutes, mot de passe sudo possible)"
echo "========================================"
echo ""

say() { printf '\n>> %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if ! have sudo; then
  echo "Il faut un compte avec sudo."
  exit 1
fi

# --- 1. Paquets de base ---
say "1/5 — Préparation de l'ordinateur"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git curl ca-certificates gnupg wget bluez

is_snap_bin() {
  local bin="$1"
  local resolved
  resolved="$(readlink -f "$bin" 2>/dev/null || echo "$bin")"
  [[ "$bin" == /snap/* || "$resolved" == /snap/* ]]
}

browser_ok() {
  local name bin
  for name in google-chrome-stable google-chrome chromium chromium-browser brave-browser microsoft-edge-stable microsoft-edge; do
    bin="$(command -v "$name" 2>/dev/null || true)"
    if [[ -n "$bin" ]] && ! is_snap_bin "$bin"; then
      echo "$bin"
      return 0
    fi
  done
  return 1
}

ensure_chromium() {
  local found
  if found="$(browser_ok)"; then
    echo "Navigateur OK : ${found}"
    return 0
  fi
  say "Installation de Chrome / Chromium (Web Bluetooth + Web Serial, pas Firefox)…"
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  if [[ "$arch" == "amd64" ]]; then
    local deb
    deb="$(mktemp --suffix=.deb)"
    if wget -qO "$deb" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$deb" || {
        sudo dpkg -i "$deb" || true
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y || true
      }
    fi
    rm -f "$deb"
  fi
  if ! browser_ok >/dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium || \
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium-browser || true
  fi
  if found="$(browser_ok)"; then
    echo "Navigateur installé : ${found}"
    return 0
  fi
  echo "Aucun Chrome/Chromium (apt) installé — le Bluetooth du navigateur ne marchera pas."
  echo "  Debian : sudo apt install chromium"
  echo "  Ubuntu : installez Google Chrome (.deb), pas le paquet Snap chromium-browser"
  echo "  Firefox n'a pas Web Bluetooth (USB = onglet Serial uniquement)."
}

CURRENT_USER="$(id -un)"
if getent group bluetooth >/dev/null 2>&1; then
  sudo usermod -aG bluetooth "${CURRENT_USER}" || true
fi
if getent group dialout >/dev/null 2>&1; then
  sudo usermod -aG dialout "${CURRENT_USER}" || true
fi
if command -v snap >/dev/null 2>&1 && snap list chromium >/dev/null 2>&1; then
  sudo snap connect chromium:bluez >/dev/null 2>&1 || true
  echo "Note : Chromium Snap bride souvent le Bluetooth. Préférez Google Chrome ou Chromium (apt)."
fi

if [[ -f /etc/bluetooth/main.conf ]]; then
  if grep -qE '^#?Experimental' /etc/bluetooth/main.conf; then
    sudo sed -i -E 's/^#?Experimental.*/Experimental = true/' /etc/bluetooth/main.conf
  else
    printf '\n[General]\nExperimental = true\n' | sudo tee -a /etc/bluetooth/main.conf >/dev/null
  fi
fi
BT_DAEMON=""
for p in /usr/libexec/bluetooth/bluetoothd /usr/lib/bluetooth/bluetoothd; do
  if [[ -x "$p" ]]; then
    BT_DAEMON="$p"
    break
  fi
done
if [[ -n "${BT_DAEMON}" ]]; then
  sudo mkdir -p /etc/systemd/system/bluetooth.service.d
  sudo tee /etc/systemd/system/bluetooth.service.d/station-meteo-experimental.conf >/dev/null <<UNIT
[Service]
ExecStart=
ExecStart=${BT_DAEMON} --experimental
UNIT
  sudo systemctl daemon-reload >/dev/null 2>&1 || true
  sudo systemctl restart bluetooth >/dev/null 2>&1 || true
fi
bluetoothctl power on >/dev/null 2>&1 || true

ensure_chromium

# Flags BLE/Serial : uniquement le profil dédié (scripts/lancer-navigateur.sh).
# Ne pas écrire ~/.config/chromium-flags.conf ni /etc/chromium.d — Chromium
# classe --enable-blink-features comme « non pris en charge ».
sudo rm -f /etc/chromium.d/station-meteo-bluetooth 2>/dev/null || true

if ! have node || [[ "$(node -v | sed 's/^v//' | cut -d. -f1)" -lt 22 ]]; then
  say "Installation de Node.js 22…"
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
fi
echo "Node $(node -v)"

# --- 2. pnpm ---
say "2/5 — pnpm ${PNPM_VERSION}"
export PATH="/usr/bin:/usr/local/bin:${HOME}/.local/share/pnpm:${HOME}/.local/bin:${PATH}"
if ! have pnpm || ! pnpm -v >/dev/null 2>&1; then
  sudo npm install -g "pnpm@${PNPM_VERSION}"
  hash -r 2>/dev/null || true
fi
if ! have pnpm || ! pnpm -v >/dev/null 2>&1; then
  echo "pnpm introuvable. Vérifiez Internet et réessayez : bash install.sh"
  exit 1
fi
echo "pnpm $(pnpm -v)"

# --- 3. Dépôts ---
say "3/5 — Téléchargement"
if [[ -f "${INSTALL_DIR}/start_StMet.sh" && -f "${INSTALL_DIR}/README.md" ]]; then
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    git -C "${INSTALL_DIR}" pull --ff-only || true
  fi
else
  if [[ -e "${INSTALL_DIR}" ]]; then
    echo "Le dossier ${INSTALL_DIR} existe déjà et n'est pas la mini station."
    echo "Renommez-le puis relancez."
    exit 1
  fi
  git clone "${MINI_REPO}" "${INSTALL_DIR}"
fi

WEB="${INSTALL_DIR}/station_meteo_client_web"
if [[ -d "${WEB}/apps/web" ]]; then
  if [[ -d "${WEB}/.git" ]]; then
    git -C "${WEB}" pull --ff-only || true
  fi
else
  git clone "${WEB_REPO}" "${WEB}"
fi

chmod +x "${INSTALL_DIR}/start_StMet.sh" "${INSTALL_DIR}/creer-icone.sh" \
  "${INSTALL_DIR}/scripts/lancer-navigateur.sh" 2>/dev/null || true

# --- 4. Dépendances JS ---
say "4/5 — Installation des composants (patientez)…"
export HUSKY=0
cd "${WEB}"
pnpm install

# --- 5. Icône ---
say "5/5 — Raccourci Bureau / menu"
if [[ -f "${INSTALL_DIR}/creer-icone.sh" ]]; then
  bash "${INSTALL_DIR}/creer-icone.sh" || true
else
  echo "creer-icone.sh absent — icône non créée."
fi

echo ""
echo "========================================"
echo "  C'est prêt."
echo ""
echo "  Double-cliquez l'icône « Station météo » sur le Bureau."
echo "  Ou :  ${INSTALL_DIR}/start_StMet.sh"
echo "  Ou :  station-meteo"
echo ""
echo "  URL : http://127.0.0.1:5173/"
echo "  Chrome / Chromium : USB (Web Serial) + Bluetooth."
echo "  Firefox : pas de BLE."
echo "  PIN BLE usine : 123456 — ne pas appairer dans les réglages OS."
echo ""
echo "  Si vous venez d'être ajouté au groupe bluetooth / dialout :"
echo "       déconnexion / reconnexion (ou reboot)."
echo "  Si l'icône Bureau refuse de démarrer :"
echo "       clic droit → Autoriser le lancement"
echo "  Recréer l'icône :"
echo "       bash ${INSTALL_DIR}/creer-icone.sh"
echo "========================================"
echo ""
