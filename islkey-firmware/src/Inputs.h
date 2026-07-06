/**
 * Inputs.h / Inputs.cpp — Security input monitoring
 * Handles: Exit Button, Door Contact, Fire Alarm, Tamper
 */

#pragma once
#include <Arduino.h>

// On the TTGO T-Display the relay-board input pins (4/5/18/19) are wired to the
// TFT, so the inputs move to free header pins that support internal pull-ups.
#ifdef BOARD_TTGO
  #define INPUT_1_PIN 13
  #define INPUT_2_PIN 25
  #define INPUT_3_PIN 26
  #define INPUT_4_PIN 27
#else
  #define INPUT_1_PIN 4
  #define INPUT_2_PIN 5
  #define INPUT_3_PIN 18
  #define INPUT_4_PIN 19
#endif

namespace Inputs {

    // Events raised by inputs — handled by API module
    enum Event {
        EVT_NONE          = 0,
        EVT_EXIT_REQUEST  = 1,
        EVT_DOOR_OPENED   = 2,
        EVT_DOOR_CLOSED   = 3,
        EVT_DOOR_HELD     = 4,
        EVT_FORCED_ENTRY  = 5,
        EVT_FIRE_ALARM    = 6,
        EVT_FIRE_CLEARED  = 7,
        EVT_TAMPER        = 8,
        EVT_TAMPER_CLEAR  = 9,
    };

    extern bool fireAlarmActive;
    extern bool tamperActive;
    extern bool doorOpen;

    void init();
    void loop();

    // Live (real-time) triggered state of input idx 0-3, per its configured N/O–N/C logic.
    // Reads the pin directly — used by the TTGO display for wiring tests.
    bool triggered( int idx );

    // Called by Outputs when access is granted — so we can monitor forced entry
    void notifyAccessGranted();

    // Callback — called when an event is detected
    void onEvent( Event evt );
}
