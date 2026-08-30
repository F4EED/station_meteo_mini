# Variant `seeed_wio_tracker_L1_meteo`

Firmware **mini station météo** (semver : fichier `VERSION` à la racine de `station_meteo_mini`) pour Seeed Wio Tracker **L1 Pro** sans écran, capteur Grove BME688 (`Wire1` SDA D18, SCL D17).

Cadrage complet : [`README.md`](../../../../../README.md) du dépôt `station_meteo_mini`.

## Compiler / flasher

```bash
pio run -e seeed_wio_tracker_L1_meteo
# UF2 : .pio/build/seeed_wio_tracker_L1_meteo/firmware.uf2
# ou : pio run -e seeed_wio_tracker_L1_meteo -t upload
```

`STATION_METEO` : télémétrie environnement + batterie rétablie après factory reset Meshtastic 2.8, `is_unmessagable = false`, prefs `/prefs/station_meteo.dat`.

## Exclusions compile

Écran, Wi‑Fi, MQTT, canned messages, store & forward, ATAK, paxcounter, detection sensor, waypoint, neighbor info, traceroute, notifications externes.
