/**
 * ISLKey Door Controller Firmware v1.0.0
 * ESP32-WROOM-32E Dual Relay Board
 *
 * GPIO MAP (confirmed for AliExpress WROOM dual relay board):
 *   GPIO16 — RELAY_1 (primary lock)
 *   GPIO17 — RELAY_2 (secondary)
 *   GPIO23 — ONBOARD_LED
 *   GPIO0  — BOOT button (hold 5s for factory reset)
 *   GPIO4  — Security Input 1
 *   GPIO5  — Security Input 2
 *   GPIO18 — Security Input 3
 *   GPIO19 — Security Input 4
 *   GPIO25 — RGB LED Red
 *   GPIO26 — RGB LED Green
 *   GPIO27 — RGB LED Blue
 */

#include <Arduino.h>
#include "Config.h"
#include "Inputs.h"
#include "Outputs.h"
#include "Network.h"
#include "BLE.h"
#include "LED.h"
#include "API.h"
#include "Provision.h"
#include "Display.h"
#include "Commission.h"

#ifdef BOARD_TTGO
#include <WiFi.h>
#include <time.h>

// Push live system state to the TTGO display
static void updateDisplay() {
    Display::setIdentity( Config::device.serial, Config::device.ap_pwd, Config::device.site_code );
    Display::setDoorName( Config::device.door_name );
    Display::setWiFi( Config::network.wifi_ssid,
                      Network::isConnected(),
                      Network::getIP().c_str(),
                      Network::isConnected() ? WiFi.RSSI() : 0 );
    Display::setCloud( API::host(), API::online, API::lastContact,
                       API::lastEventName, API::lastEventTime );
    Display::setBLEStatus( BLE::isConnected() );
    Display::setInputStates( Inputs::doorOpen,
                             Inputs::fireAlarmActive,
                             Inputs::tamperActive );
    Display::setInputLive( Inputs::triggered(0), Inputs::triggered(1),
                           Inputs::triggered(2), Inputs::triggered(3) );
    struct tm timeinfo;
    if ( getLocalTime( &timeinfo, 0 ) ) Display::setTime( &timeinfo );
}
#endif

// ── Boot button factory reset ─────────────────────────────────────────────────
#define BOOT_BTN_PIN   0
#define BOOT_HOLD_MS   5000

unsigned long bootBtnHeld = 0;
bool factoryResetArmed    = false;

void checkFactoryReset() {
    if ( digitalRead( BOOT_BTN_PIN ) == LOW ) {
        if ( bootBtnHeld == 0 ) bootBtnHeld = millis();
        if ( millis() - bootBtnHeld > BOOT_HOLD_MS && !factoryResetArmed ) {
            factoryResetArmed = true;
            Serial.println("[RESET] Factory reset triggered — clearing config");
            LED::set( LED::ORANGE, LED::BLINK_FAST );
            delay( 2000 );
            Config::clear();
            ESP.restart();
        }
    } else {
        bootBtnHeld = 0;
        factoryResetArmed = false;
    }
}

void setup() {
    Serial.begin( 115200 );
    Serial.println("\n\n=== ISLKey Door Controller v1.0.0 ===");

    // Boot button as input
    pinMode( BOOT_BTN_PIN, INPUT_PULLUP );

    // Initialise subsystems
    LED::init();
    LED::set( LED::BLUE, LED::BLINK_SLOW );

    Config::init();

#ifdef BOARD_TTGO
    // Bring up the screen early so the splash shows even before provisioning
    Display::init();
#endif

    if ( !Config::isProvisioned() ) {
        // No config — start provisioning AP. Also bring up BLE so the installer
        // app can provision the unit over Bluetooth (as an alternative to the
        // browser captive portal). BLE::loop() is serviced inside startAP().
        Serial.println("[BOOT] No config found — starting provisioning AP + BLE");
        LED::set( LED::WHITE, LED::BLINK_SLOW );
        BLE::init();
        Provision::startAP();
        // Provision::startAP() runs its own loop until saved, then restarts
        return;
    }

    Serial.println("[BOOT] Config found — starting normal operation");

    Outputs::init();
    Inputs::init();
    Network::init();
    BLE::init();
    API::init();
    API::startTask();   // cloud HTTP runs on its own task — keeps the control loop fast

    LED::set( LED::BLUE, LED::SOLID );
    Serial.println("[BOOT] Ready");
}

void loop() {
    checkFactoryReset();
    Commission::poll();
    Inputs::loop();
    Outputs::loop();
    Network::loop();
    BLE::loop();
    API::loop();
    LED::loop();

    // Fire any cloud (NFC) unlock the API task picked up — relay driven here so all
    // GPIO output stays on one thread.
    int cloudRelay = API::consumeCloudUnlock();
    if ( cloudRelay >= 0 ) Outputs::accessGranted( cloudRelay );

#ifdef BOARD_TTGO
    static unsigned long lastDispState = 0;
    if ( millis() - lastDispState > 500 ) {
        lastDispState = millis();
        updateDisplay();
    }
    Display::loop();
#endif
}
