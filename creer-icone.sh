#!/usr/bin/env bash
# Recrée l'icône Bureau + entrée menu Applications (GNOME / XFCE / MATE / Cinnamon).
# Usage : bash creer-icone.sh
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
INSTALL_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"

if [[ ! -x "${INSTALL_DIR}/start_StMet.sh" ]]; then
  echo "Lancez ce script depuis le dossier Station-météo (celui qui contient start_StMet.sh)."
  exit 1
fi

DE="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-inconnu}}"
echo "Environnement détecté : ${DE}"

ICON_SRC=""
for candidate in \
  "${INSTALL_DIR}/assets/station-meteo.png" \
  "${INSTALL_DIR}/assets/station-meteo-256.png" \
  "${INSTALL_DIR}/station_meteo_client_web/apps/web/public/apple-touch-icon.png"
do
  if [[ -f "$candidate" ]]; then
    ICON_SRC="$candidate"
    break
  fi
done
if [[ -z "${ICON_SRC}" ]]; then
  echo "Aucune image d'icône trouvée (assets/station-meteo.png)."
  exit 1
fi

if command -v xdg-user-dir >/dev/null 2>&1; then
  DESKTOP_DIR="$(xdg-user-dir DESKTOP)"
fi
if [[ -z "${DESKTOP_DIR:-}" || "${DESKTOP_DIR}" == "${HOME}" ]]; then
  if [[ -d "${HOME}/Bureau" ]]; then DESKTOP_DIR="${HOME}/Bureau"
  elif [[ -d "${HOME}/Desktop" ]]; then DESKTOP_DIR="${HOME}/Desktop"
  else DESKTOP_DIR="${HOME}/Desktop"; mkdir -p "${DESKTOP_DIR}"
  fi
fi

APPS_DIR="${HOME}/.local/share/applications"
BIN_DIR="${HOME}/.local/bin"
ICON_BASE="${HOME}/.local/share/icons/hicolor"
mkdir -p "${APPS_DIR}" "${DESKTOP_DIR}" "${BIN_DIR}"
mkdir -p "${ICON_BASE}/256x256/apps" "${ICON_BASE}/128x128/apps" "${ICON_BASE}/48x48/apps" "${ICON_BASE}/32x32/apps"

cp -f "${ICON_SRC}" "${ICON_BASE}/256x256/apps/station-meteo.png"
cp -f "${ICON_SRC}" "${ICON_BASE}/128x128/apps/station-meteo.png"
cp -f "${ICON_SRC}" "${ICON_BASE}/48x48/apps/station-meteo.png"
cp -f "${ICON_SRC}" "${ICON_BASE}/32x32/apps/station-meteo.png"
if [[ -f "${INSTALL_DIR}/assets/station-meteo.svg" ]]; then
  mkdir -p "${ICON_BASE}/scalable/apps"
  cp -f "${INSTALL_DIR}/assets/station-meteo.svg" "${ICON_BASE}/scalable/apps/station-meteo.svg"
fi
ICON_ABS="${ICON_BASE}/256x256/apps/station-meteo.png"
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f "${ICON_BASE}" >/dev/null 2>&1 || true
fi

chmod +x "${INSTALL_DIR}/start_StMet.sh"
if [[ -f "${INSTALL_DIR}/scripts/lancer-navigateur.sh" ]]; then
  chmod +x "${INSTALL_DIR}/scripts/lancer-navigateur.sh"
fi
ln -sfn "${INSTALL_DIR}/start_StMet.sh" "${HOME}/start_StMet.sh"

WRAPPER="${BIN_DIR}/station-meteo"
cat > "${WRAPPER}" <<EOF
#!/usr/bin/env bash
exec "${INSTALL_DIR}/start_StMet.sh" "\$@"
EOF
chmod +x "${WRAPPER}"

DESKTOP_FILE="${INSTALL_DIR}/Station-meteo.desktop"
cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Station météo
Name[fr]=Station météo
GenericName=Client / configurateur web
GenericName[fr]=Client / configurateur web
Comment=Lance le client web (USB, Bluetooth, IP)
Comment[fr]=Lance le client web (USB, Bluetooth, IP)
Keywords=station;meteo;météo;meshtastic;gaulix;BME688;LoRa;
Exec=${INSTALL_DIR}/start_StMet.sh
TryExec=${INSTALL_DIR}/start_StMet.sh
Path=${INSTALL_DIR}
Icon=${ICON_ABS}
Terminal=true
Categories=Network;
StartupNotify=true
EOF
chmod +x "${DESKTOP_FILE}"

MENU_FILE="${APPS_DIR}/station-meteo.desktop"
cp -f "${DESKTOP_FILE}" "${MENU_FILE}"
chmod +x "${MENU_FILE}"

DESKTOP_LAUNCHER="${DESKTOP_DIR}/Station-meteo.desktop"
cp -f "${DESKTOP_FILE}" "${DESKTOP_LAUNCHER}"
chmod +x "${DESKTOP_LAUNCHER}"

# Copie du lanceur sur le Bureau (double-clic .sh si le .desktop est bloqué)
cp -f "${INSTALL_DIR}/start_StMet.sh" "${DESKTOP_DIR}/start_StMet.sh"
chmod +x "${DESKTOP_DIR}/start_StMet.sh"

if command -v gio >/dev/null 2>&1; then
  gio set "${DESKTOP_LAUNCHER}" "metadata::trusted" true 2>/dev/null || true
fi

if command -v desktop-file-install >/dev/null 2>&1; then
  desktop-file-install --dir="${APPS_DIR}" "${DESKTOP_FILE}" 2>/dev/null || true
  cp -f "${DESKTOP_FILE}" "${MENU_FILE}"
  chmod +x "${MENU_FILE}"
fi
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "${MENU_FILE}" 2>&1 || true
fi
if command -v xdg-desktop-menu >/dev/null 2>&1; then
  xdg-desktop-menu forceupdate 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${APPS_DIR}" 2>/dev/null || true
fi

if command -v xfdesktop >/dev/null 2>&1; then
  xfdesktop --reload >/dev/null 2>&1 || true
fi

echo ""
echo "Lanceurs créés :"
echo "  Bureau .desktop : ${DESKTOP_LAUNCHER}"
echo "  Bureau .sh      : ${DESKTOP_DIR}/start_StMet.sh"
echo "  Menu            : ${MENU_FILE}"
echo "  Commande        : station-meteo   ou   ~/start_StMet.sh"
echo ""
echo "Si l'icône Bureau refuse de démarrer : clic droit → Autoriser le lancement."
echo "Recréer l'icône : bash ${INSTALL_DIR}/creer-icone.sh"
echo ""
