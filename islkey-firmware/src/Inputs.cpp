/**
 * Inputs.cpp — Security input monitoring implementation
 */

#include "Inputs.h"
#include "Config.h"
#include "Outputs.h"
#include "LED.h"
#include "API.h"

namespace Inputs {

    bool fireAlarmActive = false;
    bool tamperActive    = false;
    bool doorOpen        = false;

    static const int PINS[4] = { INPUT_1_PIN, INPUT_2_PIN, INPUT_3_PIN, INPUT_4_PIN };
    static bool lastState[4] = { false, false, false, false };
    static unsigned long doorOpenedAt = 0;
    static bool heldAlertSent = false;
    static bool accessGrantedRecently = false;
    static unsigned long accessGrantedAt = 0;
    #define ACCESS_WINDOW_MS 3000   // Door must open within 3s of access granted

    // Debounce — a state change is only accepted once the new reading has held
    // continuously for DEBOUNCE_MS (rejects electrical noise on floating inputs).
    static bool          candState[4] = { false, false, false, false };
    static unsigned long candSince[4] = { 0, 0, 0, 0 };
    #define DEBOUNCE_MS 60

    bool isTriggered( int idx );   // defined below

    void init() {
        for ( int i = 0; i < 4; i++ ) {
            pinMode( PINS[i], INPUT_PULLUP );
            // Seed all debounce state from the (logic-aware) initial reading
            bool t = isTriggered( i );
            lastState[i] = t;
            candState[i] = t;
            candSince[i] = millis();
        }
        Serial.printf("[INPUTS] Initialised on GPIO %d/%d/%d/%d\n",
            INPUT_1_PIN, INPUT_2_PIN, INPUT_3_PIN, INPUT_4_PIN );
    }

    // Returns true if the input is in triggered state
    // accounts for NC vs NO logic configured per input
    bool isTriggered( int idx ) {
        bool raw = digitalRead( PINS[idx] ) == HIGH;
        if ( Config::inputs[idx].logic == LOGIC_NC ) {
            return raw;   // NC: HIGH = open circuit = triggered
        } else {
            return !raw;  // NO: LOW = closed = triggered
        }
    }

    // Public live read of an input's triggered state (real-time, for the display)
    bool triggered( int idx ) {
        if ( idx < 0 || idx > 3 ) return false;
        return isTriggered( idx );
    }

    // Called by Outputs when access is granted — so we can monitor forced entry
    void notifyAccessGranted() {
        accessGrantedRecently = true;
        accessGrantedAt = millis();
    }

    void processInput( int idx ) {
        bool raw = isTriggered( idx );

        // Stable-confirm debounce: restart the timer whenever the raw reading
        // moves; only accept it once it has held steady for DEBOUNCE_MS.
        if ( raw != candState[idx] ) {
            candState[idx] = raw;
            candSince[idx] = millis();
            return;
        }
        if ( raw == lastState[idx] ) return;                    // already the accepted state
        if ( millis() - candSince[idx] < DEBOUNCE_MS ) return;  // not held long enough yet

        bool triggered = raw;
        lastState[idx]  = triggered;

        InputFunction fn = Config::inputs[idx].function;

        switch ( fn ) {

            case INPUT_EXIT_BTN:
                if ( triggered ) {
                    Serial.printf("[INPUT%d] Exit button pressed\n", idx + 1 );
                    onEvent( EVT_EXIT_REQUEST );
                }
                break;

            case INPUT_DOOR_CONTACT:
                if ( triggered ) {
                    // Door opened
                    doorOpen      = true;
                    doorOpenedAt  = millis();
                    heldAlertSent = false;
                    Serial.println("[DOOR] Opened");

                    // Forced entry check — did a valid access precede this?
                    if ( Config::door.forced_entry_detect ) {
                        bool withinWindow = accessGrantedRecently &&
                                            ( millis() - accessGrantedAt < ACCESS_WINDOW_MS );
                        if ( !withinWindow ) {
                            Serial.println("[DOOR] !! Forced entry detected");
                            onEvent( EVT_FORCED_ENTRY );
                        }
                    }
                    accessGrantedRecently = false;
                    onEvent( EVT_DOOR_OPENED );

                } else {
                    // Door closed
                    doorOpen      = false;
                    heldAlertSent = false;
                    Serial.println("[DOOR] Closed");
                    onEvent( EVT_DOOR_CLOSED );
                }
                break;

            case INPUT_FIRE_ALARM:
                if ( triggered ) {
                    fireAlarmActive = true;
                    Serial.println("[FIRE] !! Fire alarm triggered — unlocking all relays");
                    LED::set( LED::RED, LED::SOLID );
                    onEvent( EVT_FIRE_ALARM );
                } else {
                    fireAlarmActive = false;
                    Serial.println("[FIRE] Fire alarm cleared");
                    LED::set( LED::BLUE, LED::SOLID );
                    onEvent( EVT_FIRE_CLEARED );
                }
                break;

            case INPUT_TAMPER:
                if ( triggered ) {
                    tamperActive = true;
                    Serial.println("[TAMPER] !! Tamper detected");
                    LED::set( LED::ORANGE, LED::BLINK_FAST );
                    onEvent( EVT_TAMPER );
                } else {
                    tamperActive = false;
                    Serial.println("[TAMPER] Tamper cleared");
                    LED::set( LED::BLUE, LED::SOLID );
                    onEvent( EVT_TAMPER_CLEAR );
                }
                break;

            case INPUT_DISABLED:
            default:
                break;
        }
    }

    void loop() {
        for ( int i = 0; i < 4; i++ ) {
            processInput( i );
        }

        // Door held open check
        if ( doorOpen && !heldAlertSent ) {
            unsigned long heldMs = (unsigned long)Config::door.held_open_secs * 1000;
            if ( millis() - doorOpenedAt > heldMs ) {
                heldAlertSent = true;
                Serial.printf("[DOOR] Door held open > %d seconds\n", Config::door.held_open_secs );
                onEvent( EVT_DOOR_HELD );
            }
        }
    }

    void onEvent( Event evt ) {
        // Route events to outputs and API
        switch ( evt ) {
            case EVT_EXIT_REQUEST:
                Outputs::triggerRelay( 0 );   // Relay 1 = primary lock
                break;

            case EVT_FIRE_ALARM:
                Outputs::fireAlarmUnlock();
                break;

            case EVT_FIRE_CLEARED:
                Outputs::fireAlarmClear();
                break;

            default:
                break;
        }

        // Send event to cloud API
        API::reportEvent( evt );
    }
}
