/**
 * Provision.h / Provision.cpp
 * Creates WiFi AP "ISLKey-Setup-XXXX" and serves a config web page at 192.168.4.1
 * All settings are configured here and saved to NVS before normal boot
 */

#pragma once

namespace Provision {
    void startAP();
}
