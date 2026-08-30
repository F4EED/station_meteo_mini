#ifdef STATION_METEO

#include "StationMeteoModule.h"
#include "MeshService.h"
#include "configuration.h"
#include <string.h>

StationMeteoModule::StationMeteoModule() : SinglePortModule("stmeteo", meshtastic_PortNum_PRIVATE_APP)
{
    StationMeteoPrefsStore::instance().load();
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
