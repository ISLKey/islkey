/**
 * LED.cpp — RGB and onboard LED implementation
 */

#include "LED.h"

namespace LED {

    static Colour  currentColour  = OFF;
    static Pattern currentPattern = SOLID;
    static unsigned long lastToggle = 0;
    static bool    ledState = false;
    static int     flashCount = 0;

    struct RGB { uint8_t r, g, b; };

    RGB colourToRGB( Colour c ) {
        switch ( c ) {
            case RED:    return { 255, 0,   0   };
            case GREEN:  return { 0,   255, 0   };
            case BLUE:   return { 0,   0,   255 };
            case WHITE:  return { 255, 255, 255 };
            case ORANGE: return { 255, 80,  0   };
            case CYAN:   return { 0,   255, 255 };
            default:     return { 0,   0,   0   };
        }
    }

    void applyRGB( RGB rgb ) {
#ifndef BOARD_TTGO
        // Common anode: HIGH = off, LOW = on — adjust if common cathode
        analogWrite( LED_R_PIN, rgb.r );
        analogWrite( LED_G_PIN, rgb.g );
        analogWrite( LED_B_PIN, rgb.b );
#else
        (void) rgb;   // RGB LED disabled on TTGO — GPIO25/26/27 are free header pins
#endif
    }

    void init() {
#ifndef BOARD_TTGO
        pinMode( LED_R_PIN,  OUTPUT );
        pinMode( LED_G_PIN,  OUTPUT );
        pinMode( LED_B_PIN,  OUTPUT );
        applyRGB( { 0, 0, 0 } );
        // On the TTGO T-Display GPIO23 is the TFT reset line — never drive it as the onboard LED
        pinMode( LED_OB_PIN, OUTPUT );
        digitalWrite( LED_OB_PIN, LOW );
#endif
        // On TTGO the RGB pins (25/26/27) are repurposed as free I/O — LED is a no-op
    }

    void set( Colour colour, Pattern pattern ) {
        currentColour  = colour;
        currentPattern = pattern;
        lastToggle     = 0;
        ledState       = true;
        flashCount     = 0;

        if ( pattern == SOLID ) {
            applyRGB( colourToRGB( colour ) );
#ifndef BOARD_TTGO
            digitalWrite( LED_OB_PIN, colour != OFF ? HIGH : LOW );
#endif
        }
    }

    void off() {
        currentColour  = OFF;
        currentPattern = SOLID;
        applyRGB( { 0, 0, 0 } );
#ifndef BOARD_TTGO
        digitalWrite( LED_OB_PIN, LOW );
#endif
    }

    void loop() {
        if ( currentPattern == SOLID ) return;

        unsigned long now = millis();

        switch ( currentPattern ) {

            case BLINK_SLOW: {
                if ( now - lastToggle > 1000 ) {
                    ledState = !ledState;
                    lastToggle = now;
                    applyRGB( ledState ? colourToRGB( currentColour ) : RGB{0,0,0} );
                }
                break;
            }

            case BLINK_FAST: {
                if ( now - lastToggle > 200 ) {
                    ledState = !ledState;
                    lastToggle = now;
                    applyRGB( ledState ? colourToRGB( currentColour ) : RGB{0,0,0} );
                }
                break;
            }

            case FLASH: {
                // Single 200ms flash then off
                if ( lastToggle == 0 ) {
                    lastToggle = now;
                    applyRGB( colourToRGB( currentColour ) );
                } else if ( now - lastToggle > 200 ) {
                    off();
                }
                break;
            }

            case PULSE: {
                // 3 fast flashes then off
                if ( flashCount >= 6 ) {
                    off();
                    return;
                }
                if ( now - lastToggle > 150 ) {
                    ledState = !ledState;
                    lastToggle = now;
                    flashCount++;
                    applyRGB( ledState ? colourToRGB( currentColour ) : RGB{0,0,0} );
                }
                break;
            }

            default: break;
        }
    }
}
