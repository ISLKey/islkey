/**
 * API.cpp — ISLKey cloud REST client (HMAC device auth)
 *
 * Auth model (matches isl-key plugin class-islkey-device-api.php):
 *   1. Register once:  POST /device/register
 *        body: { provisioning_token, mac_address, hardware_id, firmware_version, relay_count }
 *        -> { success, data:{ device_uuid, hmac_secret, ... } }   (hmac_secret shown once)
 *   2. Sign every call:
 *        X-Device-UUID:      <device_uuid>
 *        X-Device-Timestamp: <unix ms, 13 digits, within 60s of server>
 *        X-Device-Sig:       lowercase hex HMAC-SHA256( uuid:timestamp:body , hmac_secret )
 */

#include "API.h"
#include "Config.h"
#include "Network.h"
#include "Inputs.h"
#include "Outputs.h"
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <WiFiClientSecure.h>
#include "mbedtls/md.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"

#define HEARTBEAT_INTERVAL_MS  60000   // Every 60 seconds
#define API_TIMEOUT_MS         8000

namespace API {

    bool online                = false;
    char lastContact[24]       = "never";
    char lastEventName[40]     = "none";
    char lastEventTime[24]     = "";

    static unsigned long lastHeartbeat = 0;
    static WiFiClientSecure wifiClient;

    // ── Background networking task plumbing ─────────────────────────────────────
    struct OutEvent {
        uint8_t kind;       // 0 = input event, 1 = BLE access
        int     evt;        // Inputs::Event (kind 0)
        bool    granted;    // kind 1
        char    token[12];  // kind 1 token hint
    };
    static QueueHandle_t g_outQueue     = nullptr;
    static TaskHandle_t  g_apiTask      = nullptr;
    static volatile int  g_cloudUnlock  = -1;   // relay index of a pending cloud unlock
    static unsigned long lastRegAttempt = 0;

    // ── Time / id helpers ───────────────────────────────────────────────────────
    static void nowStr( char* out, size_t n ) {
        struct tm ti;
        if ( getLocalTime( &ti, 0 ) && ti.tm_year > 123 ) strftime( out, n, "%H:%M:%S", &ti );
        else snprintf( out, n, "+%lus", millis() / 1000 );
    }

    const char* host() {
        static char h[64];
        const char* u = Config::network.api_url;
        const char* p = strstr( u, "://" );
        p = p ? p + 3 : u;
        size_t i = 0;
        while ( p[i] && p[i] != '/' && i < sizeof(h) - 1 ) { h[i] = p[i]; i++; }
        h[i] = '\0';
        if ( i == 0 ) strncpy( h, "(not set)", sizeof(h) );
        return h;
    }

    static String macStr() {
        uint8_t m[6];
        esp_read_mac( m, ESP_MAC_WIFI_STA );
        char b[18];
        snprintf( b, sizeof(b), "%02X:%02X:%02X:%02X:%02X:%02X", m[0], m[1], m[2], m[3], m[4], m[5] );
        return String( b );
    }

    static String hardwareId() {
        uint8_t m[6];
        esp_read_mac( m, ESP_MAC_WIFI_STA );
        char b[20];
        snprintf( b, sizeof(b), "ESP32-%02X%02X%02X%02X%02X%02X", m[0], m[1], m[2], m[3], m[4], m[5] );
        return String( b );
    }

    static String tsMillis() {
        uint64_t ms = (uint64_t) time( nullptr ) * 1000ULL;
        char b[16];
        snprintf( b, sizeof(b), "%llu", (unsigned long long) ms );
        return String( b );
    }

    static String hmacSha256Hex( const char* key, const String& msg ) {
        unsigned char hmac[32];
        const mbedtls_md_info_t* info = mbedtls_md_info_from_type( MBEDTLS_MD_SHA256 );
        mbedtls_md_context_t ctx;
        mbedtls_md_init( &ctx );
        mbedtls_md_setup( &ctx, info, 1 );
        mbedtls_md_hmac_starts( &ctx, (const unsigned char*) key, strlen( key ) );
        mbedtls_md_hmac_update( &ctx, (const unsigned char*) msg.c_str(), msg.length() );
        mbedtls_md_hmac_finish( &ctx, hmac );
        mbedtls_md_free( &ctx );

        static const char* hexd = "0123456789abcdef";
        char out[65];
        for ( int i = 0; i < 32; i++ ) {
            out[i * 2]     = hexd[ (hmac[i] >> 4) & 0xF ];
            out[i * 2 + 1] = hexd[ hmac[i] & 0xF ];
        }
        out[64] = '\0';
        return String( out );
    }

    void init() {
        wifiClient.setInsecure();   // prototype: skip cert verification
        Serial.println("[API] Initialised");
    }

    // ── Registration (consumes the one-time provisioning token) ─────────────────
    bool ensureRegistered() {
        if ( strlen( Config::device.device_uuid ) > 0 && strlen( Config::device.hmac_secret ) > 0 )
            return true;
        if ( !Network::isConnected() ) return false;
        if ( strlen( Config::network.api_url ) == 0 || strlen( Config::network.api_token ) == 0 ) return false;

        StaticJsonDocument<384> req;
        req["provisioning_token"] = Config::network.api_token;
        req["mac_address"]        = macStr();
        req["hardware_id"]        = hardwareId();
        req["firmware_version"]   = "1.0.0";
        req["relay_count"]        = 2;
        String body;
        serializeJson( req, body );

        String url = String( Config::network.api_url ) + "/wp-json/islkey/v1/device/register";
        HTTPClient http;
        http.begin( wifiClient, url );
        http.addHeader( "Content-Type", "application/json" );
        http.setTimeout( API_TIMEOUT_MS );
        int  code = http.POST( body );
        String resp = http.getString();
        http.end();

        if ( code != 200 && code != 201 ) {
            Serial.printf("[API] register failed HTTP %d: %s\n", code, resp.c_str() );
            return false;
        }

        StaticJsonDocument<1024> doc;
        if ( deserializeJson( doc, resp ) != DeserializationError::Ok ) {
            Serial.println("[API] register: bad JSON");
            return false;
        }
        const char* uuid   = doc["data"]["device_uuid"] | "";
        const char* secret = doc["data"]["hmac_secret"]  | "";
        if ( strlen( uuid ) == 0 || strlen( secret ) == 0 ) {
            Serial.println("[API] register: response missing creds");
            return false;
        }
        Config::setDeviceCreds( uuid, secret );
        Serial.printf("[API] Registered with cloud — device_uuid=%s\n", uuid );
        return true;
    }

    // ── Signed request ──────────────────────────────────────────────────────────
    // Returns HTTP status (negative on transport error). respOut optional.
    static int signedSend( const char* method, const char* endpoint, const String& body, String* respOut ) {
        if ( !Network::isConnected() ) return -1;
        if ( strlen( Config::network.api_url ) == 0 ) return -1;
        if ( strlen( Config::device.hmac_secret ) == 0 ) return -1;   // not registered yet

        String url = String( Config::network.api_url ) + endpoint;
        String ts  = tsMillis();
        String sig = hmacSha256Hex( Config::device.hmac_secret,
                                    String( Config::device.device_uuid ) + ":" + ts + ":" + body );

        HTTPClient http;
        http.begin( wifiClient, url );
        http.addHeader( "Content-Type", "application/json" );
        http.addHeader( "X-Device-UUID", Config::device.device_uuid );
        http.addHeader( "X-Device-Timestamp", ts );
        http.addHeader( "X-Device-Sig", sig );
        http.setTimeout( API_TIMEOUT_MS );

        int code = ( strcmp( method, "GET" ) == 0 ) ? http.GET() : http.POST( body );
        if ( respOut ) *respOut = http.getString();
        http.end();

        online = ( code >= 200 && code < 300 );
        if ( online ) {
            nowStr( lastContact, sizeof(lastContact) );
        } else {
            Serial.printf("[API] %s %s -> HTTP %d (heap=%u/%u)\n",
                method, endpoint, code, ESP.getFreeHeap(), ESP.getMaxAllocHeap() );
        }
        return code;
    }

    // ── Heartbeat ───────────────────────────────────────────────────────────────
    void sendHeartbeat() {
        lastHeartbeat = millis();
        if ( !ensureRegistered() ) return;

        StaticJsonDocument<256> doc;
        doc["device_uuid"]      = Config::device.device_uuid;
        doc["firmware_version"] = "1.0.0";
        doc["last_ip"]          = Network::getIP();
        doc["free_heap"]        = ESP.getFreeHeap();
        doc["uptime_secs"]      = millis() / 1000;
        doc["door_open"]        = Inputs::doorOpen;
        doc["fire_alarm"]       = Inputs::fireAlarmActive;
        doc["tamper"]           = Inputs::tamperActive;

        struct tm timeinfo;
        if ( getLocalTime( &timeinfo, 0 ) ) {
            char timebuf[24];
            strftime( timebuf, 24, "%Y-%m-%dT%H:%M:%SZ", &timeinfo );
            doc["device_time"] = timebuf;
        }

        String body;
        serializeJson( doc, body );
        int code = signedSend( "POST", "/wp-json/islkey/v1/device/heartbeat", body, nullptr );
        if ( code >= 200 && code < 300 ) Serial.println("[API] Heartbeat OK");
    }

    static const char* EVT_NAMES[] = {
        "none", "exit_request", "door_opened", "door_closed",
        "door_held", "forced_entry", "fire_alarm", "fire_cleared",
        "tamper", "tamper_clear"
    };

    // Runs on the API task — does the blocking HTTPS POST
    static void txInputEvent( Inputs::Event evt ) {
        if ( !ensureRegistered() ) return;

        StaticJsonDocument<256> doc;
        doc["device_uuid"] = Config::device.device_uuid;
        doc["event_type"]  = EVT_NAMES[evt];
        doc["site_code"]   = Config::device.site_code;
        doc["door_name"]   = Config::device.door_name;

        struct tm timeinfo;
        if ( getLocalTime( &timeinfo, 0 ) ) {
            char timebuf[24];
            strftime( timebuf, 24, "%Y-%m-%dT%H:%M:%SZ", &timeinfo );
            doc["timestamp"] = timebuf;
        }

        String body;
        serializeJson( doc, body );
        Serial.printf("[API] Reporting event: %s\n", EVT_NAMES[evt] );
        signedSend( "POST", "/wp-json/islkey/v1/device/event", body, nullptr );
    }

    // Called from the control loop — NON-BLOCKING (just queues for the API task)
    void reportEvent( Inputs::Event evt ) {
        if ( evt == Inputs::EVT_NONE ) return;

        strncpy( lastEventName, EVT_NAMES[evt], sizeof(lastEventName) - 1 );
        lastEventName[ sizeof(lastEventName) - 1 ] = '\0';
        nowStr( lastEventTime, sizeof(lastEventTime) );

        if ( g_outQueue ) {
            OutEvent e = { 0, (int) evt, false, "" };
            xQueueSend( g_outQueue, &e, 0 );
        }
    }

    // Runs on the API task — blocking HTTPS POST
    static void txBleAccess( bool granted, const char* tokenHint ) {
        if ( !ensureRegistered() ) return;

        StaticJsonDocument<256> doc;
        doc["device_uuid"] = Config::device.device_uuid;
        doc["event_type"]  = granted ? "ACCESS_GRANTED" : "ACCESS_DENIED";
        doc["method"]      = "BLE";
        doc["token_hint"]  = tokenHint;
        doc["result"]      = granted ? "GRANTED" : "DENIED";

        struct tm timeinfo;
        if ( getLocalTime( &timeinfo, 0 ) ) {
            char timebuf[24];
            strftime( timebuf, 24, "%Y-%m-%dT%H:%M:%SZ", &timeinfo );
            doc["timestamp"] = timebuf;
        }

        String body;
        serializeJson( doc, body );
        signedSend( "POST", "/wp-json/islkey/v1/device/access", body, nullptr );
    }

    // Called from the BLE callback — NON-BLOCKING (queues for the API task)
    void reportBLEAccess( const char* token, bool granted ) {
        strncpy( lastEventName, granted ? "BLE access granted" : "BLE access denied",
                 sizeof(lastEventName) - 1 );
        lastEventName[ sizeof(lastEventName) - 1 ] = '\0';
        nowStr( lastEventTime, sizeof(lastEventTime) );

        if ( g_outQueue ) {
            OutEvent e = { 1, 0, granted, "" };
            strncpy( e.token, token ? token : "", sizeof(e.token) - 1 );
            xQueueSend( g_outQueue, &e, 0 );
        }
    }

    // ── Cloud command polling (NFC cloud unlock) ────────────────────────────────
    static unsigned long lastCommandPoll = 0;
    #define COMMAND_POLL_INTERVAL_MS  2000

    void pollCommands() {
        if ( !ensureRegistered() ) return;

        String resp;
        int code = signedSend( "GET", "/wp-json/islkey/v1/device/commands", "", &resp );
        if ( code != 200 ) return;

        StaticJsonDocument<512> doc;
        if ( deserializeJson( doc, resp ) != DeserializationError::Ok ) return;

        JsonArray commands = doc["data"]["commands"].as<JsonArray>();
        for ( JsonObject cmd : commands ) {
            const char* type = cmd["type"] | "";
            if ( strcmp( type, "UNLOCK" ) == 0 ) {
                int relay = cmd["relay"] | 0;
                long cmdId = cmd["id"] | 0;
                Serial.printf("[API] Cloud UNLOCK — relay %d (cmd %ld)\n", relay, cmdId );
                g_cloudUnlock = relay;   // main loop fires the relay (GPIO on one thread)

                if ( cmdId > 0 ) {
                    StaticJsonDocument<96> ack;
                    ack["command_id"] = cmdId;
                    ack["result"]     = "executed";
                    String ackBody;
                    serializeJson( ack, ackBody );
                    signedSend( "POST", "/wp-json/islkey/v1/device/commands/ack", ackBody, nullptr );
                }
            }
        }
    }

    // ── Background networking task — ALL cloud HTTP runs here, off the control loop ──
    static void apiTaskFn( void* ) {
        for ( ;; ) {
            bool registered = ( strlen( Config::device.device_uuid ) > 0 &&
                                strlen( Config::device.hmac_secret ) > 0 );
            if ( !registered ) {
                if ( millis() - lastRegAttempt > 5000 ) {
                    lastRegAttempt = millis();
                    ensureRegistered();
                }
                vTaskDelay( pdMS_TO_TICKS( 200 ) );
                continue;
            }

            // Drain queued input / BLE events
            OutEvent e;
            while ( xQueueReceive( g_outQueue, &e, 0 ) == pdTRUE ) {
                if ( e.kind == 0 ) txInputEvent( (Inputs::Event) e.evt );
                else               txBleAccess( e.granted, e.token );
            }

            unsigned long now = millis();
            if ( now - lastCommandPoll > COMMAND_POLL_INTERVAL_MS ) {
                lastCommandPoll = now;
                pollCommands();
            }
            if ( now - lastHeartbeat > HEARTBEAT_INTERVAL_MS ) {
                sendHeartbeat();
            }

            vTaskDelay( pdMS_TO_TICKS( 100 ) );
        }
    }

    void startTask() {
        if ( g_apiTask ) return;
        g_outQueue = xQueueCreate( 16, sizeof(OutEvent) );
        // Pin to core 0 (with WiFi/BT) so TLS crypto never steals time from the
        // control loop on core 1.
        xTaskCreatePinnedToCore( apiTaskFn, "islkey-api", 16384, nullptr, 1, &g_apiTask, 0 );
        Serial.println("[API] Networking task started (core 0)");
    }

    int consumeCloudUnlock() {
        int r = g_cloudUnlock;
        if ( r >= 0 ) g_cloudUnlock = -1;
        return r;
    }

    // Networking now runs on the background task — keep loop() as a no-op so the
    // main loop never blocks on the network.
    void loop() {}
}
