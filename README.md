# Mini station météo Meshtastic

Station météo autonome **minimum**, sans écran, nœud LoRa unique. Version projet : **0.1.0**.

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

## Matériel

- **L1 Pro** : boîtier, batterie, entrée solaire USB-C / solaire / 3,7 V (PMIC Seeed). GPS hardware présent, **désactivé** par défaut. Grove I2C `Wire1` : SDA D18, SCL D17.
- **Pas d’écran** : ne pas flasher `seeed_wio_tracker_L1_eink` ni compter sur l’OLED du variant L1 stock (`HAS_SCREEN` / `USE_SSD1306`).
- **BME688** : adresse I2C `0x76` ou `0x77`. Driver firmware `BME680Sensor` (Adafruit BME680). Grandeurs : température °C, humidité %, pression hPa, résistance gaz Ω, IAQ 0–500 (estimateur firmware, pas BSEC Bosch).
- Tension batterie : ADC `PIN_VBAT` + `BAT_READ`, télémétrie power activée.

## Firmware

- Checkout : [`firmware/`](firmware/) — `origin` [F4EED/station_meteo_firmware](https://github.com/F4EED/station_meteo_firmware), `upstream` Meshtastic
- Branche de travail : `station-meteo`
- Env PlatformIO : `seeed_wio_tracker_L1_meteo`
- **Pas** le fork ThinkNode (`mestastic/firmware`)
- **État :** tree Meshtastic en place. Variant station, politique de seuils et UF2 **pas encore** créés.

```bash
cd firmware
pio run -e seeed_wio_tracker_L1_meteo
# Flash DFU nRF52 (UF2 / 1200 bps), pas esptool
```

Allègement **à la compile** (on ne supprime pas les variants amont) : `HAS_SCREEN=0`, `MESHTASTIC_EXCLUDE_SCREEN`, exclusions MQTT / Wi‑Fi / ATAK / canned messages / store & forward / paxcounter / detection sensor / waypoint / neighbor info / traceroute / notifs externes / air quality dédié. `lib_deps` : base nRF52 + Adafruit BME680. Conservé : LoRa, BLE, I2C, télémétrie environnement + power, admin, PKI.

Fichiers prévus : `variants/nrf52840/seeed_wio_tracker_L1_meteo/`, `src/modules/Telemetry/WeatherAlertPolicy.h`, hook `STATION_METEO` dans `EnvironmentTelemetry.cpp`. Pas d’édition de `src/mesh/generated/`.

## Paramètres Meshtastic / Gaulix (défauts)

Cibles au premier boot / factory reset. Alignées sur [Gaulix.fr](https://gaulix.fr/) V25.x sauf rôle Sensor, MQTT, GPS, télémétrie.

| Champ | Valeur |
| --- | --- |
| Rôle | `SENSOR` |
| `power.is_power_saving` | `true` (sommeil = intervalle du mode télémétrie) |
| Bluetooth | activé (client web / future app Android) |
| GPS | `DISABLED` |
| Hop | **3** (`HOP_RELIABLE`) |
| Région | `EU_868` |
| Modem preset | `LONG_MODERATE` (use preset = true) |
| Frequency slot | `1` |
| Override frequency | **869.4625 MHz** |
| Override duty cycle | `false` |
| SX126x RX boosted gain | `true` |
| Ignore MQTT | `true` |
| OK to MQTT | `false` |

Canaux (PSK `AQ==`) : **0** primary `Fr_Balise` · **1** `Fr_EMCOM` · **2** `Fr-BlaBla`. Uplink/downlink MQTT off, pas de broadcast position. Télémétrie sur `Fr_Balise`.

Télémétrie : environment measurement on, screen off, intervalle **piloté par les seuils** ; power measurement on.

Fuseau France : `CET-1CEST,M3.5.0,M10.5.0/3`. Nom long Gaulix non cuit (ex. préfixe `XXLLLLLM8SeN…`).

## Télémétrie BME688

Défauts 0.1.0, réglables plus tard par l’app. Priorité **choc > alerte > normal**. Retour à la normale dès que toutes les grandeurs présentes sont dans [mini, maxi] sans choc. Grandeur absente (`has_*` faux) ignorée (IAQ pendant burn-in aussi).

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

Sans horloge valide : mode Normal = 21600 s. `is_power_saving` reste `true` ; seul `environment_update_interval` change.

## Client web

Fork dans [`station_meteo_client_web/`](station_meteo_client_web/). Config / lecture du nœud headless en BLE ou USB. Pas d’UI onboard. Voir le README de ce dossier.

## Application Android

Clone : [`station_meteo_client_android/`](station_meteo_client_android/). Dépôt [F4EED/station_meteo_client_android](https://github.com/F4EED/station_meteo_client_android) (base Meshtastic-Android). Adaptations station (seuils, BLE headless) **pas encore** commencées. En 0.1.0 les seuils sont des constantes firmware.

## Changelog

### 0.1.0 — 2026-08-28 / 29

- Cible unique L1 Pro sans écran, BME688, solaire / batterie.
- Quatre dépôts F4EED : `station_meteo_mini` (README), `_firmware`, `_client_web`, `_client_android`.
- Variant `seeed_wio_tracker_L1_meteo` pas encore créé.

## Historique

**2026-08-28** — Cadrage. Clone client web F4EED → `station_meteo_client_web/`. Matériel figé L1 Pro headless. Cahier des charges : seuils mini/maxi BME688, cadences 6/12/18 · 1 h · 5 min, Sensor, Gaulix, hop 3, `is_power_saving`, firmware allégé, Android plus tard.

**2026-08-29** — Firmware dans `firmware/` (pas ThinkNode). README unique à la racine. Archi GitHub : parapluie `station_meteo_mini` + trois forks ; `origin` = F4EED, `upstream` = Meshtastic. Clone Android en local.
