/**
 * Display.cpp — TTGO T-Display screen implementation
 */

#include "Display.h"

#ifdef BOARD_TTGO

#include <TFT_eSPI.h>
#include "Config.h"
#include "Inputs.h"   // for the input GPIO numbers shown on the inputs screen

// TTGO T-Display button GPIOs
#define BTN_TOP    0
#define BTN_BOTTOM 35
#define BACKLIGHT  4    // TFT backlight pin on TTGO

namespace Display {

    TFT_eSPI tft = TFT_eSPI();

    // ── State ──────────────────────────────────────────────────────────────────
    static char serial[24]     = "—";
    static char apPwd[16]      = "—";
    static char siteCode[16]   = "";
    static char doorName[64]   = "ISLKey Door";

    static char ssid[64]       = "";
    static char ipAddr[20]     = "0.0.0.0";
    static bool netConnected   = false;
    static int  rssi           = 0;

    static char apiHost[64]    = "(not set)";
    static bool apiOnline      = false;
    static char apiContact[24] = "never";
    static char apiEvent[40]   = "none";
    static char apiEventTime[24] = "";

    static bool bleConnected   = false;
    static char lastAccess[40] = "none";
    static bool lastGranted    = false;

    static bool doorOpen       = false;
    static bool fireAlarm      = false;
    static bool tamper         = false;
    static bool inLive[4]      = { false, false, false, false };   // real-time input triggered state

    static char timeStr[12]    = "--:--";

    static bool apActive       = false;
    static char apName[24]     = "ISLKey";

    // Full-screen provisioning status overlay (app/BLE provisioning)
    static bool provStatusActive = false;
    static char provLine1[28]    = "";
    static char provLine2[40]    = "";

    static int  currentScreen  = 0;
    static bool backlightOn    = true;

    static unsigned long lastDraw   = 0;
    static unsigned long lastBtnTop = 0;
    static unsigned long lastBtnBot = 0;
    static unsigned long flashUntil = 0;

    #define DRAW_INTERVAL_MS  500
    #define BTN_DEBOUNCE_MS   220

    // Colours (RGB565)
    #define C_BG      0x0821
    #define C_ACCENT  0x04FF
    #define C_GREEN   0x07E0
    #define C_RED     0xF800
    #define C_AMBER   0xFD00
    #define C_WHITE   0xFFFF
    #define C_MUTED   0x4A69
    #define C_DARK    0x1082

    const int NUM_SCREENS = 7;

    // ── Helpers ────────────────────────────────────────────────────────────────
    void setBacklight( bool on ) {
        backlightOn = on;
        analogWrite( BACKLIGHT, on ? 255 : 0 );
    }

    void drawHeader( const char* title ) {
        tft.fillRect( 0, 0, 240, 22, C_ACCENT );
        tft.setTextColor( C_WHITE, C_ACCENT );
        tft.setTextSize( 1 );
        tft.setCursor( 6, 7 );
        tft.print( title );
        tft.setCursor( 200, 7 );
        tft.print( timeStr );
    }

    void drawFooter() {
        tft.fillRect( 0, 118, 240, 17, C_DARK );
        tft.setTextColor( C_MUTED, C_DARK );
        tft.setTextSize( 1 );
        tft.setCursor( 6, 123 );
        tft.printf( "[%d/%d]  TOP:next  BOT:light", currentScreen + 1, NUM_SCREENS );
    }

    // label/value row helper
    void row( int y, const char* label, const char* value, uint16_t valCol = C_WHITE ) {
        tft.setTextSize( 1 );
        tft.setTextColor( C_MUTED, C_BG );
        tft.setCursor( 6, y );
        tft.print( label );
        tft.setTextColor( valCol, C_BG );
        tft.setCursor( 6, y + 11 );
        tft.print( value );
    }

    // ── Screen 0 : Identity ─────────────────────────────────────────────────────
    void drawIdentity() {
        tft.fillScreen( C_BG );
        drawHeader( "IDENTITY" );

        tft.setTextColor( C_MUTED, C_BG );
        tft.setTextSize( 1 );
        tft.setCursor( 6, 28 );
        tft.print( "Serial Number" );
        tft.setTextColor( C_ACCENT, C_BG );
        tft.setTextSize( 2 );
        tft.setCursor( 6, 39 );
        tft.print( serial );

        tft.setTextColor( C_MUTED, C_BG );
        tft.setTextSize( 1 );
        tft.setCursor( 6, 62 );
        tft.print( "Setup AP Password" );
        tft.setTextColor( C_AMBER, C_BG );
        tft.setTextSize( 2 );
        tft.setCursor( 6, 73 );
        tft.print( strlen( apPwd ) ? apPwd : "(open)" );

        tft.setTextSize( 1 );
        tft.setTextColor( C_MUTED, C_BG );
        tft.setCursor( 6, 98 );
        tft.print( "Door: " );
        tft.setTextColor( C_WHITE, C_BG );
        tft.print( doorName );
        tft.setTextColor( C_MUTED, C_BG );
        tft.setCursor( 6, 108 );
        tft.print( "Site: " );
        tft.setTextColor( C_WHITE, C_BG );
        tft.print( strlen( siteCode ) ? siteCode : "-" );

        drawFooter();
    }

    // ── Screen 1 : Door ──────────────────────────────────────────────────────────
    void drawDoor() {
        tft.fillScreen( C_BG );
        drawHeader( "DOOR STATUS" );

        tft.setTextColor( C_WHITE, C_BG );
        tft.setTextSize( 2 );
        tft.setCursor( 6, 28 );
        tft.print( doorName );

        tft.fillRect( 6, 52, 228, 30, doorOpen ? 0x6200 : 0x0320 );
        tft.setTextColor( doorOpen ? C_RED : C_GREEN, doorOpen ? 0x6200 : 0x0320 );
        tft.setTextSize( 2 );
        tft.setCursor( 12, 59 );
        tft.print( doorOpen ? "DOOR OPEN" : "DOOR CLOSED" );

        int y = 90;
        if ( fireAlarm ) {
            tft.fillRect( 6, y, 228, 20, 0x6200 );
            tft.setTextColor( C_RED, 0x6200 );
            tft.setTextSize( 1 );
            tft.setCursor( 12, y + 6 );
            tft.print( "!! FIRE ALARM ACTIVE" );
            y += 22;
        }
        if ( tamper ) {
            tft.fillRect( 6, y, 228, 20, 0x4200 );
            tft.setTextColor( C_AMBER, 0x4200 );
            tft.setTextSize( 1 );
            tft.setCursor( 12, y + 6 );
            tft.print( "!! TAMPER DETECTED" );
        }
        drawFooter();
    }

    // ── Screen 2 : Wi-Fi (setup AP mode or connected) ───────────────────────────
    void drawWiFi() {
        tft.fillScreen( C_BG );
        drawHeader( "WI-FI" );

        if ( apActive ) {
            // Provisioning / setup mode
            tft.fillRect( 6, 28, 228, 18, 0x4200 );
            tft.setTextColor( C_AMBER, 0x4200 );
            tft.setTextSize( 1 );
            tft.setCursor( 12, 34 );
            tft.print( "SETUP MODE - JOIN THIS NETWORK" );

            row( 50, "Network (SSID)", apName, C_WHITE );
            row( 74, "Password", strlen( apPwd ) ? apPwd : "(open)", C_AMBER );
            row( 98, "Then browse to", "http://192.168.4.1", C_ACCENT );
        } else {
            tft.fillRect( 6, 28, 90, 18, netConnected ? 0x0320 : C_DARK );
            tft.setTextColor( netConnected ? C_GREEN : C_MUTED,
                              netConnected ? 0x0320 : C_DARK );
            tft.setTextSize( 1 );
            tft.setCursor( 12, 34 );
            tft.print( netConnected ? "CONNECTED" : "OFFLINE" );

            row( 50, "Network (SSID)", strlen( ssid ) ? ssid : "(not set)", C_WHITE );

            tft.setTextColor( C_MUTED, C_BG );
            tft.setCursor( 6, 74 );
            tft.print( "IP Address" );
            tft.setTextColor( C_WHITE, C_BG );
            tft.setCursor( 6, 85 );
            tft.print( ipAddr );

            tft.setTextColor( C_MUTED, C_BG );
            tft.setCursor( 130, 74 );
            tft.print( "Signal" );
            uint16_t barCol = rssi > -60 ? C_GREEN : rssi > -75 ? C_AMBER : C_RED;
            tft.setTextColor( netConnected ? barCol : C_MUTED, C_BG );
            tft.setCursor( 130, 85 );
            if ( netConnected ) tft.printf( "%d dBm", rssi );
            else                tft.print( "--" );

            int barW = netConnected ? max( 4, min( 228, (rssi + 100) * 4 ) ) : 0;
            tft.fillRect( 6, 100, 228, 8, C_DARK );
            tft.fillRect( 6, 100, barW, 8, barCol );
        }
        drawFooter();
    }

    // ── Screen 3 : Cloud / API ──────────────────────────────────────────────────
    void drawCloud() {
        tft.fillScreen( C_BG );
        drawHeader( "CLOUD / API" );

        tft.fillRect( 6, 28, 90, 18, apiOnline ? 0x0320 : 0x6200 );
        tft.setTextColor( apiOnline ? C_GREEN : C_RED, apiOnline ? 0x0320 : 0x6200 );
        tft.setTextSize( 1 );
        tft.setCursor( 12, 34 );
        tft.print( apiOnline ? "ONLINE" : "OFFLINE" );

        row( 50, "Server", apiHost, C_WHITE );

        tft.setTextColor( C_MUTED, C_BG );
        tft.setCursor( 6, 74 );
        tft.print( "Last contact" );
        tft.setTextColor( C_WHITE, C_BG );
        tft.setCursor( 6, 85 );
        tft.print( apiContact );

        tft.setTextColor( C_MUTED, C_BG );
        tft.setCursor( 6, 98 );
        tft.print( "Last event" );
        tft.setTextColor( C_ACCENT, C_BG );
        tft.setCursor( 6, 108 );
        tft.print( apiEvent );
        if ( strlen( apiEventTime ) ) {
            tft.setTextColor( C_MUTED, C_BG );
            tft.print( "  " );
            tft.print( apiEventTime );
        }
        drawFooter();
    }

    // ── Screen 4 : BLE / Access ─────────────────────────────────────────────────
    void drawBLE() {
        tft.fillScreen( C_BG );
        drawHeader( "BLE / ACCESS" );

        tft.fillRect( 6, 28, 228, 22, bleConnected ? 0x000F : C_DARK );
        tft.setTextColor( bleConnected ? C_WHITE : C_MUTED,
                          bleConnected ? 0x000F : C_DARK );
        tft.setTextSize( 1 );
        tft.setCursor( 12, 35 );
        tft.print( bleConnected ? "BLE: PHONE CONNECTED" : "BLE: ADVERTISING" );

        tft.setTextColor( C_MUTED, C_BG );
        tft.setCursor( 6, 60 );
        tft.print( "Last access result" );
        tft.setTextColor( lastGranted ? C_GREEN : C_RED, C_BG );
        tft.setTextSize( 2 );
        tft.setCursor( 6, 72 );
        tft.print( lastGranted ? "GRANTED" : "DENIED" );

        tft.setTextSize( 1 );
        tft.setTextColor( C_WHITE, C_BG );
        tft.setCursor( 6, 98 );
        tft.print( lastAccess );

        drawFooter();
    }

    // ── Screen 5 : Inputs ────────────────────────────────────────────────────────
    void drawInputs() {
        tft.fillScreen( C_BG );
        drawHeader( "SECURITY INPUTS" );

        const char* fn_labels[] = { "Disabled", "Exit Button", "Door Contact", "Fire Alarm", "Tamper" };
        const int   inPins[4]   = { INPUT_1_PIN, INPUT_2_PIN, INPUT_3_PIN, INPUT_4_PIN };

        for ( int i = 0; i < 4; i++ ) {
            int y = 28 + (i * 22);
            InputFunction fn = Config::inputs[i].function;
            bool trig = inLive[i];                       // real-time pin state
            bool disabled = ( fn == INPUT_DISABLED );

            uint16_t bg = disabled ? C_DARK : ( trig ? 0x6200 : 0x0320 );  // red if triggered, green if clear
            tft.fillRect( 6, y, 228, 20, bg );

            // Label: IN1 (G13) Exit Button
            tft.setTextSize( 1 );
            tft.setTextColor( C_WHITE, bg );
            tft.setCursor( 12, y + 6 );
            tft.printf( "IN%d G%d %s", i + 1, inPins[i], fn_labels[fn] );

            // Live status pill on the right
            const char* st = disabled ? "—" : ( trig ? "TRIGGERED" : "CLEAR" );
            uint16_t stc   = disabled ? C_MUTED : ( trig ? C_RED : C_GREEN );
            tft.setTextColor( stc, bg );
            tft.setCursor( 168, y + 6 );
            tft.print( st );
        }
        drawFooter();
    }

    // ── Screen 6 : Device ────────────────────────────────────────────────────────
    void drawDevice() {
        tft.fillScreen( C_BG );
        drawHeader( "DEVICE INFO" );

        row( 28, "Firmware / Board", "v1.0.0  TTGO T-Display", C_WHITE );
        row( 52, "IP Address", apActive ? "192.168.4.1 (AP)" : ipAddr, C_WHITE );

        unsigned long upSec  = millis() / 1000;
        char uptimeBuf[24];
        snprintf( uptimeBuf, sizeof(uptimeBuf), "%luh %02lum %02lus",
                  upSec / 3600, (upSec % 3600) / 60, upSec % 60 );
        row( 76, "Uptime", uptimeBuf, C_WHITE );

        char heapBuf[24];
        snprintf( heapBuf, sizeof(heapBuf), "%u KB free", (unsigned)(ESP.getFreeHeap() / 1024) );
        row( 100, "Memory", heapBuf, C_WHITE );

        drawFooter();
    }

    void drawProvStatus() {
        tft.fillScreen( C_BG );
        tft.fillRect( 0, 0, 240, 22, C_ACCENT );
        tft.setTextColor( C_WHITE, C_ACCENT );
        tft.setTextSize( 1 );
        tft.setCursor( 6, 7 );
        tft.print( "PROVISIONING" );

        tft.setTextColor( C_WHITE, C_BG );
        tft.setTextSize( 2 );
        tft.setCursor( 10, 48 );
        tft.print( provLine1 );

        if ( provLine2[0] ) {
            tft.setTextColor( C_MUTED, C_BG );
            tft.setTextSize( 1 );
            tft.setCursor( 10, 80 );
            tft.print( provLine2 );
        }
    }

    void drawCurrentScreen() {
        if ( millis() < flashUntil ) return;   // flash has priority
        if ( provStatusActive ) { drawProvStatus(); return; }  // overrides all screens
        switch ( currentScreen ) {
            case 0: drawIdentity(); break;
            case 1: drawDoor();     break;
            case 2: drawWiFi();     break;
            case 3: drawCloud();    break;
            case 4: drawBLE();      break;
            case 5: drawInputs();   break;
            case 6: drawDevice();   break;
        }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────────
    void init() {
        pinMode( BTN_TOP,    INPUT_PULLUP );
        pinMode( BTN_BOTTOM, INPUT_PULLUP );
        pinMode( BACKLIGHT,  OUTPUT );
        setBacklight( true );

        tft.init();
        tft.setRotation( 1 );    // landscape, 240x135
        tft.fillScreen( C_BG );

        // Boot splash
        tft.setTextColor( C_ACCENT, C_BG );
        tft.setTextSize( 3 );
        tft.setCursor( 40, 34 );
        tft.print( "ISLKey" );
        tft.setTextSize( 1 );
        tft.setTextColor( C_MUTED, C_BG );
        tft.setCursor( 40, 72 );
        tft.print( "Access Control Platform" );
        tft.setCursor( 40, 86 );
        tft.print( "ISL Technologies" );

        strncpy( doorName, Config::device.door_name, sizeof(doorName) );
        strncpy( siteCode, Config::device.site_code, sizeof(siteCode) );
        if ( strlen( Config::device.serial ) ) strncpy( serial, Config::device.serial, sizeof(serial) );
        if ( strlen( Config::device.ap_pwd ) ) strncpy( apPwd,  Config::device.ap_pwd,  sizeof(apPwd) );

        Serial.println("[DISPLAY] Initialised");
        delay( 1500 );
    }

    void showAccessFlash( bool granted ) {
        tft.fillScreen( granted ? C_GREEN : C_RED );
        tft.setTextColor( C_BG, granted ? C_GREEN : C_RED );
        tft.setTextSize( 3 );
        tft.setCursor( granted ? 40 : 50, 50 );
        tft.print( granted ? "GRANTED" : "DENIED" );
        flashUntil = millis() + 1500;
    }

    void loop() {
        unsigned long now = millis();

        if ( flashUntil > 0 && now > flashUntil ) {
            flashUntil = 0;
            drawCurrentScreen();
        }

        if ( digitalRead( BTN_TOP ) == LOW ) {
            if ( now - lastBtnTop > BTN_DEBOUNCE_MS ) {
                lastBtnTop = now;
                currentScreen = ( currentScreen + 1 ) % NUM_SCREENS;
                drawCurrentScreen();
            }
        }

        if ( digitalRead( BTN_BOTTOM ) == LOW ) {
            if ( now - lastBtnBot > BTN_DEBOUNCE_MS ) {
                lastBtnBot = now;
                setBacklight( !backlightOn );
            }
        }

        if ( now - lastDraw > DRAW_INTERVAL_MS && flashUntil == 0 ) {
            lastDraw = now;
            drawCurrentScreen();
        }
    }

    // ── Setters ──────────────────────────────────────────────────────────────────
    void setIdentity( const char* s, const char* p, const char* sc ) {
        if ( s && strlen(s) ) strncpy( serial, s, sizeof(serial) );
        if ( p && strlen(p) ) strncpy( apPwd,  p, sizeof(apPwd) );
        if ( sc ) strncpy( siteCode, sc, sizeof(siteCode) );
    }
    void setDoorName( const char* n ) { strncpy( doorName, n, sizeof(doorName) ); }
    void setWiFi( const char* s, bool c, const char* ip, int r ) {
        strncpy( ssid, s, sizeof(ssid) );
        netConnected = c;
        strncpy( ipAddr, ip, sizeof(ipAddr) );
        rssi = r;
    }
    void setCloud( const char* h, bool online, const char* contact,
                   const char* ev, const char* evTime ) {
        strncpy( apiHost, h, sizeof(apiHost) );
        apiOnline = online;
        strncpy( apiContact, contact, sizeof(apiContact) );
        strncpy( apiEvent, ev, sizeof(apiEvent) );
        strncpy( apiEventTime, evTime, sizeof(apiEventTime) );
    }
    void setProvisioningStatus( const char* line1, const char* line2 ) {
        if ( line1 == nullptr ) {
            provStatusActive = false;
            lastDraw = 0;           // force a normal redraw next loop
            return;
        }
        provStatusActive = true;
        strncpy( provLine1, line1, sizeof(provLine1) - 1 );
        provLine1[ sizeof(provLine1) - 1 ] = '\0';
        provLine2[0] = '\0';
        if ( line2 ) {
            strncpy( provLine2, line2, sizeof(provLine2) - 1 );
            provLine2[ sizeof(provLine2) - 1 ] = '\0';
        }
        flashUntil = 0;
        drawProvStatus();           // show immediately
    }

    void setBLEStatus( bool c ) { bleConnected = c; }
    void setLastAccess( const char* ev, bool g ) {
        strncpy( lastAccess, ev, sizeof(lastAccess) );
        lastGranted = g;
    }
    void setInputStates( bool d, bool f, bool t ) {
        doorOpen = d; fireAlarm = f; tamper = t;
    }
    void setInputLive( bool i1, bool i2, bool i3, bool i4 ) {
        inLive[0] = i1; inLive[1] = i2; inLive[2] = i3; inLive[3] = i4;
    }
    void setTime( struct tm* ti ) {
        snprintf( timeStr, sizeof(timeStr), "%02d:%02d", ti->tm_hour, ti->tm_min );
    }
    void setProvisioning( bool inAP, const char* name ) {
        apActive = inAP;
        if ( name ) strncpy( apName, name, sizeof(apName) );
    }
}

#endif // BOARD_TTGO
