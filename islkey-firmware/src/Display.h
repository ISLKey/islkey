/**
 * Display.h / Display.cpp — TTGO T-Display screen management
 * Hardware: 1.14" 240x135 colour TFT (ST7789V driver), TFT_eSPI (Setup25)
 *
 * Buttons:
 *   GPIO0  — top button    — next screen
 *   GPIO35 — bottom button — toggle backlight
 *
 * Screens (cycle with top button):
 *   0 — Identity   : serial number + provisioning AP password
 *   1 — Door       : door state + clock + fire/tamper alerts
 *   2 — Wi-Fi      : AP setup details, or connected SSID + IP + RSSI
 *   3 — Cloud/API  : API host, online state, last contact, last event
 *   4 — BLE/Access : BLE state + last access result
 *   5 — Inputs     : security input states
 *   6 — Device     : firmware, board, uptime, heap, IP
 */

#pragma once
#include <Arduino.h>

// Only compile display code on the TTGO build
#ifdef BOARD_TTGO

namespace Display {

    void init();
    void loop();

    // State pushed in from the rest of the firmware
    void setIdentity( const char* serial, const char* apPwd, const char* siteCode );
    void setDoorName( const char* name );
    void setWiFi( const char* ssid, bool connected, const char* ip, int rssi );
    void setCloud( const char* hostName, bool online, const char* lastContact,
                   const char* lastEvent, const char* lastEventTime );
    void setBLEStatus( bool connected );
    void setLastAccess( const char* event, bool granted );
    void setInputStates( bool doorOpen, bool fireAlarm, bool tamper );
    void setInputLive( bool in1, bool in2, bool in3, bool in4 );   // real-time per-input triggered state
    void setTime( struct tm* timeinfo );
    void setProvisioning( bool inAP, const char* apName );   // AP/setup mode banner
    // Full-screen provisioning status (used during app/BLE provisioning).
    // Pass nullptr line1 to clear and return to the normal screens.
    void setProvisioningStatus( const char* line1, const char* line2 );
    void showAccessFlash( bool granted );                    // brief full-screen flash
}

#endif
