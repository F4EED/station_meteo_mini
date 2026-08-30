#!/usr/bin/env python3
"""Applique l'overlay station météo sur des clones firmware / client web.

Usage (depuis la racine station_meteo_mini) :

    python3 scripts/apply-station-meteo.py firmware
    python3 scripts/apply-station-meteo.py web
    python3 scripts/apply-station-meteo.py all
"""

from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OVERLAY = ROOT / "overlay"


def project_version() -> str:
    path = ROOT / "VERSION"
    if not path.is_file():
        raise SystemExit("fichier VERSION manquant à la racine")
    ver = path.read_text(encoding="utf-8").strip().splitlines()[0].strip()
    if not ver:
        raise SystemExit("VERSION vide")
    return ver


def inject_station_meteo_version(ini: Path, ver: str) -> None:
    text = ini.read_text(encoding="utf-8")
    updated, n = re.subn(
        r'-D STATION_METEO_VERSION=\\"[^"]*\\"',
        f'-D STATION_METEO_VERSION=\\"{ver}\\"',
        text,
        count=1,
    )
    if n == 0:
        raise SystemExit(f"STATION_METEO_VERSION introuvable dans {ini}")
    if updated != text:
        ini.write_text(updated, encoding="utf-8")
        print(f"  version firmware {ver} → {ini}")
    else:
        print(f"  skip (version déjà {ver}) {ini.name}")


def _replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        print(f"  skip (déjà appliqué) {label}")
        return
    if old not in text:
        raise SystemExit(f"motif introuvable dans {path} ({label})")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"  patch {label}")


def _replace_first(
    path: Path, pairs: list[tuple[str, str]], label: str
) -> None:
    text = path.read_text(encoding="utf-8")
    for old, new in pairs:
        if new in text:
            print(f"  skip (déjà appliqué) {label}")
            return
        if old in text:
            path.write_text(text.replace(old, new, 1), encoding="utf-8")
            print(f"  patch {label}")
            return
    raise SystemExit(f"motif introuvable dans {path} ({label})")


def _copy_tree(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.is_dir():
        shutil.copytree(src, dest, dirs_exist_ok=True)
    else:
        shutil.copy2(src, dest)
    print(f"  copy {src.relative_to(OVERLAY)} → {dest}")


def _prepend_once(path: Path, marker: str, block: str, label: str) -> None:
    if not path.is_file():
        print(f"  skip (absent) {label}")
        return
    text = path.read_text(encoding="utf-8")
    if marker in text:
        print(f"  skip (déjà appliqué) {label}")
        return
    path.write_text(block + text, encoding="utf-8")
    print(f"  prepend {label}")


FIRMWARE_README_BANNER = """<!-- STATION_METEO -->
# Mini station météo (overlay)

Clone firmware pour la **mini station météo** (Seeed Wio Tracker L1 Pro headless, BME688).

- Env PlatformIO : `seeed_wio_tracker_L1_meteo`
- Détail variant : [`variants/nrf52840/seeed_wio_tracker_L1_meteo/README.md`](variants/nrf52840/seeed_wio_tracker_L1_meteo/README.md)
- Cadrage projet : [`../README.md`](../README.md) (`station_meteo_mini`)
- Appliquer l’overlay : `python3 ../scripts/apply-station-meteo.py firmware`

Le texte Meshtastic officiel suit.

<!-- /STATION_METEO -->

"""

WEB_README_BANNER = """<!-- STATION_METEO -->
# Mini Station Meteo -Configurateur

Fork **station météo** du client Meshtastic web (overlay `station_meteo_mini`).

| | |
| --- | --- |
| **Onglet navigateur** | Mini Station Meteo -Configurateur |
| **Nav** | Météo · Réglages (Plage de mesure) |
| **Connexions** | USB · Bluetooth · IP |
| **Lancer** | depuis le parapluie : `./start_StMet.sh` → http://127.0.0.1:5173/ |

**Configuration du module** — masqués : notification externe, test de portée, message pré-enregistré, audio, lumière ambiante, paxcounter, TAK, status message.

Cadrage : [`../README.md`](../README.md). Appliquer : `python3 ../scripts/apply-station-meteo.py web`.

Le README Meshtastic officiel suit.

<!-- /STATION_METEO -->

"""

WEB_APPS_README_BANNER = """<!-- STATION_METEO -->
# Mini Station Meteo -Configurateur

App web station météo. Titre d’onglet Vite : **Mini Station Meteo -Configurateur**.

Lancer : `pnpm --filter meshtastic-web dev --host 0.0.0.0 --port 5173`  
ou `./start_StMet.sh` depuis `station_meteo_mini`.

Cadrage : [`../../../README.md`](../../../README.md).

<!-- /STATION_METEO -->

"""



def apply_firmware(fw: Path) -> None:
    if not (fw / "src/mesh/NodeDB.cpp").is_file():
        raise SystemExit(f"pas un clone firmware : {fw}")

    src_overlay = OVERLAY / "firmware"
    _copy_tree(
        src_overlay / "variants/nrf52840/seeed_wio_tracker_L1_meteo",
        fw / "variants/nrf52840/seeed_wio_tracker_L1_meteo",
    )
    ver = project_version()
    inject_station_meteo_version(
        OVERLAY / "firmware/variants/nrf52840/seeed_wio_tracker_L1_meteo/platformio.ini",
        ver,
    )
    inject_station_meteo_version(
        fw / "variants/nrf52840/seeed_wio_tracker_L1_meteo/platformio.ini",
        ver,
    )
    for name in (
        "StationMeteoPrefs.h",
        "StationMeteoPrefs.cpp",
        "StationMeteoModule.h",
        "StationMeteoModule.cpp",
        "WeatherAlertPolicy.h",
    ):
        _copy_tree(
            src_overlay / "src/modules/Telemetry" / name,
            fw / "src/modules/Telemetry" / name,
        )

    nodedb = fw / "src/mesh/NodeDB.cpp"
    _replace_once(
        nodedb,
        "    config.lora.config_ok_to_mqtt = false;",
        """    config.lora.config_ok_to_mqtt = false;
#ifdef STATION_METEO
    config.lora.config_ok_to_mqtt = true;
#endif""",
        "NodeDB ok_to_mqtt",
    )
    _replace_once(
        nodedb,
        """    } else if (role == meshtastic_Config_DeviceConfig_Role_SENSOR) {
        owner.has_is_unmessagable = true;
        owner.is_unmessagable = true;
        moduleConfig.telemetry.device_update_interval = default_telemetry_broadcast_interval_secs;
        moduleConfig.telemetry.environment_measurement_enabled = true;
        moduleConfig.telemetry.environment_update_interval = 300;""",
        """    } else if (role == meshtastic_Config_DeviceConfig_Role_SENSOR) {
        owner.has_is_unmessagable = true;
#ifdef STATION_METEO
        owner.is_unmessagable = false;
#else
        owner.is_unmessagable = true;
#endif
        moduleConfig.telemetry.device_update_interval = default_telemetry_broadcast_interval_secs;
        moduleConfig.telemetry.environment_measurement_enabled = true;
        moduleConfig.telemetry.environment_update_interval = 300;
#ifdef STATION_METEO
        moduleConfig.telemetry.power_measurement_enabled = true;
        moduleConfig.telemetry.environment_screen_enabled = false;
#endif""",
        "NodeDB SENSOR unmessagable + power",
    )
    _replace_once(
        nodedb,
        """    if (moduleConfig.version < POSITION_TELEMETRY_OPTIN_VER) {
        LOG_INFO("Opt-in migration: forcing device telemetry broadcast to opt-in");
        optInDisableTelemetryBroadcast(moduleConfig);
        moduleConfig.version = POSITION_TELEMETRY_OPTIN_VER;
        saveToDisk(SEGMENT_MODULECONFIG);
    }""",
        """    if (moduleConfig.version < POSITION_TELEMETRY_OPTIN_VER) {
        LOG_INFO("Opt-in migration: forcing device telemetry broadcast to opt-in");
        optInDisableTelemetryBroadcast(moduleConfig);
#ifdef STATION_METEO
        // La migration 2.8 éteint la télémétrie (watermark 26 > DEVICESTATE 25).
        // Une station météo SENSOR doit rester en mesure environnement + batterie.
        moduleConfig.telemetry.environment_measurement_enabled = true;
        moduleConfig.telemetry.power_measurement_enabled = true;
        moduleConfig.telemetry.environment_screen_enabled = false;
#endif
        moduleConfig.version = POSITION_TELEMETRY_OPTIN_VER;
        saveToDisk(SEGMENT_MODULECONFIG);
    }""",
        "NodeDB opt-in telemetry restore",
    )
    _replace_once(
        nodedb,
        """    initModuleConfigIntervals();
}""",
        """    initModuleConfigIntervals();
#ifdef STATION_METEO
    moduleConfig.telemetry.environment_measurement_enabled = true;
    moduleConfig.telemetry.power_measurement_enabled = true;
    moduleConfig.telemetry.environment_screen_enabled = false;
#endif
}""",
        "NodeDB installDefaultModuleConfig telemetry",
    )

    env_cpp = fw / "src/modules/Telemetry/EnvironmentTelemetry.cpp"
    _replace_once(
        env_cpp,
        '#include <OLEDDisplay.h>\n',
        """#include <OLEDDisplay.h>
#ifdef STATION_METEO
#include "WeatherAlertPolicy.h"
#endif
""",
        "EnvironmentTelemetry include",
    )
    _replace_once(
        env_cpp,
        """        for (TelemetrySensor *sensor : sensors) {
            uint32_t delay = sensor->runOnce();
            if (delay < result) {
                result = delay;
            }
        }

        uint32_t lastTelemetry =""",
        """        for (TelemetrySensor *sensor : sensors) {
            uint32_t delay = sensor->runOnce();
            if (delay < result) {
                result = delay;
            }
        }
#ifdef STATION_METEO
        {
            meshtastic_Telemetry sample = meshtastic_Telemetry_init_zero;
            if (getEnvironmentTelemetry(&sample)) {
                WeatherAlertPolicy::apply(sample.variant.environment_metrics);
            }
        }
#endif

        uint32_t lastTelemetry =""",
        "EnvironmentTelemetry policy hook",
    )

    modules = fw / "src/modules/Modules.cpp"
    _replace_once(
        modules,
        '#include "modules/Telemetry/EnvironmentTelemetry.h"\n',
        """#include "modules/Telemetry/EnvironmentTelemetry.h"
#ifdef STATION_METEO
#include "modules/Telemetry/StationMeteoModule.h"
#endif
""",
        "Modules.cpp include",
    )
    _replace_once(
        modules,
        """    if (moduleConfig.has_telemetry &&
        (moduleConfig.telemetry.environment_measurement_enabled || moduleConfig.telemetry.environment_screen_enabled)) {
        new EnvironmentTelemetryModule();
    }""",
        """    if (moduleConfig.has_telemetry &&
        (moduleConfig.telemetry.environment_measurement_enabled || moduleConfig.telemetry.environment_screen_enabled)) {
        new EnvironmentTelemetryModule();
    }
#ifdef STATION_METEO
    else {
        new EnvironmentTelemetryModule();
    }
    new StationMeteoModule();
#endif""",
        "Modules.cpp instantiate",
    )

    channels = fw / "src/mesh/Channels.cpp"
    _replace_once(
        channels,
        """#ifdef USERPREFS_CHANNEL_2_DOWNLINK_ENABLED
        channelSettings.downlink_enabled = USERPREFS_CHANNEL_2_DOWNLINK_ENABLED;
#endif
        break;
    default:
        break;""",
        """#ifdef USERPREFS_CHANNEL_2_DOWNLINK_ENABLED
        channelSettings.downlink_enabled = USERPREFS_CHANNEL_2_DOWNLINK_ENABLED;
#endif
        break;
    case 3:
#ifdef USERPREFS_CHANNEL_3_PSK
        static const uint8_t defaultpsk3[] = USERPREFS_CHANNEL_3_PSK;
        memcpy(channelSettings.psk.bytes, defaultpsk3, sizeof(defaultpsk3));
        channelSettings.psk.size = sizeof(defaultpsk3);
#endif
#ifdef USERPREFS_CHANNEL_3_NAME
        strcpy(channelSettings.name, (const char *)USERPREFS_CHANNEL_3_NAME);
#endif
#ifdef USERPREFS_CHANNEL_3_PRECISION
        channelSettings.module_settings.position_precision = USERPREFS_CHANNEL_3_PRECISION;
#endif
#ifdef USERPREFS_CHANNEL_3_UPLINK_ENABLED
        channelSettings.uplink_enabled = USERPREFS_CHANNEL_3_UPLINK_ENABLED;
#endif
#ifdef USERPREFS_CHANNEL_3_DOWNLINK_ENABLED
        channelSettings.downlink_enabled = USERPREFS_CHANNEL_3_DOWNLINK_ENABLED;
#endif
        break;
    default:
        break;""",
        "Channels.cpp index 3 Alerte",
    )

    merge_userprefs(fw / "userPrefs.jsonc")
    _prepend_once(
        fw / "README.md",
        "<!-- STATION_METEO -->",
        FIRMWARE_README_BANNER,
        "firmware README banner",
    )
    print("firmware overlay OK")


STATION_USERPREFS = {
    "USERPREFS_CHANNELS_TO_WRITE": "4",
    "USERPREFS_CHANNEL_0_DOWNLINK_ENABLED": "false",
    "USERPREFS_CHANNEL_0_IS_MUTED": "false",
    "USERPREFS_CHANNEL_0_NAME": "Fr_Balise",
    "USERPREFS_CHANNEL_0_PRECISION": "0",
    "USERPREFS_CHANNEL_0_PSK": "{ 0x01 }",
    "USERPREFS_CHANNEL_0_UPLINK_ENABLED": "false",
    "USERPREFS_CHANNEL_1_DOWNLINK_ENABLED": "false",
    "USERPREFS_CHANNEL_1_IS_MUTED": "false",
    "USERPREFS_CHANNEL_1_NAME": "Fr_EMCOM",
    "USERPREFS_CHANNEL_1_PRECISION": "0",
    "USERPREFS_CHANNEL_1_PSK": "{ 0x01 }",
    "USERPREFS_CHANNEL_1_UPLINK_ENABLED": "false",
    "USERPREFS_CHANNEL_2_DOWNLINK_ENABLED": "false",
    "USERPREFS_CHANNEL_2_IS_MUTED": "false",
    "USERPREFS_CHANNEL_2_NAME": "Fr-BlaBla",
    "USERPREFS_CHANNEL_2_PRECISION": "0",
    "USERPREFS_CHANNEL_2_PSK": "{ 0x01 }",
    "USERPREFS_CHANNEL_2_UPLINK_ENABLED": "false",
    "USERPREFS_CHANNEL_3_DOWNLINK_ENABLED": "false",
    "USERPREFS_CHANNEL_3_IS_MUTED": "false",
    "USERPREFS_CHANNEL_3_NAME": "Alerte",
    "USERPREFS_CHANNEL_3_PRECISION": "0",
    "USERPREFS_CHANNEL_3_PSK": "{ 0x01 }",
    "USERPREFS_CHANNEL_3_UPLINK_ENABLED": "false",
    "USERPREFS_CONFIG_GPS_MODE": "meshtastic_Config_PositionConfig_GpsMode_DISABLED",
    "USERPREFS_CONFIG_LORA_IGNORE_MQTT": "false",
    "USERPREFS_CONFIG_LORA_REGION": "meshtastic_Config_LoRaConfig_RegionCode_EU_868",
    "USERPREFS_CONFIG_OWNER_LONG_NAME": "42METOLM8Sensor- mini st",
    "USERPREFS_CONFIG_DEVICE_ROLE": "meshtastic_Config_DeviceConfig_Role_SENSOR",
    "USERPREFS_CONFIG_SMART_POSITION_ENABLED": "false",
    "USERPREFS_CONFIG_ENVIRONMENT_MEASUREMENT_ENABLED": "1",
    "USERPREFS_CONFIG_ENV_SCREEN_SCREEN_ENABLED": "false",
    "USERPREFS_LORACONFIG_CHANNEL_NUM": "1",
    "USERPREFS_LORACONFIG_USE_PRESET": "true",
    "USERPREFS_LORACONFIG_MODEM_PRESET": "meshtastic_Config_LoRaConfig_ModemPreset_LONG_MODERATE",
    "USERPREFS_LORACONFIG_OVERRIDE_FREQUENCY": "869.4625",
    "USERPREFS_TZ_STRING": "CET-1CEST,M3.5.0,M10.5.0/3",
}


def merge_userprefs(path: Path) -> None:
    import re

    raw = path.read_text(encoding="utf-8")
    for key, value in STATION_USERPREFS.items():
        quoted = json.dumps(value)
        line = f'  "{key}": {quoted},'
        pattern = re.compile(
            rf'^[ \t]*(?://[ \t]*)?"{re.escape(key)}"\s*:.*$', re.M
        )
        if pattern.search(raw):
            raw = pattern.sub(line, raw, count=1)
        elif f'"{key}"' not in raw:
            raw = raw.replace("{", "{\n" + line, 1)
    raw = re.sub(r",\s*}\s*$", "\n}\n", raw)
    path.write_text(raw, encoding="utf-8")
    print("  merge userPrefs.jsonc")


def _patch_json(path: Path, mutator) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    mutator(data)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"  json {path.name}")


def apply_web(web: Path) -> None:
    routes = web / "apps/web/src/routes.tsx"
    if not routes.is_file():
        raise SystemExit(f"pas un clone client web : {web}")

    src = OVERLAY / "web"
    _copy_tree(
        src / "apps/web/src/core/stationMeteo",
        web / "apps/web/src/core/stationMeteo",
    )
    _copy_tree(
        src / "apps/web/src/pages/Meteo",
        web / "apps/web/src/pages/Meteo",
    )
    _copy_tree(
        src / "apps/web/src/pages/Settings/MeasurementRange.tsx",
        web / "apps/web/src/pages/Settings/MeasurementRange.tsx",
    )

    _replace_once(
        web / "apps/web/src/core/stores/deviceStore/types.ts",
        'type Page = "messages" | "map" | "settings" | "channels" | "nodes";',
        'type Page = "messages" | "map" | "settings" | "channels" | "nodes" | "meteo";',
        "Page type meteo",
    )

    _replace_once(
        routes,
        '    return redirect({ to: "/messages/broadcast/0", replace: true });',
        '    return redirect({ to: "/meteo", replace: true });',
        "index redirect /meteo",
    )
    _replace_once(
        routes,
        'import ConfigPage from "@pages/Settings/index.tsx";',
        """import ConfigPage from "@pages/Settings/index.tsx";
import MeteoPage from "@pages/Meteo/index.tsx";""",
        "routes import Meteo",
    )
    _replace_once(
        routes,
        """export const moduleRoute = createRoute({
  getParentRoute: () => settingsRoute,
  path: "module",
  component: ConfigPage,
});""",
        """export const moduleRoute = createRoute({
  getParentRoute: () => settingsRoute,
  path: "module",
  component: ConfigPage,
});

export const measurementRoute = createRoute({
  getParentRoute: () => settingsRoute,
  path: "measurement",
  component: ConfigPage,
});

const meteoRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/meteo",
  component: MeteoPage,
});""",
        "routes measurement + meteo",
    )
    _replace_once(
        routes,
        "  settingsRoute.addChildren([radioRoute, deviceRoute, moduleRoute]),",
        "  settingsRoute.addChildren([radioRoute, deviceRoute, moduleRoute, measurementRoute]),\n  meteoRoute,",
        "routeTree children",
    )

    settings = web / "apps/web/src/pages/Settings/index.tsx"
    _replace_once(
        settings,
        'import { deviceRoute, moduleRoute, radioRoute } from "@app/routes";',
        'import { deviceRoute, measurementRoute, moduleRoute, radioRoute } from "@app/routes";',
        "settings import measurementRoute",
    )
    _replace_once(
        settings,
        'import { RadioConfig } from "./RadioConfig.tsx";',
        """import { RadioConfig } from "./RadioConfig.tsx";
import { MeasurementRange } from "@pages/Settings/MeasurementRange.tsx";""",
        "settings import MeasurementRange",
    )
    _replace_once(
        settings,
        """      {
        key: "module",
        route: moduleRoute,
        label: t("navigation.moduleConfig"),
        icon: LayersIcon,
        changeCount: channelChangeCount,
        component: ModuleConfig,
      },""",
        """      {
        key: "module",
        route: moduleRoute,
        label: t("navigation.moduleConfig"),
        icon: LayersIcon,
        changeCount: channelChangeCount,
        component: ModuleConfig,
      },
      {
        key: "measurement",
        route: measurementRoute,
        label: t("navigation.measurementRange"),
        icon: LayersIcon,
        changeCount: 0,
        component: MeasurementRange,
      },""",
        "settings section Plage de mesure",
    )

    sidebar = web / "apps/web/src/components/Sidebar.tsx"
    _replace_once(
        sidebar,
        """  const pages: NavLink[] = [
    {
      name: t("navigation.messages"),
      icon: MessageSquareIcon,
      page: "messages",
      count: numUnread ? numUnread : undefined,
    },
    {
      name: `${t("navigation.nodes")} (${displayedNodeCount})`,
      icon: UsersIcon,
      page: "nodes",
    },
    {
      name: t("navigation.map"),
      icon: MapIcon,
      page: "map",
    },
    {
      name: t("navigation.settings"),
      icon: SettingsIcon,
      page: "settings",
    },
  ];""",
        """  const pages: NavLink[] = [
    {
      name: t("navigation.meteo"),
      icon: CloudSun,
      page: "meteo",
    },
    {
      name: t("navigation.settings"),
      icon: SettingsIcon,
      page: "settings",
    },
  ];""",
        "sidebar nav",
    )
    _replace_first(
        sidebar,
        [
            (
                """  MapIcon,
  MessageSquareIcon,
  SettingsIcon,
  UsersIcon,
} from "lucide-react";""",
                """  Cable,
  CloudSun,
  SettingsIcon,
} from "lucide-react";""",
            ),
            (
                """  CloudSun,
  SettingsIcon,
} from "lucide-react";""",
                """  Cable,
  CloudSun,
  SettingsIcon,
} from "lucide-react";""",
            ),
        ],
        "sidebar icons",
    )
    _replace_once(
        sidebar,
        """              onClick={() => {
                if (myNode !== undefined) {
                  navigate({ to: `/${link.page}` });
                }
              }}
              active={link.page === pathname}
              disabled={myNode === undefined}""",
        """              onClick={() => {
                navigate({ to: `/${link.page}` });
              }}
              active={
                pathname === link.page || pathname.startsWith(`${link.page}/`)
              }
              disabled={false}""",
        "sidebar nav without node",
    )
    _replace_once(
        sidebar,
        """        {myNode === undefined ? (
          <div className="flex flex-col items-center justify-center py-6">
            <Spinner />
            <Subtle
              className={cn(
                "mt-4 transition-opacity duration-300",
                isCollapsed ? "opacity-0 invisible" : "opacity-100 visible",
              )}
            >
              {t("loading")}
            </Subtle>
          </div>
        ) : (""",
        """        {myNode === undefined ? (
          <div className="flex flex-col items-center justify-center py-6 px-2 gap-2">
            <button
              type="button"
              className="inline-flex items-center gap-2 rounded-md bg-slate-900 px-3 py-2 text-sm text-white dark:bg-slate-50 dark:text-slate-900"
              onClick={() => navigate({ to: "/connections" })}
            >
              <Cable size={16} />
              {t("navigation.connect")}
            </button>
          </div>
        ) : (""",
        "sidebar connect button",
    )
    _replace_once(
        sidebar,
        """  const { metadata, setDialogOpen } = useDevice();
  const numUnread = useTotalUnread();
  const allNodes = useNodesAsProto();
  const { setCommandPaletteOpen } = useAppStore();
  const myNode = useMyNodeAsProto();""",
        """  const { deviceId } = useDeviceContext();
  const device = useDeviceStore((s) => s.getDevice(deviceId));
  const allNodes = useNodesAsProto();
  const { setCommandPaletteOpen } = useAppStore();
  const myNode = useMyNodeAsProto();""",
        "sidebar no auto-create device",
    )
    _replace_once(
        sidebar,
        """import {
  type Page,
  useActiveConnection,
  useAppStore,
  useDefaultConnection,
  useDevice,
  useSidebar,
} from "@core/stores";
import { cn } from "@core/utils/cn.ts";
import { useTotalUnread } from "@meshtastic/sdk-react";""",
        """import {
  type Page,
  useActiveConnection,
  useAppStore,
  useDefaultConnection,
  useDeviceContext,
  useDeviceStore,
  useSidebar,
} from "@core/stores";
import { cn } from "@core/utils/cn.ts";""",
        "sidebar optional device imports",
    )
    _replace_once(
        sidebar,
        "  const myMetadata = metadata.get(0);",
        "  const myMetadata = device?.metadata.get(0);",
        "sidebar optional metadata",
    )
    _replace_once(
        sidebar,
        '            setDialogOpen={() => setDialogOpen("deviceName", true)}',
        '            setDialogOpen={() => device?.setDialogOpen("deviceName", true)}',
        "sidebar optional setDialogOpen",
    )
    _replace_once(
        sidebar,
        """import { SidebarButton } from "@components/UI/Sidebar/SidebarButton.tsx";
import { SidebarSection } from "@components/UI/Sidebar/SidebarSection.tsx";
import { Spinner } from "@components/UI/Spinner.tsx";
import { Subtle } from "@components/UI/Typography/Subtle.tsx";
""",
        """import { SidebarButton } from "@components/UI/Sidebar/SidebarButton.tsx";
import { SidebarSection } from "@components/UI/Sidebar/SidebarSection.tsx";
""",
        "sidebar unused spinner/subtle",
    )

    app = web / "apps/web/src/App.tsx"
    _replace_once(
        app,
        """import { ErrorPage } from "@components/UI/ErrorPage.tsx";
import Footer from "@components/UI/Footer.tsx";
import { useTheme } from "@core/hooks/useTheme.ts";
import { SidebarProvider, useAppStore, useDeviceStore } from "@core/stores";
import { Connections } from "@pages/Connections/index.tsx";
import { Outlet } from "@tanstack/react-router";
import { TanStackRouterDevtools } from "@tanstack/react-router-devtools";
import { ErrorBoundary } from "react-error-boundary";
import { MapProvider } from "react-map-gl/maplibre";

export function App() {
  useTheme();

  const { getDevice } = useDeviceStore();
  const { selectedDeviceId } = useAppStore();

  const device = getDevice(selectedDeviceId);""",
        """import { ErrorPage } from "@components/UI/ErrorPage.tsx";
import { useTheme } from "@core/hooks/useTheme.ts";
import { SidebarProvider, useAppStore, useDeviceStore } from "@core/stores";
import { useActiveClient } from "@meshtastic/sdk-react";
import { Outlet } from "@tanstack/react-router";
import { TanStackRouterDevtools } from "@tanstack/react-router-devtools";
import { ErrorBoundary } from "react-error-boundary";
import { MapProvider } from "react-map-gl/maplibre";

export function App() {
  useTheme();

  const { getDevice } = useDeviceStore();
  const { selectedDeviceId } = useAppStore();
  const client = useActiveClient();

  const device = getDevice(selectedDeviceId);""",
        "App imports + client hook",
    )
    _replace_first(
        app,
        [
            (
                """              {device ? (
                <div className="h-full flex w-full">
                  <DialogManager />
                  <KeyBackupReminder />
                  <RegionSetupReminder />
                  <CommandPalette />
                  <MapProvider>
                    <Outlet />
                  </MapProvider>
                </div>
              ) : (
                <>
                  <Connections />
                  <Footer />
                </>
              )}""",
                """              <div className="h-full flex w-full">
                {device && client ? (
                  <>
                    <DialogManager />
                    <KeyBackupReminder />
                    <RegionSetupReminder />
                    <CommandPalette />
                  </>
                ) : null}
                <MapProvider>
                  <Outlet />
                </MapProvider>
              </div>""",
            ),
            (
                """              <div className="h-full flex w-full">
                <DialogManager />
                {device ? (
                  <>
                    <KeyBackupReminder />
                    <RegionSetupReminder />
                    <CommandPalette />
                  </>
                ) : null}
                <MapProvider>
                  <Outlet />
                </MapProvider>
              </div>""",
                """              <div className="h-full flex w-full">
                {device && client ? (
                  <>
                    <DialogManager />
                    <KeyBackupReminder />
                    <RegionSetupReminder />
                    <CommandPalette />
                  </>
                ) : null}
                <MapProvider>
                  <Outlet />
                </MapProvider>
              </div>""",
            ),
        ],
        "App always Outlet disconnected",
    )

    reminder = web / "apps/web/src/components/RegionSetupReminder.tsx"
    _replace_once(
        reminder,
        'import { useIsRegionUnset } from "@meshtastic/sdk-react";',
        """import { useActiveClient, useSignal } from "@meshtastic/sdk-react";""",
        "RegionSetupReminder safe imports",
    )
    text_reminder = reminder.read_text(encoding="utf-8")
    if "REGION_UNSET_FALSE" in text_reminder:
        print("  skip (déjà appliqué) RegionSetupReminder no throw without client")
    else:
        _replace_once(
            reminder,
            """export const RegionSetupReminder = (): null => {
  const isRegionUnset = useIsRegionUnset();""",
            """const REGION_UNSET_FALSE = {
  value: false,
  peek: () => false,
  subscribe: () => () => {},
} as const;

export const RegionSetupReminder = (): null => {
  const client = useActiveClient();
  const isRegionUnset = useSignal(
    client?.config.isRegionUnset ?? REGION_UNSET_FALSE,
  );""",
            "RegionSetupReminder no throw without client",
        )

    _replace_once(
        settings,
        """import {
  LayersIcon,
  RadioTowerIcon,
  RefreshCwIcon,
  RouterIcon,
  SaveIcon,
  SaveOff,
} from "lucide-react";""",
        """import {
  Cable,
  LayersIcon,
  RadioTowerIcon,
  RefreshCwIcon,
  RouterIcon,
  SaveIcon,
  SaveOff,
} from "lucide-react";""",
        "settings Cable icon",
    )
    _replace_once(
        settings,
        """  const activeSection =
    sections.find((section) =>
      routerState.location.pathname.includes(`/settings/${section.key}`),
    ) ?? sections[0];""",
        """  const activeSection =
    sections.find((section) =>
      routerState.location.pathname.includes(`/settings/${section.key}`),
    ) ??
    (!editor
      ? (sections.find((section) => section.key === "measurement") ??
        sections[0])
      : sections[0]);""",
        "settings default measurement when disconnected",
    )
    _replace_first(
        settings,
        [
            (
                "      {ActiveComponent && <ActiveComponent onFormInit={onFormInit} />}",
                """      {ActiveComponent &&
      (activeSection?.key === "measurement" ||
        activeSection?.key === "module" ||
        editor) ? (
        <ActiveComponent onFormInit={onFormInit} />
      ) : (
        <div className="flex flex-col items-center justify-center gap-3 p-8 text-sm text-slate-500">
          <p>{t("measurementRange.notConnected")}</p>
          <button
            type="button"
            className="inline-flex items-center gap-2 rounded-md bg-slate-900 px-3 py-2 text-sm text-white dark:bg-slate-50 dark:text-slate-900"
            onClick={() => navigate({ to: "/connections" })}
          >
            <Cable size={16} />
            {t("ui:navigation.connect")}
          </button>
        </div>
      )}""",
            ),
            (
                '      {ActiveComponent && (activeSection?.key === "measurement" || editor) ? (',
                """      {ActiveComponent &&
      (activeSection?.key === "measurement" ||
        activeSection?.key === "module" ||
        editor) ? (""",
            ),
        ],
        "settings skip radio forms without node",
    )

    vite_cfg = web / "apps/web/vite.config.ts"
    _replace_once(
        vite_cfg,
        'title: isTest ? "Meshtastic Web (TEST)" : "Meshtastic Web",',
        'title: "Mini Station Meteo -Configurateur",',
        "vite html title",
    )

    module_cfg = web / "apps/web/src/pages/Settings/ModuleConfig.tsx"
    _replace_once(
        module_cfg,
        """} as const;

export const ModuleConfig = ({ onFormInit }: ConfigProps) => {""",
        """} as const;

const STATION_METEO_HIDDEN_MODULE_CASES = new Set<string>([
  "externalNotification",
  "rangeTest",
  "cannedMessage",
  "audio",
  "ambientLighting",
  "paxcounter",
  "tak",
  "statusmessage",
]);

export const ModuleConfig = ({ onFormInit }: ConfigProps) => {""",
        "ModuleConfig hidden set",
    )
    _replace_once(
        module_cfg,
        """      { case: "tak", label: t("page.tabTak"), element: Tak },
    ],
    [t],
  );""",
        """      { case: "tak", label: t("page.tabTak"), element: Tak },
    ].filter((tab) => !STATION_METEO_HIDDEN_MODULE_CASES.has(tab.case)),
    [t],
  );""",
        "ModuleConfig filter tabs",
    )
    _replace_once(
        module_cfg,
        """          <Suspense fallback={<Spinner size="lg" className="my-5" />}>
            <tab.element onFormInit={onFormInit} />
          </Suspense>""",
        """          <Suspense fallback={<Spinner size="lg" className="my-5" />}>
            {editor ? <tab.element onFormInit={onFormInit} /> : null}
          </Suspense>""",
        "ModuleConfig forms need editor",
    )

    dialog = web / "apps/web/src/components/Dialog/AddConnectionDialog/AddConnectionDialog.tsx"
    _replace_once(
        dialog,
        """const TAB_META: Array<{ key: TabKey; label: string; Icon: LucideIcon }> = [
  { key: "http", label: "HTTP", Icon: Globe },
  { key: "bluetooth", label: "Bluetooth", Icon: Bluetooth },
  { key: "serial", label: "Serial", Icon: Cable },
];""",
        """const TAB_META: Array<{ key: TabKey; labelKey: string; Icon: LucideIcon }> = [
  { key: "serial", labelKey: "addConnection.tabs.usb", Icon: Cable },
  { key: "bluetooth", labelKey: "addConnection.tabs.bluetooth", Icon: Bluetooth },
  { key: "http", labelKey: "addConnection.tabs.ip", Icon: Globe },
];""",
        "connection tabs USB/BT/IP",
    )
    _replace_once(
        dialog,
        '  tab: "http",',
        '  tab: "serial",',
        "default tab serial",
    )
    _replace_once(
        dialog,
        "  const { t } = useTranslation();",
        '  const { t } = useTranslation("dialog");',
        "dialog i18n ns",
    )
    _replace_once(
        dialog,
        """          {TAB_META.map(({ key, label, Icon }) => (
            <TabsTrigger key={key} value={key} className="gap-2">
              <Icon className="h-4 w-4" />
              {label}
            </TabsTrigger>
          ))}""",
        """          {TAB_META.map(({ key, labelKey, Icon }) => (
            <TabsTrigger key={key} value={key} className="gap-2">
              <Icon className="h-4 w-4" />
              {t(labelKey)}
            </TabsTrigger>
          ))}""",
        "tab labels i18n",
    )

    def fr_ui(d):
        nav = d.setdefault("navigation", {})
        nav["meteo"] = "Météo"
        nav["connect"] = "Connecter"
        d["meteo"] = {
            "battery": "Batterie",
            "environment": "BME688",
            "temperature": "Température",
            "humidity": "Humidité",
            "pressure": "Pression",
            "gas": "Résistance gaz",
            "iaq": "IAQ",
            "co2": "CO2 estimé",
        }

    def en_ui(d):
        nav = d.setdefault("navigation", {})
        nav["meteo"] = "Weather"
        nav["connect"] = "Connect"
        d["meteo"] = {
            "battery": "Battery",
            "environment": "BME688",
            "temperature": "Temperature",
            "humidity": "Humidity",
            "pressure": "Pressure",
            "gas": "Gas resistance",
            "iaq": "IAQ",
            "co2": "Estimated CO2",
        }

    def range_fr(d):
        nav = d.setdefault("navigation", {})
        if isinstance(nav, dict):
            nav["measurementRange"] = "Plage de mesure"
        d["measurementRange"] = {
            "description": "Moyenne normale, plage basse/haute et seuils (très bas → très haut) pour chaque grandeur BME688. Les valeurs sont enregistrées sur le nœud.",
            "refresh": "Lire le nœud",
            "save": "Enregistrer sur le nœud",
            "resetDefaults": f"Défauts {project_version()}",
            "notConnected": "Pas de nœud connecté",
            "sendFailed": "Échec d’envoi",
            "quantity": {
                "temp": "Température (°C)",
                "humidity": "Humidité (%RH)",
                "pressure": "Pression (hPa)",
                "gasOhm": "Résistance gaz (Ω)",
                "iaq": "IAQ (0–500)",
                "co2": "CO2 estimé (ppm)",
            },
            "field": {
                "mean": "Moyenne normale",
                "low": "Valeur basse",
                "high": "Valeur haute",
                "veryLow": "Très bas",
                "warnLow": "Bas",
                "warnHigh": "Haut",
                "veryHigh": "Très haut",
            },
        }

    def range_en(d):
        nav = d.setdefault("navigation", {})
        if isinstance(nav, dict):
            nav["measurementRange"] = "Measurement range"
        d["measurementRange"] = {
            "description": "Normal mean, low/high range and thresholds (very low → very high) for each BME688 quantity. Values live on the node.",
            "refresh": "Read node",
            "save": "Save to node",
            "resetDefaults": f"{project_version()} defaults",
            "notConnected": "No node connected",
            "sendFailed": "Send failed",
            "quantity": {
                "temp": "Temperature (°C)",
                "humidity": "Humidity (%RH)",
                "pressure": "Pressure (hPa)",
                "gasOhm": "Gas resistance (Ω)",
                "iaq": "IAQ (0–500)",
                "co2": "Estimated CO2 (ppm)",
            },
            "field": {
                "mean": "Normal mean",
                "low": "Low",
                "high": "High",
                "veryLow": "Very low",
                "warnLow": "Low warn",
                "warnHigh": "High warn",
                "veryHigh": "Very high",
            },
        }

    def dialog_tabs(d, fr: bool):
        ac = d.setdefault("addConnection", {})
        ac["tabs"] = {
            "usb": "USB",
            "bluetooth": "Bluetooth",
            "ip": "IP",
        }
        ac["description"] = (
            "USB (Web Serial), Bluetooth (Web Bluetooth) ou IP."
            if fr
            else "USB (Web Serial), Bluetooth (Web Bluetooth) or IP."
        )
        if fr:
            ac["title"] = "Ajouter une connexion"

    def connections_page(d, fr: bool):
        d["page"] = {
            "title": "Connecter la station météo" if fr else "Connect the weather station",
            "description": (
                "USB (Web Serial), Bluetooth (Web Bluetooth) ou IP. Les connexions sont enregistrées dans le navigateur."
                if fr
                else "USB (Web Serial), Bluetooth (Web Bluetooth) or IP. Saved connections stay in this browser."
            ),
        }
        d["connectionType_ble"] = "Bluetooth"
        d["connectionType_serial"] = "USB"
        d["connectionType_network"] = "IP"

    locales = web / "apps/web/public/i18n/locales"
    _patch_json(locales / "fr-FR/ui.json", fr_ui)
    _patch_json(locales / "en/ui.json", en_ui)
    _patch_json(locales / "fr-FR/config.json", range_fr)
    _patch_json(locales / "en/config.json", range_en)
    _patch_json(locales / "fr-FR/dialog.json", lambda d: dialog_tabs(d, True))
    _patch_json(locales / "en/dialog.json", lambda d: dialog_tabs(d, False))
    _patch_json(locales / "fr-FR/connections.json", lambda d: connections_page(d, True))
    _patch_json(locales / "en/connections.json", lambda d: connections_page(d, False))

    cmd = locales / "fr-FR/commandPalette.json"
    if cmd.is_file():
        def cmd_fr(d):
            d.setdefault("goto", {}).setdefault("command", {})["meteo"] = "Météo"
        _patch_json(cmd, cmd_fr)
        def cmd_en(d):
            d.setdefault("goto", {}).setdefault("command", {})["meteo"] = "Weather"
        _patch_json(locales / "en/commandPalette.json", cmd_en)

    _prepend_once(
        web / "README.md",
        "<!-- STATION_METEO -->",
        WEB_README_BANNER,
        "web README banner",
    )
    _prepend_once(
        web / "apps/web/README.md",
        "<!-- STATION_METEO -->",
        WEB_APPS_README_BANNER,
        "apps/web README banner",
    )

    print("web overlay OK")


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        raise SystemExit(2)
    target = sys.argv[1]
    fw = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "firmware"
    web = Path(sys.argv[3]) if len(sys.argv) > 3 else ROOT / "station_meteo_client_web"
    if target in ("firmware", "all"):
        apply_firmware(fw)
    if target in ("web", "all"):
        apply_web(web)


if __name__ == "__main__":
    main()
