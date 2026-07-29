ISLKey 1-MINI (V2.0.0) — Manufacturing Package (PCBWay)
========================================================

BOARD SPECS
-----------
  Size:            60 x 60 mm
  Layers:          2 (copper)
  Thickness:       1.6 mm
  Copper weight:   1 oz (35 um)
  Surface finish:  ENIG recommended (fine-pitch TSOT-23/SOT-23) — HASL OK
  Solder mask + silkscreen: both sides
  SPECIAL SHAPE:   two semicircular NOTCHES cut into the left/right edges at
                   mid-height (for a UK 1-gang back box's fixing screws,
                   ~62 mm centres) + one 8 mm round CUTOUT centred above the
                   TTGO. All defined on the Edge_Cuts / drill layers.

FILES
-----
  Gerbers:  F_Cu B_Cu F_Mask B_Mask F_Silkscreen B_Silkscreen F_Paste B_Paste Edge_Cuts (.gbr)
  Drill:    ISLKey-Mini.drl (Excellon) ;  Job: ISLKey-Mini-job.gbrjob
  CPL:      ISLKey-Mini-CPL.csv (pick & place)
  BOM:      ISLKey-Mini-BOM.csv  +  ISLKey-Mini-BOM-turnkey.csv (with MPNs)

ASSEMBLY NOTES
--------------
  * Mostly SMD (machine-place). THT parts: relay K1 (Omron G6E — order the
    5V-coil DC5 variant), the 3 Phoenix PT-3.5-H terminals.
  * M1 (TTGO T-Display) is customer-sourced and plugs into headers — do NOT
    reflow it; fit after assembly.
  * BOM MPNs/distributor PNs are indicative — confirm stock + the Phoenix
    PT-H horizontal order numbers before ordering PCBA.

FUNCTION
--------
  Single-relay door controller for behind an exit button / break-glass:
  12 VAC or 12 VDC in -> bridge -> 5 V buck -> TTGO; 1 relay (lock, dry
  COM/NO/NC); 1 exit input. Terminals labelled 12V / LOCK / EXIT on silk.
