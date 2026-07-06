/**
 * Outputs.h / Outputs.cpp — Relay output control
 * Handles: primary lock, secondary relay, fire alarm unlock, pulse timing
 */

#pragma once
#include <Arduino.h>

// On the TTGO T-Display GPIO16/17 are the TFT DC line / an input pin, so the
// relays move to free header pins.
#ifdef BOARD_TTGO
  #define RELAY_1_PIN 32
  #define RELAY_2_PIN 33
#else
  #define RELAY_1_PIN 16
  #define RELAY_2_PIN 17
#endif

namespace Outputs {

    extern bool relay1Active;
    extern bool relay2Active;
    extern bool fireAlarmOverride;

    void init();
    void loop();

    // Trigger a relay by index (0=relay1, 1=relay2) for its configured pulse duration
    void triggerRelay( int idx );

    // Hold relay open indefinitely (fire alarm)
    void fireAlarmUnlock();

    // Release fire alarm hold
    void fireAlarmClear();

    // Called by BLE/API on valid credential
    void accessGranted( int relay_idx = 0 );
}
