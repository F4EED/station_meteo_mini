#pragma once

#ifdef STATION_METEO

#include "mesh/generated/meshtastic/telemetry.pb.h"
#include "NodeDB.h"
#include "StationMeteoPrefs.h"
#include "gps/RTC.h"
#include <math.h>
#include <stdint.h>
#include <time.h>

// Seuils 0.1.0 : priorité choc > alerte > normal.
// gas_resistance sur le fil = kOhm (BME680Sensor) ; prefs gaz en Ω.
struct WeatherAlertPolicy {
    static constexpr float TEMP_SHOCK = 3.f;
    static constexpr float HUM_SHOCK = 15.f;
    static constexpr float PRES_SHOCK = 5.f;
    static constexpr float GAS_SHOCK_REL = 0.30f;
    static constexpr uint16_t IAQ_SHOCK = 50;
    static constexpr float CO2_SHOCK = 200.f;

    static constexpr uint32_t INTERVAL_ALERT_S = 3600;
    static constexpr uint32_t INTERVAL_SHOCK_S = 300;
    static constexpr uint32_t INTERVAL_NORMAL_NO_RTC_S = 21600;
    static constexpr int SLOT_HOURS[3] = {6, 12, 18};

    enum class Mode : uint8_t { Normal = 0, Alert = 1, Shock = 2 };

    static uint32_t secondsUntilNextSlot(int hour, int minute, int second)
    {
        const int now = hour * 3600 + minute * 60 + second;
        for (int s : SLOT_HOURS) {
            const int t = s * 3600;
            if (t > now)
                return (uint32_t)(t - now);
        }
        return (uint32_t)((24 * 3600 - now) + SLOT_HOURS[0] * 3600);
    }

    static bool outOfRange(bool has, float value, float mini, float maxi)
    {
        return has && (value < mini || value > maxi);
    }

    static bool shocked(bool hasPrev, bool hasNow, float prev, float now, float absDelta)
    {
        return hasPrev && hasNow && fabsf(now - prev) >= absDelta;
    }

    static uint32_t apply(const meshtastic_EnvironmentMetrics &m)
    {
        static bool havePrev = false;
        static meshtastic_EnvironmentMetrics prev = meshtastic_EnvironmentMetrics_init_zero;

        StationMeteoPrefsStore::instance().load();
        const StationMeteoPrefs &p = StationMeteoPrefsStore::instance().get();

        Mode mode = Mode::Normal;

        const bool shockTemp =
            shocked(havePrev && prev.has_temperature, m.has_temperature, prev.temperature, m.temperature, TEMP_SHOCK);
        const bool shockHum = shocked(havePrev && prev.has_relative_humidity, m.has_relative_humidity, prev.relative_humidity,
                                      m.relative_humidity, HUM_SHOCK);
        const bool shockPres = shocked(havePrev && prev.has_barometric_pressure, m.has_barometric_pressure,
                                       prev.barometric_pressure, m.barometric_pressure, PRES_SHOCK);
        const float gasNowOhm = m.has_gas_resistance ? m.gas_resistance * 1000.f : 0.f;
        const float gasPrevOhm = havePrev && prev.has_gas_resistance ? prev.gas_resistance * 1000.f : 0.f;
        const bool shockGas = havePrev && prev.has_gas_resistance && m.has_gas_resistance && gasPrevOhm > 0.f &&
                              fabsf(gasNowOhm - gasPrevOhm) / gasPrevOhm >= GAS_SHOCK_REL;
        const bool shockIaq =
            havePrev && prev.has_iaq && m.has_iaq && ((m.iaq > prev.iaq ? m.iaq - prev.iaq : prev.iaq - m.iaq) >= IAQ_SHOCK);

        const float co2Now = m.has_iaq ? StationMeteoPrefsStore::estimatedCo2Ppm(m.iaq) : 0.f;
        const float co2Prev = havePrev && prev.has_iaq ? StationMeteoPrefsStore::estimatedCo2Ppm(prev.iaq) : 0.f;
        const bool shockCo2 = havePrev && prev.has_iaq && m.has_iaq && fabsf(co2Now - co2Prev) >= CO2_SHOCK;

        if (shockTemp || shockHum || shockPres || shockGas || shockIaq || shockCo2)
            mode = Mode::Shock;
        else if (outOfRange(m.has_temperature, m.temperature, p.temp.low, p.temp.high) ||
                 outOfRange(m.has_relative_humidity, m.relative_humidity, p.humidity.low, p.humidity.high) ||
                 outOfRange(m.has_barometric_pressure, m.barometric_pressure, p.pressure.low, p.pressure.high) ||
                 outOfRange(m.has_gas_resistance, gasNowOhm, p.gasOhm.low, p.gasOhm.high) ||
                 outOfRange(m.has_iaq, (float)m.iaq, p.iaq.low, p.iaq.high) ||
                 outOfRange(m.has_iaq, co2Now, p.co2.low, p.co2.high))
            mode = Mode::Alert;

        uint32_t interval = INTERVAL_ALERT_S;
        if (mode == Mode::Shock) {
            interval = INTERVAL_SHOCK_S;
        } else if (mode == Mode::Normal) {
            const uint32_t now = getValidTime(RTCQualityFromNet, true);
            if (now == 0) {
                interval = INTERVAL_NORMAL_NO_RTC_S;
            } else {
                time_t t = (time_t)now;
                struct tm tm{};
                localtime_r(&t, &tm);
                interval = secondsUntilNextSlot(tm.tm_hour, tm.tm_min, tm.tm_sec);
                if (interval < 60)
                    interval = 60;
            }
        }

        moduleConfig.telemetry.environment_update_interval = interval;
        prev = m;
        havePrev = true;
        return interval;
    }
};

#endif
