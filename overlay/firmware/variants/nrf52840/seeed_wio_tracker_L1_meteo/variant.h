#ifndef _SEEED_TRACKER_L1_METEO_H_
#define _SEEED_TRACKER_L1_METEO_H_
#include "WVariant.h"
// Mini station météo : L1 Pro headless (pas d'OLED / trackball). BME688 sur Grove Wire1.

#define VARIANT_MCK (64000000ul)
#define USE_LFXO
#define USE_POWERSAVE

#define PINS_COUNT (33u)
#define NUM_DIGITAL_PINS (33u)
#define NUM_ANALOG_INPUTS (8u)
#define NUM_ANALOG_OUTPUTS (0u)

#define PIN_LED1 (11)
#define PIN_LED2 (12)

#define LED_GREEN PIN_LED1
#define LED_BLUE PIN_LED2
#define LED_STATE_ON 1

#define CANCEL_BUTTON_PIN D13
#define CANCEL_BUTTON_ACTIVE_LOW true
#define CANCEL_BUTTON_ACTIVE_PULLUP false

#define D0 0
#define D1 1
#define D2 2
#define D3 3
#define D4 4
#define D5 5
#define D6 6
#define D7 7
#define D8 8
#define D9 9
#define D10 10
#define D12 12
#define D13 13
#define D14 14
#define D15 15
#define D16 16
#define D17 17
#define D18 18

#define PIN_A0 0
#define PIN_A1 1
#define PIN_A2 2
#define PIN_A3 3
#define PIN_A4 4
#define PIN_A5 5
#define PIN_VBAT D16

#define PIN_WIRE_SDA D14
#define PIN_WIRE_SCL D15
#define WIRE_INTERFACES_COUNT 2
#define PIN_WIRE1_SDA D18
#define PIN_WIRE1_SCL D17
#define I2C_NO_RESCAN

static const uint8_t SDA = PIN_WIRE_SDA;
static const uint8_t SCL = PIN_WIRE_SCL;

#define HAS_SCREEN 0

#define SPI_INTERFACES_COUNT 1
#define PIN_SPI_MISO 9
#define PIN_SPI_MOSI 10
#define PIN_SPI_SCK 8

#define USE_SX1262
#define SX126X_CS D4
#define SX126X_DIO1 D1
#define SX126X_BUSY D3
#define SX126X_RESET D2
#define SX126X_DIO3_TCXO_VOLTAGE 1.8
#define SX126X_RXEN D5
#define SX126X_TXEN RADIOLIB_NC
#define SX126X_DIO2_AS_RF_SWITCH

#define BAT_READ 30
#define ADC_CTRL BAT_READ
#define ADC_CTRL_ENABLED HIGH
#define BATTERY_SENSE_RESOLUTION_BITS 12
#define ADC_MULTIPLIER 2.0
#define BATTERY_PIN PIN_VBAT
#define AREF_VOLTAGE 3.6
#define NRF_APM

#define PIN_GPS_STANDBY D0
#ifndef HAS_GPS
#define HAS_GPS 0
#endif

#define PIN_QSPI_SCK (21)
#define PIN_QSPI_CS (22)
#define PIN_QSPI_IO0 (23)
#define PIN_QSPI_IO1 (24)
#define PIN_QSPI_IO2 (25)
#define PIN_QSPI_IO3 (26)

#define EXTERNAL_FLASH_DEVICES P25Q16H
#define EXTERNAL_FLASH_USE_QSPI

#define PIN_BUZZER D12

#ifdef __cplusplus
extern "C" {
#endif
#define PIN_SERIAL1_RX (-1)
#define PIN_SERIAL1_TX (-1)
#define PIN_SERIAL2_RX (-1)
#define PIN_SERIAL2_TX (-1)
#ifdef __cplusplus
}
#endif

#endif
