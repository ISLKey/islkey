/**
 * Network.cpp — WiFi and NTP implementation
 */

#include "Network.h"
#include "Config.h"
#include "LED.h"
#include <WiFi.h>
#include <time.h>

namespace Network {

    bool connected          = false;
    unsigned long lastNTPSync = 0;
    static unsigned long lastReconnectAttempt = 0;
    #define RECONNECT_INTERVAL_MS  30000
    #define NTP_SYNC_INTERVAL_MS   3600000   // Re-sync every hour

    void syncNTP() {
        Serial.println("[NTP] Syncing time...");
        configTime( 0, 0, "pool.ntp.org", "time.google.com" );
        struct tm timeinfo;
        int tries = 0;
        while ( !getLocalTime( &timeinfo ) && tries < 10 ) {
            delay( 500 );
            tries++;
        }
        if ( tries < 10 ) {
            lastNTPSync = millis();
            Serial.printf("[NTP] Time synced: %04d-%02d-%02d %02d:%02d:%02d UTC\n",
                timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
                timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec );
        } else {
            Serial.println("[NTP] Sync failed — will retry");
        }
    }

    void updateTimeFromBLE( uint32_t utc_epoch, int16_t utc_offset_minutes ) {
        // Only update if the incoming time is plausible (after 2024-01-01)
        if ( utc_epoch < 1704067200UL ) return;

        struct timeval tv;
        tv.tv_sec  = utc_epoch;
        tv.tv_usec = 0;
        settimeofday( &tv, nullptr );

        struct tm timeinfo;
        getLocalTime( &timeinfo );
        Serial.printf("[TIME] Updated from BLE: %04d-%02d-%02d %02d:%02d UTC (offset %d min)\n",
            timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
            timeinfo.tm_hour, timeinfo.tm_min, utc_offset_minutes );
    }

    void init() {
        Serial.printf("[NET] Connecting to WiFi: %s\n", Config::network.wifi_ssid );
        WiFi.mode( WIFI_STA );
        WiFi.begin( Config::network.wifi_ssid, Config::network.wifi_password );

        // Wait up to 15 seconds
        unsigned long start = millis();
        while ( WiFi.status() != WL_CONNECTED && millis() - start < 15000 ) {
            delay( 500 );
            Serial.print(".");
        }
        Serial.println();

        if ( WiFi.status() == WL_CONNECTED ) {
            connected = true;
            Serial.printf("[NET] Connected — IP: %s\n", WiFi.localIP().toString().c_str() );
            LED::set( LED::BLUE, LED::SOLID );
            syncNTP();
        } else {
            connected = false;
            Serial.println("[NET] WiFi connection failed — operating offline");
            LED::set( LED::BLUE, LED::BLINK_SLOW );
        }
    }

    void loop() {
        // Reconnect if lost
        if ( WiFi.status() != WL_CONNECTED ) {
            if ( connected ) {
                connected = false;
                Serial.println("[NET] WiFi lost");
                LED::set( LED::BLUE, LED::BLINK_SLOW );
            }
            if ( millis() - lastReconnectAttempt > RECONNECT_INTERVAL_MS ) {
                lastReconnectAttempt = millis();
                Serial.println("[NET] Attempting WiFi reconnect...");
                WiFi.reconnect();
            }
        } else {
            if ( !connected ) {
                connected = true;
                Serial.printf("[NET] WiFi reconnected — IP: %s\n", WiFi.localIP().toString().c_str() );
                LED::set( LED::BLUE, LED::SOLID );
                syncNTP();
            }
            // Periodic NTP re-sync
            if ( millis() - lastNTPSync > NTP_SYNC_INTERVAL_MS ) {
                syncNTP();
            }
        }
    }

    bool isConnected() {
        return WiFi.status() == WL_CONNECTED;
    }

    String getIP() {
        return WiFi.localIP().toString();
    }
}
