#ifdef STATION_METEO

#include "StationMeteoPrefs.h"
#include "FSCommon.h"
#include "SPILock.h"
#include "configuration.h"
#include <math.h>

StationMeteoPrefsStore &StationMeteoPrefsStore::instance()
{
    static StationMeteoPrefsStore store;
    return store;
}

static StationMeteoBand band(float mean, float low, float high, float veryLow, float warnLow, float warnHigh, float veryHigh)
{
    StationMeteoBand b{};
    b.mean = mean;
    b.low = low;
    b.high = high;
    b.veryLow = veryLow;
    b.warnLow = warnLow;
    b.warnHigh = warnHigh;
    b.veryHigh = veryHigh;
    return b;
}

StationMeteoPrefs StationMeteoPrefsStore::defaults()
{
    StationMeteoPrefs s{};
    s.magic = MAGIC;
    s.version = VERSION;
    s.cmd = STMET_CMD_STORE;
    s.reserved = 0;
    s.temp = band(15.f, -10.f, 40.f, -20.f, 0.f, 35.f, 45.f);
    s.humidity = band(55.f, 20.f, 90.f, 10.f, 30.f, 80.f, 95.f);
    s.pressure = band(1013.f, 980.f, 1040.f, 960.f, 990.f, 1030.f, 1050.f);
    s.gasOhm = band(50000.f, 5000.f, 1.0e7f, 1000.f, 10000.f, 5.0e6f, 2.0e7f);
    s.iaq = band(50.f, 0.f, 150.f, 0.f, 25.f, 100.f, 200.f);
    s.co2 = band(600.f, 400.f, 1500.f, 350.f, 500.f, 1000.f, 2000.f);
    finalize(s, STMET_CMD_STORE);
    return s;
}

uint32_t StationMeteoPrefsStore::computeHash(const StationMeteoPrefs &s)
{
    const uint8_t *p = reinterpret_cast<const uint8_t *>(&s);
    uint32_t h = 0;
    for (size_t i = 0; i + 4 <= sizeof(StationMeteoPrefs) - 4; i += 4) {
        uint32_t w;
        memcpy(&w, p + i, 4);
        h ^= w;
    }
    return h;
}

bool StationMeteoPrefsStore::valid(const StationMeteoPrefs &s)
{
    if (s.magic != MAGIC || s.version != VERSION)
        return false;
    StationMeteoPrefs tmp = s;
    tmp.xorHash = 0;
    return computeHash(tmp) == s.xorHash;
}

void StationMeteoPrefsStore::finalize(StationMeteoPrefs &s, uint8_t cmd)
{
    s.magic = MAGIC;
    s.version = VERSION;
    s.cmd = cmd;
    s.xorHash = 0;
    s.xorHash = computeHash(s);
}

void StationMeteoPrefsStore::load()
{
    if (loaded)
        return;
    prefs = defaults();
#ifdef FSCom
    spiLock->lock();
    auto file = FSCom.open(kFileName, FILE_O_READ);
    if (file) {
        StationMeteoPrefs onDisk{};
        const size_t n = file.read(reinterpret_cast<uint8_t *>(&onDisk), sizeof(onDisk));
        file.close();
        if (n == sizeof(onDisk) && valid(onDisk))
            prefs = onDisk;
    }
    spiLock->unlock();
#endif
    loaded = true;
}

bool StationMeteoPrefsStore::save()
{
    finalize(prefs, STMET_CMD_STORE);
#ifdef FSCom
    spiLock->lock();
    auto file = FSCom.open(kFileName, FILE_O_WRITE);
    if (!file) {
        spiLock->unlock();
        return false;
    }
    const size_t n = file.write(reinterpret_cast<const uint8_t *>(&prefs), sizeof(prefs));
    file.close();
    spiLock->unlock();
    return n == sizeof(prefs);
#else
    return false;
#endif
}

bool StationMeteoPrefsStore::apply(const StationMeteoPrefs &incoming)
{
    if (!valid(incoming))
        return false;
    prefs = incoming;
    prefs.cmd = STMET_CMD_STORE;
    return save();
}

StationMeteoPrefs StationMeteoPrefsStore::copyForWire(uint8_t cmd) const
{
    StationMeteoPrefs out = prefs;
    finalize(out, cmd);
    return out;
}

#endif
