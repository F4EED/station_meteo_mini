# Mini station météo Meshtastic

Station météo autonome **minimum**, sans écran, nœud LoRa unique. Version projet : **0.1.1**.

| | |
| --- | --- |
| **Carte** | Seeed Studio Wio Tracker L1 Pro (nRF52840, SX1262, GNSS L76K) |
| **Écran** | aucun |
| **Capteur** | Bosch BME688, I2C Grove, **extérieur sous abri** |
| **Énergie** | solaire + batterie Li-ion du L1 Pro (`power.is_power_saving`) |
| **Réseau** | Gaulix 868, rôle Sensor, hop 3 |

## Arborescence

Quatre dépôts GitHub, un clone local par composant. **Pas de submodule.**

```
Station-météo/                         →  F4EED/station_meteo_mini     (ce README)
  install.sh  install.ps1  install.bat ← install client web (Linux / Windows)
  creer-icone.sh                       ← raccourci Bureau + icône
  start_StMet.sh                       ← lance le client web + Chromium
  assets/                              ← icône (PNG / ICO / SVG)
  scripts/lancer-navigateur.sh         ← Chrome/Chromium + Web Bluetooth / Serial
  firmware/                            →  F4EED/station_meteo_firmware
  station_meteo_client_web/            →  F4EED/station_meteo_client_web
  station_meteo_client_android/        →  F4EED/station_meteo_client_android
```

## Dépôts GitHub (F4EED)

| Dépôt | Rôle | `origin` | `upstream` |
| --- | --- | --- | --- |
| [station_meteo_mini](https://github.com/F4EED/station_meteo_mini) | README projet global | — | — |
| [station_meteo_firmware](https://github.com/F4EED/station_meteo_firmware) | Firmware (variant L1 Pro / télémétrie) | F4EED | [meshtastic/firmware](https://github.com/meshtastic/firmware) |
| [station_meteo_client_web](https://github.com/F4EED/station_meteo_client_web) | Client web BLE / USB | F4EED | [meshtastic/web](https://github.com/meshtastic/web) |
| [station_meteo_client_android](https://github.com/F4EED/station_meteo_client_android) | Client Android | F4EED | [meshtastic/Meshtastic-Android](https://github.com/meshtastic/Meshtastic-Android) |

Noms en minuscules, sans accent.

### Cloner

```bash
git clone https://github.com/F4EED/station_meteo_mini.git
cd station_meteo_mini
git clone https://github.com/F4EED/station_meteo_firmware.git firmware
git clone https://github.com/F4EED/station_meteo_client_web.git
git clone https://github.com/F4EED/station_meteo_client_android.git
```

Dans chaque composant : `origin` = F4EED, `upstream` = dépôt Meshtastic officiel (resync / rebase).

Reprise sur une autre machine : [`TRANSIT.md`](TRANSIT.md) (branches, clone Android `feat/station-meteo-client`, JDK 25 pour l’APK).

## Matériel

- **L1 Pro** : boîtier, batterie, entrée solaire USB-C / solaire / 3,7 V (PMIC Seeed). GPS hardware présent, **désactivé** par défaut. Grove I2C `Wire1` : SDA D18, SCL D17.
- **Pas d’écran** : ne pas flasher `seeed_wio_tracker_L1_eink` ni compter sur l’OLED du variant L1 stock (`HAS_SCREEN` / `USE_SSD1306`).
- **BME688** : Grove I2C `Wire1` (SDA D18, SCL D17), adresse `0x76` ou `0x77`. **Extérieur sous abri** météo (pas plein vent, pas intérieur). Driver firmware `BME680Sensor` (Adafruit BME680, pas BSEC).
- Tension batterie : ADC `PIN_VBAT` + `BAT_READ`, télémétrie power activée.

## Firmware

- Checkout : [`firmware/`](firmware/) — `origin` [F4EED/station_meteo_firmware](https://github.com/F4EED/station_meteo_firmware), `upstream` Meshtastic
- Branche de travail : `station-meteo`
- Env PlatformIO : `seeed_wio_tracker_L1_meteo`
- **Pas** le fork ThinkNode (`mestastic/firmware`)
- **État :** variant `seeed_wio_tracker_L1_meteo` (L1 Pro **sans écran**), `WeatherAlertPolicy`, version **0.1.1**. Flash DFU nRF52 (UF2).
- **Dev :** `STATION_METEO_DEV_NO_SLEEP` — pas de deep sleep (USB/BLE restent joignables). Retirer le `-D` dans `firmware/variants/nrf52840/seeed_wio_tracker_L1_meteo/platformio.ini` pour rétablir le sommeil Sensor.

```bash
cd firmware
pio run -e seeed_wio_tracker_L1_meteo
# DFU (volume TRACKER L1) : copier .pio/build/seeed_wio_tracker_L1_meteo/firmware-seeed_wio_tracker_L1_meteo-*.uf2
# Sinon : pio run -e seeed_wio_tracker_L1_meteo -t upload   (1200 bps / nrfutil, pas esptool)
```

Allègement **à la compile** : `HAS_SCREEN=0`, `MESHTASTIC_EXCLUDE_SCREEN`, exclusions MQTT / Wi‑Fi / ATAK / canned messages / store & forward / paxcounter / detection sensor / waypoint / neighbor info / traceroute / notifs externes. Conservé : LoRa, BLE, I2C, télémétrie environnement + power, admin, PKI.

Fichiers : `firmware/variants/nrf52840/seeed_wio_tracker_L1_meteo/`, `src/modules/Telemetry/WeatherAlertPolicy.h`, `StationMeteoPrefs` (`/prefs/station_meteo.dat`), hook `STATION_METEO` dans `EnvironmentTelemetry.cpp`. Pas d’édition de `src/mesh/generated/`.

Pairing BLE headless : PIN fixe Meshtastic (souvent `123456`).

## Paramètres Meshtastic / Gaulix (défauts)

Cibles au premier boot / factory reset. Alignées sur [Gaulix.fr](https://gaulix.fr/) V25.x sauf rôle Sensor, GPS, télémétrie.

| Champ | Valeur |
| --- | --- |
| Rôle | `SENSOR` |
| `owner.is_unmessagable` | **`false`** (STATION_METEO ; le rôle SENSOR stock force `true`) |
| `power.is_power_saving` | **dev : off** (`STATION_METEO_DEV_NO_SLEEP`) ; prod : `true` (sommeil = intervalle télémétrie) |
| Bluetooth | activé (client web / app Android) |
| GPS | `DISABLED` (L76K présent). Un fix GPS remet l’horloge. USB : heure du PC à la connexion (`set_time_only`, ne remplace pas un horodatage GPS). |
| Hop | **3** (`HOP_RELIABLE`) |
| Région | `EU_868` |
| Modem preset | `LONG_MODERATE` (use preset = true) |
| Frequency slot | `1` |
| Override frequency | **869.4625 MHz** |
| Override duty cycle | `false` |
| SX126x RX boosted gain | `true` |
| Ignore MQTT | `false` |
| OK to MQTT | `true` |
| Nom long | `42METOLM8Sensor- mini st` (24 octets) |

Canaux (PSK `AQ==`) : **0** primary `Fr_Balise` · **1** `Fr_EMCOM` · **2** `Fr-BlaBla` · **3** `Alerte`. Uplink/downlink MQTT off, pas de broadcast position. Télémétrie sur `Fr_Balise`.

Télémétrie : environment measurement on, screen off, intervalle **piloté par les seuils** ; power measurement on.

Fuseau France : `CET-1CEST,M3.5.0,M10.5.0/3`. Nom long cuit (premier boot / factory reset) : `42METOLM8Sensor- mini st`. Demandé `42METOLM8Sensor- mini station météo (developpement)` (53 octets UTF-8) : tronqué à **24 octets** (`MAX_LONG_NAME_BYTES` ; le tampon protobuf reste 40 pour l’ancien plafond 39). Pas de short name usine (max 4 octets).

## Télémétrie BME688

Capteur **extérieur sous abri**. Grandeurs : T °C, HR %, pression hPa, résistance gaz, IAQ 0–500, eCO2 estimé.

**Gaz** — fil Meshtastic = **kΩ** (`gas_resistance`) ; affichage client = **Ω** (×1000). Plage normale projet : 5 000–1,0×10⁷ Ω (moyenne visée 100 000 Ω). Sous abri, **50–150 kΩ** est typique (ex. ~72 kΩ : normal, pas de l’air « très propre » en plein vent). Résistance **monte** si l’air est plus propre, **baisse** avec COV / humidité.

**IAQ** — estimateur firmware (`BME680IaqEstimator`), pas BSEC Bosch. Publié après **3** échantillons de warmup gaz (1/min si le nœud est éveillé), pas après 30. Si `iaq` manque, le client web estime depuis `gas_resistance` (plafond 100 kΩ). Indice VOC 0–500, **pas** un indice ATMO.

**eCO2** — `400 + IAQ × 4` ppm, calculé dans le client (et les seuils firmware). **Pas** un capteur NDIR (SCD4x). Tendance seulement, surtout en extérieur.

Défauts 0.1.0, réglables plus tard par l’app. Priorité **choc > alerte > normal**. Retour à la normale dès que toutes les grandeurs présentes sont dans [mini, maxi] sans choc. Grandeur absente (`has_*` faux) ignorée.

| Paramètre | Mini | Maxi | Choc (Δ) |
| --- | --- | --- | --- |
| Température °C | −10 | 40 | 3 °C |
| Humidité % | 20 | 90 | 15 points |
| Pression hPa | 980 | 1040 | 5 hPa |
| Résistance gaz Ω | 5 000 | 1,0×10⁷ | 30 % relatif |
| IAQ 0–500 | 0 | 150 | 50 points |

| Mode | Condition | Intervalle / sommeil |
| --- | --- | --- |
| Normal | dans tous les seuils | créneaux **06:00, 12:00, 18:00** locale (réglable) |
| Alerte | hors mini/maxi | **3600 s** |
| Choc | variation brutale vs échantillon précédent | **300 s** |

Sans horloge valide : mode Normal = 21600 s. `is_power_saving` reste `true` ; seul `environment_update_interval` change. Horloge : GPS si fix, sinon heure du PC à la connexion USB.

Client web, dérivé de T + HR (pas de vent sur le BME688) : **point de rosée** Magnus–Tetens ; **température ressentie** = indice de chaleur NWS si T ≥ 27 °C, sinon température apparente Steadman (vent = 0). Gaz / IAQ / eCO2 : voir ci-dessus. Si gaz présent mais IAQ encore absente : repli client ; si T/HR/P sans gaz : « Chauffe gaz… ». Page Météo : pastille **vert / orange / rouge** à côté de chaque grandeur (dans la moyenne / un peu décalé / complètement décalé ; bandes défaut STMET).

## Client web

Fork dans [`station_meteo_client_web/`](station_meteo_client_web/). Client **simplifié** : télémétrie BME688 (T, HR, pression, gaz Ω, IAQ, eCO2) / batterie, réglages. **Pas** de messagerie, liste de nœuds ni carte.

Connexions (Chrome / Chromium, pas Firefox pour le BLE) :

| Onglet | API |
| --- | --- |
| **USB** | Web Serial — handshake `wantConfigId` **69420** (config seule : pas de dump NodeDB ni manifeste fichiers) |
| **Bluetooth** | Web Bluetooth |
| **IP** | HTTP(S) |

### Installer (client web seulement)

Linux (Debian / Ubuntu) — vérifie / installe **Chrome ou Chromium** (apt, pas Snap), Node 22, pnpm, groupes `bluetooth` / `dialout`, clone le client web, icône Bureau :

```bash
wget -O install.sh https://raw.githubusercontent.com/F4EED/station_meteo_mini/main/install.sh
bash install.sh
```

Depuis un clone déjà présent : `bash install.sh`. Recréer l’icône : `bash creer-icone.sh`.

Windows 10 / 11 — Git, Node LTS, **Google Chrome** (ou Edge), pnpm, clone, raccourci Bureau avec icône :

```powershell
irm https://raw.githubusercontent.com/F4EED/station_meteo_mini/main/install.ps1 | iex
```

Ou double-clic `install.bat`. Recréer le raccourci : `install.ps1 -Icone`.

Firefox n’a pas Web Bluetooth. PIN BLE usine : **123456**. Ne pas appairer le nœud dans les réglages Bluetooth de l’OS avant le navigateur.

### Lancer

```bash
./start_StMet.sh
```

- Démarre Vite (`pnpm --filter meshtastic-web dev`) sur **http://127.0.0.1:5173/** (boucle locale = contexte sécurisé BLE / USB)
- Ouvre **Chrome / Chromium** (profil dédié, `--enable-features=WebBluetooth` — pas `--enable-blink-features`). Ne pas coller l’URL dans un Chromium déjà ouvert : ce profil n’a pas les flags BLE.
- Linux : icône **Station météo** (Bureau + menu Applications). Copie : `~/Bureau/start_StMet.sh`. GNOME : autoriser le lancement si demandé.
- Windows : raccourci **Station météo** sur le Bureau (`.lnk` / `.bat`)

| Variable | Effet |
| --- | --- |
| `STMET_NO_BROWSER=1` | Serveur seul, pas de navigateur |
| `STMET_PORT` | Port (défaut `5173`) |
| `STMET_HOST` | Hôte Vite (défaut `127.0.0.1`, aussi `localhost`) |

Ctrl+C dans le terminal arrête le serveur. Si le serveur tourne déjà, le script n’en relance pas un second : il ouvre le navigateur.

## Application Android

Clone : [`station_meteo_client_android/`](station_meteo_client_android/). Dépôt [F4EED/station_meteo_client_android](https://github.com/F4EED/station_meteo_client_android) (base Meshtastic-Android).

Client **simplifié** comme le web : **Météo**, **Connexions** (BLE / USB / IP), **Réglages**. Pas de messagerie, liste de nœuds ni carte. Télémétrie BME688 (T, HR, pression, gaz Ω, IAQ, eCO2) / batterie. PIN BLE usine : **123456**. `applicationId` : `fr.f4eed.stationmeteo`.

```bash
cd station_meteo_client_android
./gradlew assembleFdroidDebug
# APK : androidApp/build/outputs/apk/fdroid/debug/
```

Seuils mini/maxi (protocole STMET) : constantes firmware 0.1.x affichées en pastille **vert / orange / rouge** à côté de chaque grandeur (dans la moyenne / un peu décalé / complètement décalé). Capteur : BME688 extérieur sous abri (§ Télémétrie).

## Changelog

### 0.1.1 — 2026-08-31

- BME688 **extérieur sous abri**. IAQ dès warmup gaz ; eCO2 client `400 + IAQ × 4` ; repli depuis `gas_resistance`.
- Install Linux / Windows, handshake USB `wantConfigId` 69420, icône Bureau.
- UF2 `seeed_wio_tracker_L1_meteo` 0.1.1 (DFU TRACKER L1).
- Client Android : Météo / Connexions / Réglages, `fr.f4eed.stationmeteo`.

### 0.1.0 — 2026-08-28 / 29

- Cible unique L1 Pro sans écran, BME688 **extérieur sous abri**, solaire / batterie.
- Quatre dépôts F4EED : `station_meteo_mini` (README), `_firmware`, `_client_web`, `_client_android`.
- Variant `seeed_wio_tracker_L1_meteo` (L1 Pro sans écran) + `WeatherAlertPolicy` 0.1.0.
- Canaux défaut : `Fr_Balise`, `Fr_EMCOM`, `Fr-BlaBla`, `Alerte` (PSK `AQ==`).
- LoRa : `ignore_mqtt` = false, `config_ok_to_mqtt` = true (userPrefs).
- `start_StMet.sh` : client web + Chromium (Web Serial / Web Bluetooth).
- Client web : USB, Bluetooth, IP ; télémétrie + réglages (plus de messagerie / nœuds / carte).
- Install Linux / Windows 10-11 : `install.sh`, `install.ps1` / `install.bat`, icône Bureau (`creer-icone.sh`).

## Historique

**2026-08-28** — Cadrage. Clone client web F4EED → `station_meteo_client_web/`. Matériel figé L1 Pro headless. Cahier des charges : seuils mini/maxi BME688, cadences 6/12/18 · 1 h · 5 min, Sensor, Gaulix, hop 3, `is_power_saving`, firmware allégé, Android plus tard.

**2026-08-29** — Firmware dans `firmware/` (pas ThinkNode). README unique à la racine. Archi GitHub : parapluie `station_meteo_mini` + trois forks. Défauts LoRa : Ignore MQTT **false**, OK to MQTT **true**. Premier UF2 `seeed_wio_tracker_L1_meteo` 0.1.0 (headless, Gaulix, seuils). Client web : USB / Web Bluetooth / IP.

**2026-08-30** — Scripts d’install du client web : Linux (`install.sh`, Chrome/Chromium apt) et Windows 10/11 (`install.ps1` / `install.bat`). Raccourci Bureau + icône (`creer-icone.sh`, `assets/`). Handshake USB sans dump NodeDB ni manifeste LittleFS. Page Météo : point de rosée + température ressentie. Heure : PC à la connexion USB, GPS si fix.

**2026-09-02** — Transit autre machine : [`TRANSIT.md`](TRANSIT.md). APK Android non produit ici (JDK 25).

**2026-09-01** — Clients web et Android : pastille vert / orange / rouge à côté de chaque grandeur (dans la moyenne / un peu décalé / complètement décalé). Bandes défaut STMET 0.1.x.

**2026-08-31** — BME688 **extérieur sous abri**. IAQ firmware dès warmup gaz (3+1 échantillons). Client : IAQ / eCO2 de repli depuis `gas_resistance` (fil en kΩ, UI en Ω). eCO2 = `400 + IAQ × 4` ppm (pas NDIR). UF2 IAQ flashé DFU `TRACKER L1`. Gaz sous abri typique 50–150 kΩ.
