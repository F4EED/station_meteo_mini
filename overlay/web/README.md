# Mini Station Meteo -Configurateur

Sources overlay du **client web** (copiées dans `station_meteo_client_web/` par `scripts/apply-station-meteo.py`).

Cadrage : [`README.md`](../../README.md) à la racine de `station_meteo_mini`. Semver : [`VERSION`](../../VERSION).

| | |
| --- | --- |
| Titre d’onglet | **Mini Station Meteo -Configurateur** (`vite.config.ts`) |
| Pages | `/meteo`, `/settings/measurement`, `/connections` |
| Module config masqué | notification externe, test de portée, message pré-enregistré, audio, lumière ambiante, paxcounter, TAK, status message |

```bash
python3 scripts/apply-station-meteo.py web
./start_StMet.sh
```
