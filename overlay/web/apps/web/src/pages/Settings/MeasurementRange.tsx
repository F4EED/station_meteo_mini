import { Button } from "@components/UI/Button.tsx";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@components/UI/Card.tsx";
import { Input } from "@components/UI/Input.tsx";
import { Label } from "@components/UI/Label.tsx";
import { useToast } from "@core/hooks/useToast.ts";
import {
  BAND_KEYS,
  type BandKey,
  DEFAULT_PREFS,
  type MeasurementRangePrefs,
  QUANTITY_KEYS,
  type QuantityKey,
  STMET_CMD_SET,
  clonePrefs,
  decodePrefs,
  encodeGet,
  encodePrefs,
} from "@core/stationMeteo/measurementRange.ts";
import { Protobuf } from "@meshtastic/sdk";
import { useActiveClient } from "@meshtastic/sdk-react";
import { useCallback, useEffect, useState } from "react";
import type { UseFormReturn } from "react-hook-form";
import { useTranslation } from "react-i18next";

interface Props {
  onFormInit?: <T extends object>(methods: UseFormReturn<T>) => void;
}

const FIELD_ORDER: BandKey[] = [
  "mean",
  "low",
  "high",
  "veryLow",
  "warnLow",
  "warnHigh",
  "veryHigh",
];

export function MeasurementRange(_props: Props) {
  const { t } = useTranslation("config");
  const { toast } = useToast();
  const client = useActiveClient();
  const [prefs, setPrefs] = useState<MeasurementRangePrefs>(() =>
    clonePrefs(),
  );
  const [busy, setBusy] = useState(false);

  const applyBytes = useCallback((bytes: Uint8Array | undefined) => {
    if (!bytes) return;
    const decoded = decodePrefs(bytes);
    if (decoded) setPrefs(decoded);
  }, []);

  useEffect(() => {
    if (!client) return;
    const handler = (mesh: { payloadVariant: { case: string; value?: { portnum?: number; payload?: Uint8Array } } }) => {
      if (mesh.payloadVariant.case !== "decoded") return;
      const data = mesh.payloadVariant.value;
      if (!data || data.portnum !== Protobuf.Portnums.PortNum.PRIVATE_APP)
        return;
      applyBytes(data.payload);
    };
    client.events.onMeshPacket.subscribe(handler);
    return () => {
      client.events.onMeshPacket.unsubscribe(handler);
    };
  }, [client, applyBytes]);

  const send = async (bytes: Uint8Array) => {
    if (!client) {
      toast({ title: t("measurementRange.notConnected") });
      return;
    }
    setBusy(true);
    try {
      await client.sendPacket(
        bytes,
        Protobuf.Portnums.PortNum.PRIVATE_APP,
        "self",
      );
    } catch (err) {
      toast({
        title: t("measurementRange.sendFailed"),
        description: String(err),
      });
    } finally {
      setBusy(false);
    }
  };

  const onRefresh = () => send(encodeGet());
  const onSave = () => send(encodePrefs(prefs, STMET_CMD_SET));
  const onReset = () => setPrefs(clonePrefs(DEFAULT_PREFS));

  const setField = (q: QuantityKey, k: BandKey, raw: string) => {
    const n = Number(raw);
    setPrefs((prev) => ({
      ...prev,
      [q]: { ...prev[q], [k]: Number.isFinite(n) ? n : prev[q][k] },
    }));
  };

  return (
    <div className="flex flex-col gap-4 p-2">
      <p className="text-sm text-slate-500 dark:text-slate-400">
        {t("measurementRange.description")}
      </p>
      <div className="flex flex-wrap gap-2">
        <Button onClick={onRefresh} disabled={busy || !client}>
          {t("measurementRange.refresh")}
        </Button>
        <Button onClick={onSave} disabled={busy || !client}>
          {t("measurementRange.save")}
        </Button>
        <Button variant="subtle" onClick={onReset} disabled={busy}>
          {t("measurementRange.resetDefaults")}
        </Button>
      </div>
      {QUANTITY_KEYS.map((q) => (
        <Card key={q}>
          <CardHeader>
            <CardTitle>{t(`measurementRange.quantity.${q}`)}</CardTitle>
          </CardHeader>
          <CardContent className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {FIELD_ORDER.map((k) => (
              <div key={k} className="grid gap-1">
                <Label>{t(`measurementRange.field.${k}`)}</Label>
                <Input
                  type="number"
                  value={Number.isFinite(prefs[q][k]) ? String(prefs[q][k]) : ""}
                  onChange={(e) => setField(q, k, e.target.value)}
                />
              </div>
            ))}
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
