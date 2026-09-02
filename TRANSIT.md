# Transit — reprendre la mini station météo sur une autre machine

Récupération **via GitHub** (compte [F4EED](https://github.com/F4EED)). Quatre dépôts, **pas de submodule**. Le clone Android de cette machine n’a **pas** produit d’APK (JDK 25 manquant). Continuer le client Android **là-bas**.

Date de ce transit : **2026-09-02**.

## Dépôts et branches

| Clone local | GitHub | Branche à prendre |
| --- | --- | --- |
| ce dossier (README + scripts) | [F4EED/station_meteo_mini](https://github.com/F4EED/station_meteo_mini) | `main` |
| `firmware/` | [F4EED/station_meteo_firmware](https://github.com/F4EED/station_meteo_firmware) | `station-meteo` |
| `station_meteo_client_web/` | [F4EED/station_meteo_client_web](https://github.com/F4EED/station_meteo_client_web) | `main` |
| `station_meteo_client_android/` | [F4EED/station_meteo_client_android](https://github.com/F4EED/station_meteo_client_android) | `feat/station-meteo-client` |

`origin` = F4EED. `upstream` = Meshtastic officiel (firmware, web, Android seulement).

## Cloner sur la nouvelle machine

```bash
mkdir -p ~/Dev_Cursor/mestastic
cd ~/Dev_Cursor/mestastic
git clone https://github.com/F4EED/station_meteo_mini.git "Station-météo"
cd "Station-météo"

git clone https://github.com/F4EED/station_meteo_firmware.git firmware
git -C firmware switch station-meteo

git clone https://github.com/F4EED/station_meteo_client_web.git

git clone -b feat/station-meteo-client https://github.com/F4EED/station_meteo_client_android.git
```

Sans `-b`, le clone Android retombe sur `main` (docs 0.1.1 **sans** l’écran Météo / pastilles).

Auth GitHub : `gh auth login` (compte F4EED) si push ensuite.

## État du travail (ce qui est sur GitHub après ce transit)

**Firmware 0.1.1** — déjà sur `origin/station-meteo`. Variant `seeed_wio_tracker_L1_meteo` (L1 Pro **sans écran**), BME688 Grove extérieur sous abri, IAQ / seuils. Rien de local non poussé.

**Client web** — pastilles vert / orange / rouge sur la page Météo (bandes STMET 0.1.x). Compile : `cd station_meteo_client_web/apps/web && pnpm test -- run src/core/stationMeteo && pnpm build`. Lancer : `bash start_StMet.sh` (Chrome/Chromium, Web Bluetooth / Serial).

**Client Android** — module `:feature:meteo`, nav **Météo / Connexions / Réglages**, `applicationId` `fr.f4eed.stationmeteo`, pastilles comme le web, PIN BLE **123456**. **APK non généré ici.** Gradle 9.6.1 + toolchain **JDK 25** (compile Kotlin `jvmToolchain(25)`, cible JVM 21). Sur cette machine : JDK 21 seulement → `Cannot find a Java installation … languageVersion=25`.

Ne **pas** copier `local.properties`, `keystore.properties`, `*.jks`, `assemble-fdroid-debug.log`.

## Continuer l’Android (nouvelle machine)

Besoins : JDK **25**, Android SDK (`platforms;android-36` + `android-37`, `build-tools;37.0.0`), `ANDROID_HOME`.

```bash
cd station_meteo_client_android
# local.properties : sdk.dir=…  (gitignored ; partir de secrets.defaults.properties si besoin, sans y coller de vrais secrets)
export ANDROID_HOME="$HOME/Android/Sdk" ANDROID_SDK_ROOT="$ANDROID_HOME"
./gradlew :androidApp:assembleFdroidDebug
# APK : androidApp/build/outputs/apk/fdroid/debug/
```

Symlink éventuel si le SDK n’a que `android-37.0` : `ln -s android-37.0 "$ANDROID_HOME/platforms/android-37"`.

## Matériel / défauts

Seeed Wio Tracker L1 Pro **sans écran**, BME688 I2C Grove **extérieur sous abri**. Doc des défauts LoRa / seuils : `README.md` (même dossier). PIN BLE usine : **123456** (appairer **dans** l’app, pas dans les réglages Bluetooth du téléphone).
