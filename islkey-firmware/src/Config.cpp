/**
 * Config.cpp — NVS configuration implementation
 */

#include "Config.h"
#include <Preferences.h>
#include <ArduinoJson.h>

// ─────────────────────────────────────────────────────────────────────────────
// TEST-ONLY hardcoded provisioning. Set ISLKEY_TEST_HARDCODE to 0 (or delete this
// block) for production. When enabled the unit skips the provisioning AP and uses
// these credentials directly. Leave TEST_API_URL empty to keep the URL already in
// NVS (from a prior provisioning).
// ─────────────────────────────────────────────────────────────────────────────
#define ISLKEY_TEST_HARDCODE 0
#if ISLKEY_TEST_HARDCODE
  #define TEST_WIFI_SSID  "YourWiFiSSID"
  #define TEST_WIFI_PASS  "YourWiFiPassword"
  #define TEST_API_TOKEN  "islk_d_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  #define TEST_API_URL    ""   // e.g. "https://yourserver.co.uk" — empty = keep NVS value
#endif

namespace Config {

    // Defaults
    InputConfig inputs[4] = {
        { INPUT_EXIT_BTN,     LOGIC_NO },
        { INPUT_DOOR_CONTACT, LOGIC_NC },
        { INPUT_FIRE_ALARM,   LOGIC_NC },
        { INPUT_TAMPER,       LOGIC_NC },
    };

    RelayConfig relays[2] = {
        { RELAY_PRIMARY_LOCK, 5000, true },   // 5 second pulse, active high
        { RELAY_DISABLED,     2000, true },
    };

    DoorConfig door = {
        .held_open_secs      = 60,
        .forced_entry_detect = true,
    };

    DeviceConfig device = {
        "Unconfigured Door",   // door_name
        "",                    // site_code
    };

    NetworkConfig network = {
        "",   // wifi_ssid
        "",   // wifi_password
        "",   // api_url
        "",   // api_token
    };

    static Preferences prefs;

    void init() {
        prefs.begin( "islkey", false );

        // Factory identity — written via serial commissioning, present even
        // before the unit is provisioned with WiFi/API settings
        strncpy( device.serial, prefs.getString( "serial", "" ).c_str(), sizeof(device.serial) );
        strncpy( device.ap_pwd, prefs.getString( "ap_pwd", "" ).c_str(), sizeof(device.ap_pwd) );

        // Device-registration credentials (HMAC auth for the cloud API)
        strncpy( device.device_uuid, prefs.getString( "dev_uuid", "" ).c_str(), sizeof(device.device_uuid) );
        strncpy( device.hmac_secret, prefs.getString( "hmac_sec", "" ).c_str(), sizeof(device.hmac_secret) );

        // Pre-loaded config written at commissioning time (from the .islkey file).
        // Loaded even before the unit is provisioned so the provisioning page can
        // pre-fill these — the engineer then only needs to enter WiFi.
        strncpy( network.api_url,   prefs.getString( "api_url",   "" ).c_str(), sizeof(network.api_url) );
        strncpy( network.api_token, prefs.getString( "api_token", "" ).c_str(), sizeof(network.api_token) );
        strncpy( device.door_name,  prefs.getString( "door_name", device.door_name ).c_str(), sizeof(device.door_name) );
        strncpy( device.site_code,  prefs.getString( "site_code", "" ).c_str(), sizeof(device.site_code) );

        if ( !prefs.isKey( "provisioned" ) ) {
            Serial.println("[CONFIG] Not provisioned (pre-loaded config may be present)");
#if !ISLKEY_TEST_HARDCODE
            return;
#endif
        }

        // WiFi credentials (only available once provisioned on the device)
        strncpy( network.wifi_ssid,     prefs.getString( "wifi_ssid",  "" ).c_str(), sizeof(network.wifi_ssid) );
        strncpy( network.wifi_password, prefs.getString( "wifi_pass",  "" ).c_str(), sizeof(network.wifi_password) );

        // Door
        door.held_open_secs      = prefs.getUShort( "held_secs", 60 );
        door.forced_entry_detect = prefs.getBool( "forced_det", true );

        // Inputs
        for ( int i = 0; i < 4; i++ ) {
            char key[16];
            snprintf( key, 16, "in%d_fn", i );
            inputs[i].function = (InputFunction) prefs.getUChar( key, inputs[i].function );
            snprintf( key, 16, "in%d_lg", i );
            inputs[i].logic = (InputLogic) prefs.getUChar( key, inputs[i].logic );
        }

        // Relays
        for ( int i = 0; i < 2; i++ ) {
            char key[16];
            snprintf( key, 16, "rl%d_fn", i );
            relays[i].function = (RelayFunction) prefs.getUChar( key, relays[i].function );
            snprintf( key, 16, "rl%d_ms", i );
            relays[i].pulse_ms = prefs.getUShort( key, relays[i].pulse_ms );
            snprintf( key, 16, "rl%d_ah", i );
            relays[i].active_high = prefs.getBool( key, relays[i].active_high );
        }

        Serial.println("[CONFIG] Loaded from NVS");

#if ISLKEY_TEST_HARDCODE
        strncpy( network.wifi_ssid,     TEST_WIFI_SSID,  sizeof(network.wifi_ssid) - 1 );
        strncpy( network.wifi_password, TEST_WIFI_PASS,  sizeof(network.wifi_password) - 1 );
        strncpy( network.api_token,     TEST_API_TOKEN,  sizeof(network.api_token) - 1 );
        if ( strlen( TEST_API_URL ) > 0 ) {
            strncpy( network.api_url, TEST_API_URL, sizeof(network.api_url) - 1 );
        }
        Serial.printf("[CONFIG] *** TEST HARDCODE active *** SSID=%s api=%s\n",
            network.wifi_ssid, network.api_url );
#endif
    }

    void clear() {
        prefs.begin( "islkey", false );
        prefs.clear();
        prefs.end();
        Serial.println("[CONFIG] Cleared");
    }

    void save() {
        prefs.begin( "islkey", false );

        prefs.putString( "wifi_ssid",  network.wifi_ssid );
        prefs.putString( "wifi_pass",  network.wifi_password );
        prefs.putString( "api_url",    network.api_url );
        prefs.putString( "api_token",  network.api_token );
        prefs.putString( "door_name",  device.door_name );
        prefs.putString( "site_code",  device.site_code );
        prefs.putUShort( "held_secs",  door.held_open_secs );
        prefs.putBool(   "forced_det", door.forced_entry_detect );

        for ( int i = 0; i < 4; i++ ) {
            char key[16];
            snprintf( key, 16, "in%d_fn", i );
            prefs.putUChar( key, inputs[i].function );
            snprintf( key, 16, "in%d_lg", i );
            prefs.putUChar( key, inputs[i].logic );
        }

        for ( int i = 0; i < 2; i++ ) {
            char key[16];
            snprintf( key, 16, "rl%d_fn", i );
            prefs.putUChar( key, relays[i].function );
            snprintf( key, 16, "rl%d_ms", i );
            prefs.putUShort( key, relays[i].pulse_ms );
            snprintf( key, 16, "rl%d_ah", i );
            prefs.putBool( key, relays[i].active_high );
        }

        prefs.putBool( "provisioned", true );
        prefs.end();
        Serial.println("[CONFIG] Saved to NVS");
    }

    bool isProvisioned() {
#if ISLKEY_TEST_HARDCODE
        return true;   // skip the provisioning AP — using hardcoded test credentials
#else
        prefs.begin( "islkey", true );
        bool p = prefs.isKey( "provisioned" ) && prefs.getBool( "provisioned", false );
        prefs.end();
        return p;
#endif
    }

    void setNetwork( const char* ssid, const char* pass, const char* url, const char* token ) {
        strncpy( network.wifi_ssid,     ssid,  64 );
        strncpy( network.wifi_password, pass,  64 );
        strncpy( network.api_url,       url,   128 );
        strncpy( network.api_token,     token, 128 );
    }

    void setInput( int idx, InputFunction fn, InputLogic logic ) {
        if ( idx < 0 || idx > 3 ) return;
        inputs[idx].function = fn;
        inputs[idx].logic    = logic;
    }

    void setRelay( int idx, RelayFunction fn, uint16_t pulse_ms, bool active_high ) {
        if ( idx < 0 || idx > 1 ) return;
        relays[idx].function    = fn;
        relays[idx].pulse_ms    = pulse_ms;
        relays[idx].active_high = active_high;
    }

    void setDoor( uint16_t held_open_secs, bool forced_entry ) {
        door.held_open_secs      = held_open_secs;
        door.forced_entry_detect = forced_entry;
    }

    void setDevice( const char* name, const char* site_code ) {
        strncpy( device.door_name, name,      64 );
        strncpy( device.site_code, site_code, 16 );
    }

    void setIdentity( const char* serial, const char* ap_pwd ) {
        strncpy( device.serial, serial, sizeof(device.serial) - 1 );
        device.serial[ sizeof(device.serial) - 1 ] = '\0';
        strncpy( device.ap_pwd, ap_pwd, sizeof(device.ap_pwd) - 1 );
        device.ap_pwd[ sizeof(device.ap_pwd) - 1 ] = '\0';

        prefs.begin( "islkey", false );
        prefs.putString( "serial", device.serial );
        prefs.putString( "ap_pwd", device.ap_pwd );
        prefs.end();
        Serial.printf("[CONFIG] Identity stored: %s\n", device.serial );
    }

    void applyCommissionJson( const char* json ) {
        StaticJsonDocument<768> doc;
        if ( deserializeJson( doc, json ) != DeserializationError::Ok ) {
            Serial.println("[CONFIG] Commission JSON parse error");
            return;
        }

        prefs.begin( "islkey", false );

        auto setStr = [&]( const char* key, char* dst, size_t dstLen, const char* nvsKey ) {
            const char* v = doc[key] | (const char*)nullptr;
            if ( v && v[0] ) {
                strncpy( dst, v, dstLen - 1 );
                dst[dstLen - 1] = '\0';
                prefs.putString( nvsKey, dst );
            }
        };

        setStr( "serial",    device.serial,     sizeof(device.serial),     "serial" );
        setStr( "ap_pwd",    device.ap_pwd,     sizeof(device.ap_pwd),     "ap_pwd" );
        setStr( "api_url",   network.api_url,   sizeof(network.api_url),   "api_url" );
        setStr( "api_token", network.api_token, sizeof(network.api_token), "api_token" );
        setStr( "door_name", device.door_name,  sizeof(device.door_name),  "door_name" );
        setStr( "site_code", device.site_code,  sizeof(device.site_code),  "site_code" );

        // Optional WiFi supplied at flash time. If present, persist it and mark the
        // unit provisioned so it connects directly on next boot (skips the setup AP).
        setStr( "wifi_ssid", network.wifi_ssid,     sizeof(network.wifi_ssid),     "wifi_ssid" );
        setStr( "wifi_pass", network.wifi_password, sizeof(network.wifi_password), "wifi_pass" );
        if ( strlen( network.wifi_ssid ) > 0 ) {
            prefs.putBool( "provisioned", true );
            Serial.println("[CONFIG] WiFi supplied at commissioning — marked provisioned");
        }

        prefs.end();
        Serial.printf("[CONFIG] Commission applied: serial=%s door=%s api=%s wifi=%s\n",
            device.serial, device.door_name, network.api_url, network.wifi_ssid );
    }

    void setDeviceCreds( const char* device_uuid, const char* hmac_secret ) {
        strncpy( device.device_uuid, device_uuid, sizeof(device.device_uuid) - 1 );
        device.device_uuid[ sizeof(device.device_uuid) - 1 ] = '\0';
        strncpy( device.hmac_secret, hmac_secret, sizeof(device.hmac_secret) - 1 );
        device.hmac_secret[ sizeof(device.hmac_secret) - 1 ] = '\0';

        prefs.begin( "islkey", false );
        prefs.putString( "dev_uuid", device.device_uuid );
        prefs.putString( "hmac_sec", device.hmac_secret );
        prefs.end();
        Serial.printf("[CONFIG] Device creds stored: uuid=%s\n", device.device_uuid );
    }
}
