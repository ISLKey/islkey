/**
 * Commission.h / Commission.cpp
 * Factory commissioning over the USB serial link.
 *
 * The ISLKey Flasher sends, after flashing:
 *     ISLKEY-PROV:<serial>:<ap_pwd>\n
 * The firmware stores the identity in NVS, replies:
 *     ISLKEY-ACK:<serial>\n
 * and restarts so the provisioning AP comes up secured with the new password.
 *
 * poll() is cheap and safe to call from any loop (main + provisioning).
 */

#pragma once

namespace Commission {
    void poll();
}
