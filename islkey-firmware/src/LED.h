/**
 * LED.h / LED.cpp — RGB status LED and onboard LED control
 */

#pragma once
#include <Arduino.h>

#define LED_R_PIN  25
#define LED_G_PIN  26
#define LED_B_PIN  27
#define LED_OB_PIN 23   // Onboard LED

namespace LED {

    enum Colour {
        OFF    = 0,
        RED    = 1,
        GREEN  = 2,
        BLUE   = 3,
        WHITE  = 4,
        ORANGE = 5,
        CYAN   = 6,
    };

    enum Pattern {
        SOLID      = 0,
        BLINK_SLOW = 1,   // 1s on / 1s off
        BLINK_FAST = 2,   // 200ms on / 200ms off
        FLASH      = 3,   // single 200ms flash then off
        PULSE      = 4,   // 3 fast flashes then off
    };

    void init();
    void set( Colour colour, Pattern pattern );
    void loop();
    void off();
}
