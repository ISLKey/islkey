/**
 * Network.h / Network.cpp — WiFi connection and NTP time sync
 */

#pragma once
#include <Arduino.h>

namespace Network {

    extern bool connected;
    extern unsigned long lastNTPSync;

    void init();
    void loop();
    bool isConnected();
    String getIP();

    // Sync time from NTP — call after WiFi connects
    void syncNTP();

    // Update internal clock from BLE phone timestamp
    void updateTimeFromBLE( uint32_t utc_epoch, int16_t utc_offset_minutes );
}
