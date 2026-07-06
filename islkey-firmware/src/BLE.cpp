/**
 * BLE.cpp — BLE GATT server implementation (NimBLE)
 *
 * Migrated from the Bluedroid stack to NimBLE to free heap. The Bluedroid
 * stack left too little memory for the WiFiClientSecure TLS handshake
 * (mbedtls RSA alloc failures, -17040), so the device could not reach the
 * cloud over HTTPS while BLE was active. NimBLE uses ~30-40 KB less RAM.
 *
 * Same service / characteristics / behaviour as before:
 *   Service:  4fafc201-1fb5-459e-8fcc-c5c9c331914b
 *   Unlock:   beb5483e-36e1-4688-b7f5-ea07361b26a8  (WRITE)
 *   Status:   beb5483e-36e1-4688-b7f5-ea07361b26a9  (READ/NOTIFY)
 */

#include "BLE.h"
#include "Config.h"
#include "Outputs.h"
#include "Network.h"
#include "LED.h"
#include "API.h"
#ifdef BOARD_TTGO
#include "Display.h"
#endif
#include <NimBLEDevice.h>
#include <ArduinoJson.h>

#define SERVICE_UUID         "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define UNLOCK_CHAR_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define STATUS_CHAR_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26a9"
// Provisioning (installer app): write config, notify status.
#define PROVISION_CHAR_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26aa"
#define PROV_STATUS_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26ab"

namespace BLE {

    static NimBLEServer*         pServer         = nullptr;
    static NimBLECharacteristic* pStatusChar     = nullptr;
    static NimBLECharacteristic* pProvStatusChar = nullptr;
    static bool                  deviceConnected = false;
    static bool                  oldConnected    = false;

    // Restart is scheduled from loop() (never inside a NimBLE callback).
    static bool                  provRestartPending = false;
    static unsigned long         provRestartAt      = 0;

    // Notify provisioning status to the app + mirror on the LCD.
    static void notifyProv( const char* state, const char* msg ) {
        char buf[96];
        snprintf( buf, sizeof(buf), "{\"state\":\"%s\",\"msg\":\"%s\"}", state, msg ? msg : "" );
        if ( pProvStatusChar ) {
            pProvStatusChar->setValue( std::string( buf ) );
            pProvStatusChar->notify();
        }
        Serial.printf("[PROV-BLE] %s\n", buf );
#ifdef BOARD_TTGO
        Display::setProvisioningStatus( msg && msg[0] ? msg : state, nullptr );
#endif
    }

    // ── Validate credential token ──────────────────────────────────────────────
    bool validateToken( const char* token, uint32_t ts, int16_t tz ) {
        // Update clock from phone time
        Network::updateTimeFromBLE( ts, tz );

        if ( strlen( token ) < 16 ) {
            Serial.println("[BLE] Token too short — denied");
            return false;
        }

        // TODO v1.1: check token against NVS credential cache
        Serial.printf("[BLE] Token received: %.8s... — granted (prototype mode)\n", token );
        return true;
    }

    // ── Unlock write callback ──────────────────────────────────────────────────
    class UnlockCallback : public NimBLECharacteristicCallbacks {
        void onWrite( NimBLECharacteristic* pChar ) override {
            std::string value = pChar->getValue();
            if ( value.empty() ) return;

            Serial.printf("[BLE] Received unlock payload (%d bytes)\n", value.length() );
            LED::set( LED::WHITE, LED::SOLID );

            // Parse JSON payload
            StaticJsonDocument<256> doc;
            DeserializationError err = deserializeJson( doc, value.c_str() );
            if ( err ) {
                Serial.println("[BLE] JSON parse error — denied");
                pStatusChar->setValue( std::string("{\"result\":\"DENIED\",\"reason\":\"bad_payload\"}") );
                pStatusChar->notify();
                LED::set( LED::RED, LED::FLASH );
                return;
            }

            const char* token = doc["token"] | "";
            uint32_t    ts    = doc["ts"]    | 0;
            int16_t     tz    = doc["tz"]    | 0;

            if ( validateToken( token, ts, tz ) ) {
                pStatusChar->setValue( std::string("{\"result\":\"GRANTED\"}") );
                pStatusChar->notify();
                Outputs::accessGranted( 0 );   // Trigger relay 1
                API::reportBLEAccess( token, true );
                Serial.println("[BLE] Access GRANTED");
            } else {
                pStatusChar->setValue( std::string("{\"result\":\"DENIED\",\"reason\":\"invalid_token\"}") );
                pStatusChar->notify();
                LED::set( LED::RED, LED::PULSE );
                API::reportBLEAccess( token, false );
                Serial.println("[BLE] Access DENIED");
            }
        }
    };

    // ── Provisioning write callback (installer app) ────────────────────────────
    // Payload: { wifi_ssid, wifi_pass, api_url, token, door_name, site_code }
    // We persist the config (marking the unit provisioned) and restart; the
    // normal boot path then connects WiFi and registers with the cloud using
    // `token` — which credits the installer's reward points for this device.
    class ProvisionCallback : public NimBLECharacteristicCallbacks {
        void onWrite( NimBLECharacteristic* pChar ) override {
            std::string value = pChar->getValue();
            if ( value.empty() ) return;
            Serial.printf("[PROV-BLE] Received provisioning payload (%d bytes)\n", (int)value.length() );

            StaticJsonDocument<512> doc;
            if ( deserializeJson( doc, value.c_str() ) != DeserializationError::Ok ) {
                notifyProv( "error", "Bad payload" );
                return;
            }

            const char* ssid    = doc["wifi_ssid"] | "";
            const char* pass     = doc["wifi_pass"] | "";
            const char* apiUrl   = doc["api_url"]   | "";
            const char* token    = doc["token"]     | "";
            const char* doorName = doc["door_name"] | "";
            const char* siteCode = doc["site_code"] | "";

            if ( strlen( ssid ) == 0 || strlen( token ) == 0 ) {
                notifyProv( "error", "Missing wifi or token" );
                return;
            }

            notifyProv( "received", "Config received" );

            // Persist. api_url falls back to whatever was commissioned if blank.
            const char* url = strlen( apiUrl ) > 0 ? apiUrl : Config::network.api_url;
            Config::setNetwork( ssid, pass, url, token );
            if ( strlen( doorName ) > 0 || strlen( siteCode ) > 0 ) {
                Config::setDevice(
                    strlen( doorName ) > 0 ? doorName : Config::device.door_name,
                    strlen( siteCode ) > 0 ? siteCode : Config::device.site_code );
            }
            Config::save();   // marks the unit provisioned

            notifyProv( "saved", "Saved. Restarting to register" );

            // Restart shortly so the notify is delivered first.
            provRestartAt      = millis() + 2500;
            provRestartPending = true;
        }
    };

    // ── Server callbacks ───────────────────────────────────────────────────────
    class ServerCallbacks : public NimBLEServerCallbacks {
        void onConnect( NimBLEServer* pServer ) override {
            deviceConnected = true;
            LED::set( LED::WHITE, LED::SOLID );
            Serial.println("[BLE] Phone connected");
        }
        void onDisconnect( NimBLEServer* pServer ) override {
            deviceConnected = false;
            Serial.println("[BLE] Phone disconnected");
        }
    };

    void init() {
        // Build device name from last 4 of MAC
        uint8_t mac[6];
        esp_read_mac( mac, ESP_MAC_WIFI_STA );
        char devName[32];
        snprintf( devName, 32, "ISLKey-%02X%02X", mac[4], mac[5] );

        NimBLEDevice::init( devName );

        pServer = NimBLEDevice::createServer();
        pServer->setCallbacks( new ServerCallbacks() );

        NimBLEService* pService = pServer->createService( SERVICE_UUID );

        // Unlock characteristic — phone writes credential here
        NimBLECharacteristic* pUnlockChar = pService->createCharacteristic(
            UNLOCK_CHAR_UUID,
            NIMBLE_PROPERTY::WRITE
        );
        pUnlockChar->setCallbacks( new UnlockCallback() );

        // Status characteristic — ESP32 notifies result here.
        // NimBLE auto-adds the 0x2902 CCCD for NOTIFY characteristics.
        pStatusChar = pService->createCharacteristic(
            STATUS_CHAR_UUID,
            NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
        );
        pStatusChar->setValue( std::string("ready") );

        // Provisioning characteristic — installer app writes WiFi + token here
        NimBLECharacteristic* pProvChar = pService->createCharacteristic(
            PROVISION_CHAR_UUID,
            NIMBLE_PROPERTY::WRITE
        );
        pProvChar->setCallbacks( new ProvisionCallback() );

        // Provisioning status — ESP32 notifies provisioning progress here
        pProvStatusChar = pService->createCharacteristic(
            PROV_STATUS_UUID,
            NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
        );
        pProvStatusChar->setValue( std::string("{\"state\":\"ready\"}") );

        pService->start();

        // Advertise
        NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
        pAdvertising->addServiceUUID( SERVICE_UUID );
        pAdvertising->setScanResponse( true );
        NimBLEDevice::startAdvertising();

        Serial.printf("[BLE] Advertising as: %s (NimBLE)\n", devName );
    }

    void loop() {
        // Scheduled restart after a successful BLE provisioning.
        if ( provRestartPending && millis() > provRestartAt ) {
            Serial.println("[PROV-BLE] Restarting to apply provisioning");
            delay( 100 );
            ESP.restart();
        }

        // Restart advertising after phone disconnects
        if ( !deviceConnected && oldConnected ) {
            delay( 500 );
            NimBLEDevice::startAdvertising();
            LED::set( LED::BLUE, LED::SOLID );
            Serial.println("[BLE] Restarted advertising");
            oldConnected = false;
        }
        if ( deviceConnected && !oldConnected ) {
            oldConnected = true;
        }
    }

    bool isConnected() {
        return deviceConnected;
    }
}
