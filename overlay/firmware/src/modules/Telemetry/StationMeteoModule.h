#pragma once

#ifdef STATION_METEO

#include "SinglePortModule.h"
#include "StationMeteoPrefs.h"
#include "concurrency/OSThread.h"

class StationMeteoModule : public SinglePortModule, private concurrency::OSThread
{
  public:
    StationMeteoModule();

  protected:
    virtual ProcessMessage handleReceived(const meshtastic_MeshPacket &mp) override;
    virtual int32_t runOnce() override;

  private:
    void pinGpsAndSleep();

    bool hunting = false;
    uint32_t huntStartMs = 0;
};

#endif
