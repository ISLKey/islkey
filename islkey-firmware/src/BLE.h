/**
 * BLE.h / BLE.cpp — BLE GATT server for phone credential unlock
 *
 * Service UUID:      4fafc201-1fb5-459e-8fcc-c5c9c331914b
 * Unlock Char UUID:  beb5483e-36e1-4688-b7f5-ea07361b26a8  (WRITE)
 * Status Char UUID:  beb5483e-36e1-4688-b7f5-ea07361b26a9  (READ/NOTIFY)
 *
 * Unlock payload (JSON written to characteristic):
 * {
 *   "token": "<credential_token>",
 *   "ts": 1749916800,         // UTC epoch from phone
 *   "tz": 60                  // UTC offset in minutes
 * }
 *
 * Response (notified on status char):
 * {"result":"GRANTED"} or {"result":"DENIED","reason":"..."}
 */

#pragma once
#include <Arduino.h>

namespace BLE {
    void init();
    void loop();
    bool isConnected();
}
