# Variant `seeed_wio_tracker_L1_meteo` (MStMet)

Firmware **MStMet** (Mini Station Météo ; semver : fichier `VERSION` à la racine de `station_meteo_mini`) pour Seeed Wio Tracker **L1 Pro** sans écran, capteur Grove BME688 (`Wire1` SDA D18, SCL D17).

Cadrage complet : [`README.md`](../../../../../README.md) du dépôt `station_meteo_mini`.

**UF2 :** [release v0.1.0](https://github.com/F4EED/station_meteo_mini/releases/tag/v0.1.0) (`firmware-seeed_wio_tracker_L1_meteo-0.1.0.uf2`).

## Compiler / flasher

```bash
pio run -e seeed_wio_tracker_L1_meteo
# UF2 : .pio/build/seeed_wio_tracker_L1_meteo/firmware.uf2
# ou : pio run -e seeed_wio_tracker_L1_meteo -t upload
```

`STATION_METEO` : télémétrie environnement + batterie rétablie après factory reset Meshtastic 2.8, `is_unmessagable = false`, prefs `/prefs/station_meteo.dat`.

## Exclusions compile

Écran, Wi‑Fi, MQTT, canned messages, store & forward, ATAK, paxcounter, detection sensor, waypoint, neighbor info, traceroute, notifications externes.
