ISLKey TTGO Carrier Board — Manufacturing Package (PCBWay)
==========================================================

BOARD SPECS
-----------
  Size:            148.4 x 127.6 mm
  Layers:          2 (copper)
  Thickness:       1.6 mm (standard)
  Copper weight:   1 oz (35 um)
  Min track/space: 0.25 mm / 0.20 mm  (well within PCBWay standard)
  Min via drill:   0.40 mm, plated
  Surface finish:  ENIG recommended (fine-pitch SOIC-16 RTC) — HASL also OK
  Solder mask:     both sides;  Silkscreen: both sides
  Mounting holes:  4 x 3.2 mm (M3), unplated

FILES
-----
  Gerbers (RS-274X):  ISLKey-F_Cu / B_Cu / F_Mask / B_Mask /
                      F_Silkscreen / B_Silkscreen / F_Paste / B_Paste / Edge_Cuts .gbr
  Drill (Excellon):   ISLKey.drl
  Gerber job:         ISLKey-job.gbrjob
  Pick & place (CPL): ISLKey-CPL.csv   (ref, x/y mm, rotation, side)
  BOM:                ISLKey-BOM.csv   (refs, value, footprint, qty)

ASSEMBLY NOTES  (read before ordering PCBA)
-------------------------------------------
  * The BOM lists VALUE + FOOTPRINT but NOT manufacturer part numbers.
    For turnkey assembly you must add an MPN / supplier link per line, OR
    consign the parts. Key specific parts to pin down:
      U3  TMR10-2412WIR  (Traco, 9-36V->iso 12V 10W)
      U4  TSR-1-2450     (Traco, 12->5V SIP-3 buck)
      U5  DS3231M        (RTC, SOIC-16)
      U1  PC817          (opto, DIP-4)
      K1,K2  SRD-05VDC-SL-C (SANYOU/Songle 5V relay)
      BR1 KBU4M / any KBU 4A 1000V bridge
      F1  5x20 fuse holder + T2A fuse
      BT1 Keystone 1042 (1x18650) ; BT3 Keystone 3002 (CR2032)
  * Mixed technology: SMD passives/RTC (machine-place) + THT
    (relays, screw terminals, DC-DC modules, fuse holder, battery holders).
    THT is usually hand/selective-soldered — confirm scope with PCBWay.
  * M1 (TTGO T-Display) is a module that plugs into headers — do NOT have it
    reflowed; fit it after assembly.

CONFIG JUMPERS (fit shunt as needed)
------------------------------------
  J9  FIRE LINK  — links relay COM to the fire terminals (fire-alarm release)
  J15 DCDC ON    — ties the TMR10 Ctrl pin to +Vin (forces converter ON)
