# Variant `seeed_wio_tracker_L1_meteo` (MStMet)

Firmware **MStMet** (Mini Station Météo ; semver : fichier `VERSION` à la racine de `station_meteo_mini`) pour Seeed Wio Tracker **L1 Pro** sans écran, capteur Grove BME688 (`Wire1` SDA D18, SCL D17).

Cadrage complet : [`README.md`](../../../../../README.md) du dépôt `station_meteo_mini`.

**UF2 :** [release v0.1.0](https://github.com/F4EED/station_meteo_mini/releases/tag/v0.1.0) (`firmware-seeed_wio_tracker_L1_meteo-0.1.0.uf2`). Compile PlatformIO `seeed_wio_tracker_L1_meteo` **SUCCESS** (2026-08-30, allégé GPS/capteurs) : RAM 40,1 %, flash 54,6 %. Nom d’affichage Meshtastic : **MStMet (Seeed Wio Tracker L1 Pro)**.

## Compiler / flasher

```bash
pio run -e seeed_wio_tracker_L1_meteo
# UF2 : .pio/build/seeed_wio_tracker_L1_meteo/firmware.uf2
# ou : pio run -e seeed_wio_tracker_L1_meteo -t upload
```

`STATION_METEO` : télémétrie environnement + batterie rétablie après factory reset Meshtastic 2.8, `is_unmessagable = false`, prefs `/prefs/station_meteo.dat`.

## Exclusions compile

Écran, GPS (L76K en standby matériel), Wi‑Fi, MQTT, canned messages, store & forward, ATAK, paxcounter, detection sensor, waypoint, neighbor info, traceroute, notifications externes, replybot, dropzone, status, remote hardware, module série, télémétrie santé, capteurs air quality, accéléro / magnéto. Capteurs I2C : **BME688 seulement**.
