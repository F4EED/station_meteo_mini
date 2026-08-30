#pragma once

#ifdef STATION_METEO

#include "SinglePortModule.h"
#include "StationMeteoPrefs.h"

class StationMeteoModule : public SinglePortModule
{
  public:
    StationMeteoModule();

  protected:
    virtual ProcessMessage handleReceived(const meshtastic_MeshPacket &mp) override;
};

#endif
