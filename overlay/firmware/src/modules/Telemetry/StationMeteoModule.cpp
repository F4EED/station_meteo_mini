#ifdef STATION_METEO

#include "StationMeteoModule.h"
#include "MeshService.h"
#include "NodeDB.h"
#include "configuration.h"
#include <string.h>

#if !MESHTASTIC_EXCLUDE_GPS
#include "GPS.h"
#endif

namespace
{
constexpr int32_t kGpsPollMs = 2000;
constexpr uint32_t kGpsHuntTimeoutMs = 8 * 60 * 1000UL;
} // namespace

StationMeteoModule::StationMeteoModule()
    : SinglePortModule("stmeteo", meshtastic_PortNum_PRIVATE_APP), concurrency::OSThread("StMeteoGps")
{
    StationMeteoPrefsStore::instance().load();
    setIntervalFromNow(kGpsPollMs);
}

void StationMeteoModule::pinGpsAndSleep()
{
#if !MESHTASTIC_EXCLUDE_GPS
    if (!gps || !nodeDB)
        return;

    meshtastic_Position pos = gps->p;
    pos.location_source = meshtastic_Position_LocSource_LOC_INTERNAL;
    nodeDB->updatePosition(nodeDB->getNodeNum(), pos, RX_SRC_LOCAL);
    nodeDB->setLocalPosition(pos);
    config.has_position = true;
    config.position.fixed_position = true;
    config.position.gps_mode = meshtastic_Config_PositionConfig_GpsMode_DISABLED;
    gps->disable();
    nodeDB->saveToDisk(SEGMENT_CONFIG | SEGMENT_NODEDATABASE);
    LOG_INFO("Station météo: position figée lat=%d lon=%d, GPS éteint", pos.latitude_i, pos.longitude_i);
#endif
}

int32_t StationMeteoModule::runOnce()
{
#if MESHTASTIC_EXCLUDE_GPS
    return disable();
#else
    const bool havePos = config.position.fixed_position && (localPosition.latitude_i != 0 || localPosition.longitude_i != 0);

    // Déjà géolocalisée et GPS non demandé : rester éteint (y compris réveil is_power_saving).
    if (havePos && config.position.gps_mode != meshtastic_Config_PositionConfig_GpsMode_ENABLED)
        return disable();

    if (!gps) {
        LOG_WARN("Station météo: pas de GPS, chasse abandonnée");
        return disable();
    }

    if (!hunting) {
        hunting = true;
        huntStartMs = millis();
        if (config.position.gps_mode != meshtastic_Config_PositionConfig_GpsMode_ENABLED)
            config.position.gps_mode = meshtastic_Config_PositionConfig_GpsMode_ENABLED;
        if (!gps->isEnabled())
            gps->enable();
        LOG_INFO("Station météo: GPS allumé, chasse d'un fix");
        return kGpsPollMs;
    }

    if (gps->hasLock() && (gps->p.latitude_i != 0 || gps->p.longitude_i != 0)) {
        pinGpsAndSleep();
        return disable();
    }

    if (!gps->isEnabled() && (millis() - huntStartMs) > 30 * 1000UL) {
        LOG_WARN("Station météo: GPS absent ou déjà éteint, chasse stoppée");
        return disable();
    }

    if ((millis() - huntStartMs) > kGpsHuntTimeoutMs) {
        LOG_WARN("Station météo: pas de fix GPS en 8 min, extinction pour cette session");
        gps->disable();
        return disable();
    }

    return kGpsPollMs;
#endif
}

ProcessMessage StationMeteoModule::handleReceived(const meshtastic_MeshPacket &mp)
{
    if (mp.decoded.portnum != meshtastic_PortNum_PRIVATE_APP)
        return ProcessMessage::CONTINUE;
    if (mp.decoded.payload.size < 6)
        return ProcessMessage::CONTINUE;

    StationMeteoPrefs incoming{};
    const size_t n = mp.decoded.payload.size < sizeof(incoming) ? mp.decoded.payload.size : sizeof(incoming);
    memcpy(&incoming, mp.decoded.payload.bytes, n);
    if (incoming.magic != StationMeteoPrefsStore::MAGIC)
        return ProcessMessage::CONTINUE;

    auto &store = StationMeteoPrefsStore::instance();
    store.load();

    if (incoming.cmd == STMET_CMD_SET) {
        if (!store.apply(incoming))
            return ProcessMessage::STOP;
    }

    StationMeteoPrefs reply = store.copyForWire(STMET_CMD_DATA);
    meshtastic_MeshPacket *p = allocDataPacket();
    if (!p)
        return ProcessMessage::STOP;
    p->to = mp.from;
    p->decoded.want_response = false;
    p->decoded.payload.size = sizeof(reply);
    memcpy(p->decoded.payload.bytes, &reply, sizeof(reply));
    service->sendToMesh(p, RX_SRC_LOCAL, true);
    return ProcessMessage::STOP;
}

#endif
