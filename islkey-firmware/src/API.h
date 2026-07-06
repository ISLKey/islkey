/**
 * API.h / API.cpp — WordPress REST API client
 * Handles: heartbeat, event reporting, access log
 */

#pragma once
#include <Arduino.h>
#include "Inputs.h"

namespace API {

    // Live status for the display
    extern bool online;              // last cloud call succeeded
    extern char lastContact[24];     // time of last successful contact
    extern char lastEventName[40];   // most recent event reported
    extern char lastEventTime[24];   // when it was reported

    // Host portion of the configured API URL (for display)
    const char* host();

    void init();
    void loop();

    // Start the background networking task (all cloud HTTP runs there so the
    // main control loop never blocks on TLS).
    void startTask();

    // If a cloud UNLOCK command is pending, returns its relay index and clears it;
    // otherwise returns -1. Called from the main loop so the relay is driven from
    // a single thread.
    int consumeCloudUnlock();

    // Report a security input event to the cloud
    void reportEvent( Inputs::Event evt );

    // Report a BLE access attempt
    void reportBLEAccess( const char* token, bool granted );

    // Send device heartbeat with status
    void sendHeartbeat();
}
