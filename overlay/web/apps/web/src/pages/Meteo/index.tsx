import { PageLayout } from "@components/PageLayout.tsx";
import { Sidebar } from "@components/Sidebar.tsx";
import BatteryStatus from "@components/BatteryStatus.tsx";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@components/UI/Card.tsx";
import { useMyNodeAsProto } from "@core/hooks/useNodesAsProto.ts";
import { estimatedCo2Ppm } from "@core/stationMeteo/measurementRange.ts";
import { useActiveClient, useSignal } from "@meshtastic/sdk-react";
import { CloudSun } from "lucide-react";
import { useTranslation } from "react-i18next";

function fmt(n: number | undefined, digits = 1, unit = ""): string {
  if (n === undefined || Number.isNaN(n)) return "—";
  return `${n.toFixed(digits)}${unit}`;
}

export default function MeteoPage() {
  const { t } = useTranslation("ui");
  const myNode = useMyNodeAsProto();
  const client = useActiveClient();
  const myNum = useSignal(
    client?.device.myNodeNum ?? {
      value: undefined,
      peek: () => undefined,
      subscribe: () => () => {},
    },
  );
  const latest = useSignal(
    myNum !== undefined && client
      ? client.telemetry.latest(myNum)
      : {
          value: undefined,
          peek: () => undefined,
          subscribe: () => () => {},
        },
  );

  const env =
    latest?.kind === "environmentMetrics"
      ? (latest.value as {
          temperature?: number;
          relativeHumidity?: number;
          barometricPressure?: number;
          gasResistance?: number;
          iaq?: number;
        })
      : undefined;

  const iaq = env?.iaq;
  const co2 = typeof iaq === "number" ? estimatedCo2Ppm(iaq) : undefined;

  return (
    <PageLayout
      leftBar={<Sidebar />}
      label={t("navigation.meteo")}
      icon={CloudSun}
    >
      <div className="grid gap-4 p-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>{t("meteo.battery")}</CardTitle>
          </CardHeader>
          <CardContent>
            <BatteryStatus deviceMetrics={myNode?.deviceMetrics} />
            <p className="mt-2 text-sm text-slate-500">
              {fmt(myNode?.deviceMetrics?.voltage, 2, " V")}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>{t("meteo.environment")}</CardTitle>
          </CardHeader>
          <CardContent className="grid grid-cols-2 gap-2 text-sm">
            <span>{t("meteo.temperature")}</span>
            <span>{fmt(env?.temperature, 1, " °C")}</span>
            <span>{t("meteo.humidity")}</span>
            <span>{fmt(env?.relativeHumidity, 0, " %")}</span>
            <span>{t("meteo.pressure")}</span>
            <span>{fmt(env?.barometricPressure, 1, " hPa")}</span>
            <span>{t("meteo.gas")}</span>
            <span>
              {env?.gasResistance !== undefined
                ? `${(env.gasResistance * 1000).toExponential(2)} Ω`
                : "—"}
            </span>
            <span>{t("meteo.iaq")}</span>
            <span>{fmt(iaq, 0)}</span>
            <span>{t("meteo.co2")}</span>
            <span>{fmt(co2, 0, " ppm")}</span>
          </CardContent>
        </Card>
      </div>
    </PageLayout>
  );
}
