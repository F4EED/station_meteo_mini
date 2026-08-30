# MStMet — Mini Station Météo

Station météo autonome **minimum**, sans écran, nœud LoRa unique. Nom d’affichage : **MStMet**. Version projet : **0.1.0** (`VERSION`).

| | |
| --- | --- |
| **Carte** | Seeed Studio Wio Tracker L1 Pro (nRF52840, SX1262, GNSS L76K) |
| **Écran** | aucun |
| **Capteur** | Bosch BME688, I2C Grove |
| **Énergie** | solaire + batterie Li-ion du L1 Pro (`power.is_power_saving`) |
| **Réseau** | Gaulix 868, rôle Sensor, hop 3 |

## Arborescence

Quatre dépôts GitHub, un clone local par composant. **Pas de submodule.**

```
Station-météo/                         →  F4EED/station_meteo_mini     (ce README)
  VERSION                              ← semver projet (source unique)
  start_StMet.sh                       ← lance le client web + Chromium
  overlay/                             ← sources station (variant, prefs, UI, README overlay)
  overlay/web/README.md                ← note client web
  overlay/web/apps/web/public/         ← logo / icône MStMet
  overlay/firmware/.../README.md       ← note variant L1 météo
  scripts/apply-station-meteo.py       ← copie l’overlay dans les clones
  firmware/                            →  F4EED/station_meteo_firmware
  station_meteo_client_web/            →  F4EED/station_meteo_client_web
  station_meteo_client_android/        →  F4EED/station_meteo_client_android
```

`firmware/`, `station_meteo_client_web/` et `station_meteo_client_android/` sont gitignorés ici : ce sont des clones séparés.

## Dépôts GitHub (F4EED)

| Dépôt | Rôle | `origin` | `upstream` |
| --- | --- | --- | --- |
| [station_meteo_mini](https://github.com/F4EED/station_meteo_mini) | README + overlay | — | — |
| [station_meteo_firmware](https://github.com/F4EED/station_meteo_firmware) | Firmware (variant L1 Pro / télémétrie) | F4EED | [meshtastic/firmware](https://github.com/meshtastic/firmware) |
| [station_meteo_client_web](https://github.com/F4EED/station_meteo_client_web) | Client web BLE / USB / IP | F4EED | [meshtastic/web](https://github.com/meshtastic/web) |
| [station_meteo_client_android](https://github.com/F4EED/station_meteo_client_android) | Client Android | F4EED | [meshtastic/Meshtastic-Android](https://github.com/meshtastic/Meshtastic-Android) |

### Cloner et appliquer l’overlay

```bash
git clone https://github.com/F4EED/station_meteo_mini.git
cd station_meteo_mini
git clone https://github.com/F4EED/station_meteo_firmware.git firmware
git clone https://github.com/F4EED/station_meteo_client_web.git
git clone https://github.com/F4EED/station_meteo_client_android.git
python3 scripts/apply-station-meteo.py all
```

Le script est idempotent. Il lit `VERSION`, injecte `STATION_METEO_VERSION` dans le variant PlatformIO, ajoute le variant `seeed_wio_tracker_L1_meteo`, la politique de seuils, les prefs persistées, et le client web (titre d’onglet **MStMet - Configurateur**, marque **MStM - Mini Station Météo** / **Via Meshtastic**, Météo / Plage de mesure / USB·BT·IP, configuration module allégée).

## Matériel

- **L1 Pro** : boîtier, batterie, entrée solaire USB-C / solaire / 3,7 V (PMIC Seeed). GPS hardware présent, **désactivé** par défaut. Grove I2C `Wire1` : SDA D18, SCL D17.
- **Pas d’écran** : ne pas flasher `seeed_wio_tracker_L1_eink` ni compter sur l’OLED du variant L1 stock (`HAS_SCREEN` / `USE_SSD1306`).
- **BME688** : adresse I2C `0x76` ou `0x77`. Driver firmware `BME680Sensor` (Adafruit BME680). Grandeurs : température °C, humidité %, pression hPa, résistance gaz Ω, IAQ 0–500, CO2 estimé ppm (`400 + IAQ × 4`, pas BSEC Bosch).
- Tension batterie : ADC `PIN_VBAT` + `BAT_READ`, télémétrie power activée.

## Firmware

- Checkout : [`firmware/`](firmware/) — `origin` [F4EED/station_meteo_firmware](https://github.com/F4EED/station_meteo_firmware), `upstream` Meshtastic
- Branche de travail : `station-meteo` (locale) ; l’overlay vit dans ce dépôt parapluie tant que le fork firmware n’a pas reçu le push.
- Env PlatformIO : `seeed_wio_tracker_L1_meteo` (`custom_meshtastic_display_name` : **MStMet (Seeed Wio Tracker L1 Pro)**)
- **Pas** le fork ThinkNode (`mestastic/firmware`)
- **État :** variant `seeed_wio_tracker_L1_meteo` (L1 Pro **sans écran**), `WeatherAlertPolicy`, `StationMeteoPrefs` (`/prefs/station_meteo.dat`), version **0.1.0**. Flash DFU nRF52 (UF2).

**UF2 précompilé :** [release GitHub v0.1.0](https://github.com/F4EED/station_meteo_mini/releases/tag/v0.1.0) — fichier `firmware-seeed_wio_tracker_L1_meteo-0.1.0.uf2`. Carte en bootloader DFU : copier le UF2. Les `.uf2` ne sont pas dans git (gitignore).

```bash
cd firmware
pio run -e seeed_wio_tracker_L1_meteo
# Carte déjà en bootloader UF2 : copier .pio/build/seeed_wio_tracker_L1_meteo/firmware*.uf2
# Sinon : pio run -e seeed_wio_tracker_L1_meteo -t upload   (1200 bps / nrfutil, pas esptool)
```

Allègement **à la compile** : `HAS_SCREEN=0`, `MESHTASTIC_EXCLUDE_SCREEN`, exclusions MQTT / Wi‑Fi / ATAK / canned messages / store & forward / paxcounter / detection sensor / waypoint / neighbor info / traceroute / notifs externes. Conservé : LoRa, BLE, I2C, télémétrie environnement + power, admin, PKI.

Fichiers overlay : `overlay/firmware/variants/nrf52840/seeed_wio_tracker_L1_meteo/` (dont un README variant), `StationMeteoPrefs`, `StationMeteoModule` (port `PRIVATE_APP`), `WeatherAlertPolicy.h`. Pas d’édition de `src/mesh/generated/`.

Pairing BLE headless : PIN fixe Meshtastic (souvent `123456`).

## Versioning

Source unique : fichier [`VERSION`](VERSION) (semver, actuellement **0.1.0**).

| Canal | Rôle |
| --- | --- |
| `VERSION` | Semver du projet mini station (firmware overlay + client web overlay) |
| Tag / release GitHub | `v0.1.0` — [releases](https://github.com/F4EED/station_meteo_mini/releases) (UF2 en asset) |
| `-D STATION_METEO_VERSION` | Injecté dans `platformio.ini` du variant par `apply-station-meteo.py` |
| `StationMeteoPrefs.version` | Version du **blob** LittleFS (entier 1 = layout 180 octets), indépendante du semver |
| Changelog ci-dessous | Notes de release |

Pour bump : éditer `VERSION`, relancer `python3 scripts/apply-station-meteo.py all`, mettre à jour ce README (en-tête + changelog), tagger `vX.Y.Z` et publier une [release](https://github.com/F4EED/station_meteo_mini/releases) avec le nouvel UF2.

## Factory reset et télémétrie (Meshtastic 2.8)

Les défauts `userPrefs` s’appliquent au **premier boot** et après **factory reset** seulement.

Un factory reset USB (nœud sans écran) :

```bash
meshtastic --port /dev/ttyACM0 --factory-reset
```

Bug corrigé dans l’overlay : Meshtastic 2.8 pose un watermark `POSITION_TELEMETRY_OPTIN_VER` (26) **au-dessus** de `DEVICESTATE_CUR_VER` (25). Au reboot après reset, la migration opt-in **éteint** environment + power. Pour `STATION_METEO`, l’overlay les **rallume** juste après cette migration (et à l’install des moduleConfig). Sans cet overlay, il fallait `meshtastic --set telemetry.environment_measurement_enabled true`.

## Paramètres Meshtastic / Gaulix (défauts)

Cibles au premier boot / factory reset. Alignées sur [Gaulix.fr](https://gaulix.fr/) V25.x sauf rôle Sensor, GPS, télémétrie.

| Champ | Valeur |
| --- | --- |
| Rôle | `SENSOR` |
| `owner.is_unmessagable` | **`false`** (STATION_METEO ; le rôle SENSOR stock force `true`) |
| `power.is_power_saving` | `true` (sommeil = intervalle du mode télémétrie) |
| Bluetooth | activé, PIN fixe `123456` |
| GPS | `DISABLED` |
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

Fuseau France : `CET-1CEST,M3.5.0,M10.5.0/3`. Nom long cuit (premier boot / factory reset) : `42METOLM8Sensor- mini st`. Demandé `42METOLM8Sensor- mini station météo (developpement)` (53 octets UTF-8) : tronqué à **24 octets** (`MAX_LONG_NAME_BYTES` ; le tampon protobuf reste 40). Pas de short name usine (max 4 octets).

## Télémétrie BME688 / plage de mesure

Défauts 0.1.0, réglables dans le client (**Réglages → Plage de mesure**), persistés sur le nœud (`/prefs/station_meteo.dat`). Priorité **choc > alerte > normal**. Grandeur absente (`has_*` faux) ignorée.

| Paramètre | Moyenne | Basse | Haute | Très bas | Bas | Haut | Très haut |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Température °C | 15 | −10 | 40 | −20 | 0 | 35 | 45 |
| Humidité % | 55 | 20 | 90 | 10 | 30 | 80 | 95 |
| Pression hPa | 1013 | 980 | 1040 | 960 | 990 | 1030 | 1050 |
| Résistance gaz Ω | 5×10⁴ | 5 000 | 1,0×10⁷ | 1 000 | 1×10⁴ | 5×10⁶ | 2×10⁷ |
| IAQ 0–500 | 50 | 0 | 150 | 0 | 25 | 100 | 200 |
| CO2 estimé ppm | 600 | 400 | 1500 | 350 | 500 | 1000 | 2000 |

Choc (Δ vs échantillon précédent) : 3 °C, 15 points RH, 5 hPa, 30 % gaz, 50 IAQ, 200 ppm CO2.

| Mode | Condition | Intervalle / sommeil |
| --- | --- | --- |
| Normal | dans [basse, haute] | créneaux **06:00, 12:00, 18:00** locale |
| Alerte | hors basse/haute | **3600 s** |
| Choc | variation brutale vs échantillon précédent | **300 s** |

Sans horloge valide : mode Normal = 21600 s. `is_power_saving` reste `true` ; seul `environment_update_interval` change.

## Client web

Fork dans [`station_meteo_client_web/`](station_meteo_client_web/). Client **simplifié** : télémétrie BME688 / batterie, réglages + **Plage de mesure**. Messagerie / nœuds / carte restent dans le code mais hors navigation.

Titre d’onglet du navigateur : **MStMet - Configurateur**.

Marque dans la barre latérale (à la place de « Meshtastic ») :
1. **MStM - Mini Station Météo**
2. **Via Meshtastic**

Logo / icône : pictogramme de **point de relevé** (mini station : abri Stevenson, panneau solaire, antenne LoRa, soleil) — `logo.svg` dans la barre, `icon.svg` / `favicon.ico` / `apple-touch-icon.png` pour l’onglet et le PWA.

**Réglages → Configuration du module** — onglets **conservés** : MQTT, série, store & forward, télémétrie, voisinage, capteur de détection, matériel distant, trafic. **Masqués** : notification externe, test de portée, message pré-enregistré, audio, lumière ambiante, paxcounter, TAK, status message. Les fichiers upstream des modules restent ; le script d’apply filtre la liste. Sur le firmware `seeed_wio_tracker_L1_meteo`, MQTT / store-forward / voisinage / détection sont aussi exclus à la compile : les onglets UI correspondants ne pilotent rien sur ce nœud.

Connexions (Chromium, `./start_StMet.sh`) :

| Onglet | API |
| --- | --- |
| **USB** | Web Serial |
| **Bluetooth** | Web Bluetooth |
| **IP** | HTTP(S) |

Sans nœud branché, **Météo**, **Réglages → Plage de mesure** et la liste d’onglets **Configuration du module** restent consultables (valeurs `—`, bouton **Connecter** ; formulaires module vides tant qu’un nœud n’est pas lié). USB / Bluetooth ne marchent que dans Chromium **sur la machine où la carte est branchée**.

### Lancer

```bash
./start_StMet.sh
```

- Démarre Vite (`pnpm --filter meshtastic-web dev`) sur **http://127.0.0.1:5173/**
- Écoute `0.0.0.0` par défaut (accès Cursor / LAN) ; l’URL affichée reste le loopback
- Ouvre **Chromium** (flags Web Bluetooth + Web Serial) sur cette URL

| Variable | Effet |
| --- | --- |
| `STMET_NO_BROWSER=1` | Serveur seul, pas de Chromium |
| `STMET_PORT` | Port (défaut `5173`) |
| `STMET_HOST` | Hôte de l’URL / health-check (défaut `127.0.0.1`) |
| `STMET_BIND` | Interface d’écoute Vite (défaut `0.0.0.0`) |

Le navigateur intégré de Cursor n’expose pas Web Serial / Web Bluetooth.

## Application Android

Clone : [`station_meteo_client_android/`](station_meteo_client_android/). Adaptations station (seuils, BLE headless) **pas encore** commencées.

## Changelog

### 0.1.0 — 2026-08-28 / 30

- Cible unique L1 Pro sans écran, BME688, solaire / batterie.
- Quatre dépôts F4EED : `station_meteo_mini` (README + overlay), `_firmware`, `_client_web`, `_client_android`.
- Variant `seeed_wio_tracker_L1_meteo` + `WeatherAlertPolicy` + `StationMeteoPrefs`.
- Canaux défaut : `Fr_Balise`, `Fr_EMCOM`, `Fr-BlaBla`, `Alerte` (PSK `AQ==`).
- LoRa : `ignore_mqtt` = false, `config_ok_to_mqtt` = true.
- Factory reset 2.8 : télémétrie environnement + batterie rétablie (`STATION_METEO`).
- `start_StMet.sh` : client web + Chromium (Web Serial / Web Bluetooth).
- Client web : USB, Bluetooth, IP ; Météo + Plage de mesure.
- Client web : titre d’onglet **MStMet - Configurateur** ; marque **MStM - Mini Station Météo** / **Via Meshtastic** ; logo mini station ; configuration module sans notif externe / portée / canned / audio / lumière / paxcounter / TAK / status.
- Météo / Réglages consultables sans nœud ; versioning via fichier `VERSION`.
- Firmware `seeed_wio_tracker_L1_meteo` : compile PlatformIO **SUCCESS** (revérifié 2026-08-30 après rebrand MStMet) ; UF2 publié en [release v0.1.0](https://github.com/F4EED/station_meteo_mini/releases/tag/v0.1.0).

## Historique

**2026-08-28** — Cadrage. Clone client web F4EED → `station_meteo_client_web/`. Matériel figé L1 Pro headless.

**2026-08-29** — Firmware dans `firmware/` (pas ThinkNode). Premier UF2 flashé. Client web USB / Web Bluetooth / IP.

**2026-08-30** — Factory reset USB. Correctif télémétrie opt-in 2.8. Overlay versionné dans `station_meteo_mini`. Client web **MStMet** : titre **MStMet - Configurateur** ; marque **MStM - Mini Station Météo** / **Via Meshtastic** ; logo / icône point de relevé (mini station) ; configuration module allégée ; Météo / Réglages sans nœud. Semver `VERSION` **0.1.0**. Firmware `seeed_wio_tracker_L1_meteo` : compile PlatformIO **SUCCESS** (RAM 40,7 %, flash 71,7 %). [Release GitHub v0.1.0](https://github.com/F4EED/station_meteo_mini/releases/tag/v0.1.0) (UF2).
