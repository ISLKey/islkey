/**
 * Outputs.cpp — Relay output implementation
 */

#include "Outputs.h"
#include "Config.h"
#include "LED.h"
#include "Inputs.h"

namespace Outputs {

    bool relay1Active      = false;
    bool relay2Active      = false;
    bool fireAlarmOverride = false;

    static const int PINS[2] = { RELAY_1_PIN, RELAY_2_PIN };
    static unsigned long relayOnAt[2]  = { 0, 0 };
    static bool          relayPulsing[2] = { false, false };

    void setRelay( int idx, bool state ) {
        if ( idx < 0 || idx > 1 ) return;
        bool active_high = Config::relays[idx].active_high;
        // If active_high, HIGH energises the relay; otherwise LOW energises it
        digitalWrite( PINS[idx], ( state == active_high ) ? HIGH : LOW );
        if ( idx == 0 ) relay1Active = state;
        else            relay2Active = state;
    }

    void init() {
        pinMode( RELAY_1_PIN, OUTPUT );
        pinMode( RELAY_2_PIN, OUTPUT );

        // Initialise relays to de-energised state
        for ( int i = 0; i < 2; i++ ) {
            bool active_high = Config::relays[i].active_high;
            digitalWrite( PINS[i], active_high ? LOW : HIGH );
        }

        relay1Active      = false;
        relay2Active      = false;
        fireAlarmOverride = false;
        Serial.println("[OUTPUTS] Relays initialised — de-energised");
    }

    void triggerRelay( int idx ) {
        if ( idx < 0 || idx > 1 ) return;
        if ( Config::relays[idx].function == RELAY_DISABLED ) return;
        if ( fireAlarmOverride ) return;   // Fire alarm holds relays — do not override

        Serial.printf("[RELAY%d] Triggered — pulse %dms\n", idx + 1, Config::relays[idx].pulse_ms );
        setRelay( idx, true );
        relayOnAt[idx]    = millis();
        relayPulsing[idx] = true;
    }

    void fireAlarmUnlock() {
        fireAlarmOverride = true;
        Serial.println("[RELAY] Fire alarm override — energising all configured relays");
        for ( int i = 0; i < 2; i++ ) {
            if ( Config::relays[i].function != RELAY_DISABLED ) {
                setRelay( i, true );
                relayPulsing[i] = false;   // Hold indefinitely — no pulse timer
            }
        }
    }

    void fireAlarmClear() {
        fireAlarmOverride = false;
        Serial.println("[RELAY] Fire alarm cleared — de-energising relays");
        for ( int i = 0; i < 2; i++ ) {
            setRelay( i, false );
        }
    }

    void accessGranted( int relay_idx ) {
        LED::set( LED::GREEN, LED::FLASH );
        Inputs::notifyAccessGranted();
        triggerRelay( relay_idx );
    }

    void loop() {
        if ( fireAlarmOverride ) return;

        unsigned long now = millis();
        for ( int i = 0; i < 2; i++ ) {
            if ( relayPulsing[i] ) {
                if ( now - relayOnAt[i] >= Config::relays[i].pulse_ms ) {
                    setRelay( i, false );
                    relayPulsing[i] = false;
                    Serial.printf("[RELAY%d] Pulse complete — de-energised\n", i + 1 );
                }
            }
        }
    }
}
