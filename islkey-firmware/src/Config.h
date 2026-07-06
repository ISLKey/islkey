/**
 * Config.h — NVS-backed configuration storage
 * Stores all provisioning settings in ESP32 non-volatile storage
 */

#pragma once
#include <Preferences.h>
#include <Arduino.h>

// Input function types
enum InputFunction {
    INPUT_DISABLED    = 0,
    INPUT_EXIT_BTN    = 1,
    INPUT_DOOR_CONTACT= 2,
    INPUT_FIRE_ALARM  = 3,
    INPUT_TAMPER      = 4,
};

// Input logic
enum InputLogic {
    LOGIC_NC = 0,   // Normally Closed — LOW=secure, HIGH=triggered
    LOGIC_NO = 1,   // Normally Open   — HIGH=secure, LOW=triggered
};

// Relay function
enum RelayFunction {
    RELAY_DISABLED    = 0,
    RELAY_PRIMARY_LOCK= 1,
    RELAY_SECONDARY   = 2,
    RELAY_ALARM_OUT   = 3,
};

// Fail safe mode
enum FailSafe {
    FAIL_LOCKED = 0,
    FAIL_OPEN   = 1,
};

struct InputConfig {
    InputFunction function;
    InputLogic    logic;
};

struct RelayConfig {
    RelayFunction function;
    uint16_t      pulse_ms;      // How long relay energises for unlock (ms)
    bool          active_high;   // true = HIGH energises relay
};

struct DoorConfig {
    uint16_t held_open_secs;     // Alert if door open longer than this
    bool     forced_entry_detect;// Alert if door opens without valid access
};

struct DeviceConfig {
    char door_name[64];
    char site_code[16];
    char serial[24];        // Factory serial e.g. ISL-0006-20260614 (set via commissioning)
    char ap_pwd[16];        // Provisioning AP password (set via commissioning)
    char device_uuid[40];   // Server-assigned at /device/register
    char hmac_secret[80];   // HMAC-SHA256 key from /device/register (64 hex chars)
};

struct NetworkConfig {
    char wifi_ssid[64];
    char wifi_password[64];
    char api_url[128];
    char api_token[128];
};

namespace Config {

    extern InputConfig  inputs[4];
    extern RelayConfig  relays[2];
    extern DoorConfig   door;
    extern DeviceConfig device;
    extern NetworkConfig network;

    void init();
    void clear();
    void save();
    bool isProvisioned();

    // Individual setters called from provisioning page
    void setNetwork( const char* ssid, const char* pass, const char* url, const char* token );
    void setInput( int idx, InputFunction fn, InputLogic logic );
    void setRelay( int idx, RelayFunction fn, uint16_t pulse_ms, bool active_high );
    void setDoor( uint16_t held_open_secs, bool forced_entry );
    void setDevice( const char* name, const char* site_code );

    // Factory identity written by the flasher over serial (commissioning).
    // Persists in NVS independently of provisioning.
    void setIdentity( const char* serial, const char* ap_pwd );

    // Apply a full commissioning payload (compact JSON from the .islkey file):
    // serial, ap_pwd, api_url, api_token, door_name, site_code. Persists to NVS
    // WITHOUT marking the unit provisioned — WiFi is still entered on the device.
    void applyCommissionJson( const char* json );

    // Device credentials returned by /device/register (persisted to NVS).
    void setDeviceCreds( const char* device_uuid, const char* hmac_secret );
}
