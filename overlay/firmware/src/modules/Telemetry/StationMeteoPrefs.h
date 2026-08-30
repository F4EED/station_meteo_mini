#pragma once

#ifdef STATION_METEO

#include <stdint.h>
#include <string.h>

// Bande de mesure persistée (LittleFS /prefs/station_meteo.dat).
// Unités : °C, %RH, hPa, Ω, IAQ 0–500, CO2 estimé ppm.
// eCO2 = 400 + IAQ × 4 (dérivé firmware, pas BSEC Bosch).
#pragma pack(push, 1)
struct StationMeteoBand {
    float mean;
    float low;
    float high;
    float veryLow;
    float warnLow;
    float warnHigh;
    float veryHigh;
};

struct StationMeteoPrefs {
    uint32_t magic;
    uint8_t version;
    uint8_t cmd;
    uint16_t reserved;
    StationMeteoBand temp;
    StationMeteoBand humidity;
    StationMeteoBand pressure;
    StationMeteoBand gasOhm;
    StationMeteoBand iaq;
    StationMeteoBand co2;
    uint32_t xorHash;
};
#pragma pack(pop)

static_assert(sizeof(StationMeteoPrefs) == 180, "StationMeteoPrefs layout must stay 180 bytes");

enum StationMeteoPrefsCmd : uint8_t {
    STMET_CMD_STORE = 0,
    STMET_CMD_GET = 1,
    STMET_CMD_SET = 2,
    STMET_CMD_DATA = 3,
};

class StationMeteoPrefsStore
{
  public:
    static constexpr uint32_t MAGIC = 0x53544D54; // 'STMT'
    static constexpr uint8_t VERSION = 1;
    static constexpr const char *kFileName = "/prefs/station_meteo.dat";

    static StationMeteoPrefsStore &instance();

    static StationMeteoPrefs defaults();
    static uint32_t computeHash(const StationMeteoPrefs &s);
    static bool valid(const StationMeteoPrefs &s);
    static void finalize(StationMeteoPrefs &s, uint8_t cmd = STMET_CMD_STORE);

    // eCO2 estimé (ppm) à partir de l'IAQ firmware — pas un proto Bosch.
    static float estimatedCo2Ppm(uint16_t iaq) { return 400.f + float(iaq) * 4.f; }

    void load();
    bool save();
    bool apply(const StationMeteoPrefs &incoming);

    const StationMeteoPrefs &get() const { return prefs; }
    StationMeteoPrefs copyForWire(uint8_t cmd) const;

  private:
    StationMeteoPrefsStore() : prefs(defaults()) {}
    StationMeteoPrefs prefs;
    bool loaded = false;
};

#endif
