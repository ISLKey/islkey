/**
 * Commission.cpp — factory identity commissioning over serial
 */

#include "Commission.h"
#include "Config.h"
#include <Arduino.h>
#include <string.h>

namespace Commission {

    static char   buf[640];
    static size_t len = 0;

    static void handleLine( char* line ) {
        static const char* PFX = "ISLKEY-PROV:";
        size_t pfxLen = strlen( PFX );
        if ( strncmp( line, PFX, pfxLen ) != 0 ) return;

        char* rest = line + pfxLen;

        if ( rest[0] == '{' ) {
            // Full config payload (serial, ap_pwd, api_url, api_token, door_name, site_code)
            Config::applyCommissionJson( rest );
        } else {
            // Legacy form: <serial>:<ap_pwd>
            char* sep = strchr( rest, ':' );
            if ( !sep ) return;
            *sep = '\0';
            if ( strlen( rest ) == 0 ) return;
            Config::setIdentity( rest, sep + 1 );
        }

        Serial.print("ISLKEY-ACK:");
        Serial.println( Config::device.serial );
        Serial.flush();

        // Restart so the provisioning AP comes up secured and config is reloaded
        delay( 250 );
        ESP.restart();
    }

    void poll() {
        while ( Serial.available() ) {
            char c = (char) Serial.read();
            if ( c == '\n' || c == '\r' ) {
                if ( len > 0 ) {
                    buf[len] = '\0';
                    handleLine( buf );
                    len = 0;
                }
            } else if ( len < sizeof(buf) - 1 ) {
                buf[len++] = c;
            } else {
                len = 0;   // overflow — discard
            }
        }
    }
}
