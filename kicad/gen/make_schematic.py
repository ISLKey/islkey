"""Generate the ISLKey TTGO carrier-board schematic using REAL KiCad 10 library
symbols (correct pin<->pad maps) with footprints assigned, so the netlist, PCB
and BOM are all consistent.

Connectivity is by net name: every pin gets a short on-grid stub + a global
label (unused connector pins get a no-connect). This is electrically identical
to drawn wires for netlist/PCB/BOM purposes and keeps the geometry ERC-clean.
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(__file__))
from kicad_lib import extract_symbol, rename_symbol, parse_pins, U

OUT = r"C:\src\islkey\kicad\ISLKey.kicad_sch"
ROOT = U()
STUB = 3.81  # mm, multiple of 1.27 -> stays on grid

# ── symbol catalogue: lib_id -> (lib file, symbol name) ───────────────────────
CAT = {
    "Device:R":                 ("Device.kicad_sym", "R"),
    "Device:C":                 ("Device.kicad_sym", "C"),
    "Device:C_Polarized":       ("Device.kicad_sym", "C_Polarized"),
    "Device:LED":               ("Device.kicad_sym", "LED"),
    "Device:D":                 ("Device.kicad_sym", "D"),
    "Transistor_BJT:Q_NPN_EBC": ("Transistor_BJT.kicad_sym", "Q_NPN_EBC"),
    "Relay:SANYOU_SRD_Form_C":  ("Relay.kicad_sym", "SANYOU_SRD_Form_C"),
    "Isolator:PC817":           ("Isolator.kicad_sym", "PC817"),
    "Connector_Generic:Conn_01x12":     ("Connector_Generic.kicad_sym", "Conn_01x12"),
    "Connector_Generic:Conn_01x02":     ("Connector_Generic.kicad_sym", "Conn_01x02"),
    "Connector_Generic:Conn_01x03":     ("Connector_Generic.kicad_sym", "Conn_01x03"),
    "Connector_Generic:Conn_01x04":     ("Connector_Generic.kicad_sym", "Conn_01x04"),
    "Connector:Screw_Terminal_01x02": ("Connector.kicad_sym", "Screw_Terminal_01x02"),
    "Connector:Screw_Terminal_01x03": ("Connector.kicad_sym", "Screw_Terminal_01x03"),
    "Device:Fuse":              ("Device.kicad_sym", "Fuse"),
    "Diode_Bridge:KBU4A":       ("Diode_Bridge.kicad_sym", "KBU4A"),
}

FP = {  # lib_id -> footprint
    "Device:R":                 "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal",
    "Device:C":                 "Capacitor_THT:C_Disc_D5.0mm_W2.5mm_P5.00mm",
    "Device:C_Polarized":       "Capacitor_THT:CP_Radial_D6.3mm_P2.50mm",
    "Device:LED":               "LED_THT:LED_D3.0mm",
    "Device:D":                 "Diode_THT:D_DO-41_SOD81_P10.16mm_Horizontal",
    "Transistor_BJT:Q_NPN_EBC": "Package_TO_SOT_THT:TO-92_Inline",
    "Relay:SANYOU_SRD_Form_C":  "Relay_THT:Relay_SPDT_SANYOU_SRD_Series_Form_C",
    "Isolator:PC817":           "Package_DIP:DIP-4_W7.62mm",
    "Connector_Generic:Conn_01x12":     "Connector_PinSocket_2.54mm:PinSocket_1x12_P2.54mm_Vertical",
    "Connector_Generic:Conn_01x02":     "Connector_PinHeader_2.54mm:PinHeader_1x02_P2.54mm_Vertical",
    "Connector:Screw_Terminal_01x02":        "TerminalBlock_Phoenix:TerminalBlock_Phoenix_MKDS-1,5-2-5.08_1x02_P5.08mm_Horizontal",
    "Connector:Screw_Terminal_01x03":        "TerminalBlock_Phoenix:TerminalBlock_Phoenix_MKDS-1,5-3-5.08_1x03_P5.08mm_Horizontal",
    "Connector_Generic:Conn_01x03":     "Connector_PinHeader_2.54mm:PinHeader_1x03_P2.54mm_Vertical",
    "Connector_Generic:Conn_01x04":     "Connector_PinHeader_2.54mm:PinHeader_1x04_P2.54mm_Vertical",
    "Device:Fuse":              "Fuse:Fuseholder_Clip-5x20mm_Keystone_3512_Inline_P23.62x7.27mm_D1.02x1.57mm_Horizontal",
    "Diode_Bridge:KBU4A":       "Diode_THT:Diode_Bridge_Vishay_KBU",
}
# heavy-duty terminal footprint for the wide-input power terminals
FP_MKDS3 = "TerminalBlock_Phoenix:TerminalBlock_Phoenix_MKDS-3-2-5.08_1x02_P5.08mm_Horizontal"

# ── the design: list of parts ────────────────────────────────────────────────
# each: (ref, lib_id, value, x, y, {pin_number: net or "NC"})
NC = "NC"
PARTS = [
    # TTGO module headers (module plugs in here)
    ("J1", "Connector_Generic:Conn_01x12", "TTGO Left",  40, 70,
     {"1":"GND","2":"GND","3":NC,"4":NC,"5":NC,"6":NC,"7":NC,"8":"EXIT","9":NC,"10":"GND","11":"GND","12":"+3V3"}),
    ("J2", "Connector_Generic:Conn_01x12", "TTGO Right", 40, 135,
     {"1":"+3V3","2":NC,"3":NC,"4":NC,"5":NC,"6":"RLY1","7":"RLY2","8":"DOOR","9":"FIRE_SENSE","10":"TAMPER","11":"GND","12":"+5V"}),

    # Field inputs
    ("J3", "Connector:Screw_Terminal_01x02", "Exit btn",   40, 200, {"1":"EXIT","2":"GND"}),
    ("J4", "Connector:Screw_Terminal_01x02", "Door contact",40, 220, {"1":"DOOR","2":"GND"}),
    ("J5", "Connector:Screw_Terminal_01x02", "Tamper",      40, 240, {"1":"TAMPER","2":"GND"}),

    # Relay channel 1 (lock)  GPIO32
    ("R1", "Device:R", "1k",  95, 70, {"1":"RLY1","2":"RLY1_B"}),
    ("R2", "Device:R", "10k", 115,70, {"1":"RLY1_B","2":"GND"}),
    ("Q1", "Transistor_BJT:Q_NPN_EBC", "PN2222A", 115, 100, {"1":"GND","2":"RLY1_B","3":"K1_C"}),
    ("K1", "Relay:SANYOU_SRD_Form_C", "SRD-05VDC-SL-C", 150, 90,
     {"1":"LK1_COM","2":"K1_C","3":"LK1_NO","4":"LK1_NC","5":"+5V"}),
    ("D1", "Device:D", "1N4007", 130, 130, {"1":"+5V","2":"K1_C"}),
    ("D4", "Device:LED", "GRN", 165, 130, {"1":"D4K","2":"+5V"}),
    ("R7", "Device:R", "1k", 165, 150, {"1":"D4K","2":"K1_C"}),
    ("J6","Connector:Screw_Terminal_01x03", "LOCK COM/NO/NC", 190, 90, {"1":"LK1_COM","2":"LK1_NO","3":"LK1_NC"}),

    # Relay channel 2 (aux)  GPIO33
    ("R3", "Device:R", "1k",  95, 185, {"1":"RLY2","2":"RLY2_B"}),
    ("R4", "Device:R", "10k", 115,185, {"1":"RLY2_B","2":"GND"}),
    ("Q2", "Transistor_BJT:Q_NPN_EBC", "PN2222A", 115, 215, {"1":"GND","2":"RLY2_B","3":"K2_C"}),
    ("K2", "Relay:SANYOU_SRD_Form_C", "SRD-05VDC-SL-C", 150, 205,
     {"1":"LK2_COM","2":"K2_C","3":"LK2_NO","4":"LK2_NC","5":"+5V"}),
    ("D2", "Device:D", "1N4007", 130, 245, {"1":"+5V","2":"K2_C"}),
    ("D5", "Device:LED", "GRN", 165, 245, {"1":"D5K","2":"+5V"}),
    ("R8", "Device:R", "1k", 165, 265, {"1":"D5K","2":"K2_C"}),
    ("J7","Connector:Screw_Terminal_01x03", "AUX COM/NO/NC", 190, 205, {"1":"LK2_COM","2":"LK2_NO","3":"LK2_NC"}),

    # Fire interface (monitored series link)  GPIO26
    ("U1", "Isolator:PC817", "PC817", 250, 90, {"1":"OPTO_A","2":"FIRE_B","3":"GND","4":"FIRE_SENSE"}),
    ("R5", "Device:R", "2k2", 225, 90, {"1":"FIRE_A","2":"OPTO_A"}),
    ("J8","Connector:Screw_Terminal_01x02", "Fire volt-free", 250, 130, {"1":"FIRE_A","2":"FIRE_B"}),
    ("J9","Connector_Generic:Conn_01x02", "Fire link COM-Fire", 225, 130, {"1":"LK1_COM","2":"FIRE_A"}),

    # ── Wide-input power front end: 5-60V AC/DC -> isolated 12V -> 5V ──────────
    # Heavy input terminal + fuse + bridge (AC or either DC polarity) + bulk cap
    ("J10","Connector:Screw_Terminal_01x02", "5-60V AC/DC IN", 300, 60, {"1":"ACL","2":"ACN"}, FP_MKDS3),
    ("F1", "Device:Fuse", "T2A", 320, 60, {"1":"ACL","2":"ACIN1"}),
    ("BR1","Diode_Bridge:KBU4A", "KBU4M (4A)", 345, 70, {"1":"RAWP","2":"ACIN1","3":"ACN","4":"PGND"}),
    ("C4", "Device:C_Polarized", "100uF/100V", 370, 70, {"1":"RAWP","2":"PGND"}),
    # Isolated DC-DC module (pluggable): Vin+/Vin- (primary) -> 12V/GND (secondary, isolated)
    ("U3", "Connector_Generic:Conn_01x04", "ISO DCDC ->12V (e.g. Mornsun URB)", 395, 75,
     {"1":"RAWP","2":"PGND","3":"GND","4":"+12V"}),
    ("C5", "Device:C_Polarized", "100uF/25V", 420, 75, {"1":"+12V","2":"GND"}),
    ("J11","Connector:Screw_Terminal_01x02", "12V OUT (lock/aux)", 420, 55, {"1":"+12V","2":"GND"}, FP_MKDS3),
    # Buck module (pluggable): 12V -> 5V for the TTGO
    ("U4", "Connector_Generic:Conn_01x03", "BUCK 12->5V (e.g. MP1584)", 395, 120,
     {"1":"+12V","2":"GND","3":"+5V"}),

    # 5V/3V3 decoupling + power LED
    ("C1", "Device:C_Polarized", "100uF/16V", 300, 120, {"1":"+5V","2":"GND"}),
    ("C2", "Device:C", "100nF", 320, 120, {"1":"+5V","2":"GND"}),
    ("C3", "Device:C", "100nF", 340, 120, {"1":"+3V3","2":"GND"}),
    ("D3", "Device:LED", "PWR", 300, 155, {"1":"D3K","2":"+5V"}),
    ("R6", "Device:R", "1k", 300, 175, {"1":"D3K","2":"GND"}),

    # Battery passthrough (TTGO batt lead pads -> 18650 holder)
    ("J13","Connector_Generic:Conn_01x02", "TTGO batt pads", 300, 210, {"1":"VBAT","2":"GND_BAT"}),
    ("J14","Connector:Screw_Terminal_01x02", "18650 pack", 300, 235, {"1":"VBAT","2":"GND_BAT"}),
]

# ── build embedded lib_symbols (unique) ──────────────────────────────────────
used = []
seen = set()
for _r, lib, *_ in PARTS:
    if lib not in seen:
        seen.add(lib); used.append(lib)

lib_blocks = []
pin_geom = {}   # lib_id -> {num: (x,y,angle)}
for lib in used:
    f, name = CAT[lib]
    blk = extract_symbol(f, name)
    pin_geom[lib] = {p["number"]: (p["x"], p["y"], p["angle"]) for p in parse_pins(blk)}
    lib_blocks.append(rename_symbol(blk, lib))

# ── emit instances + stubs + labels + no-connects ────────────────────────────
def dir_from_angle(a):
    """outward (away from body) unit vector in SCHEMATIC space (y down)."""
    ar = math.radians(a)
    # pin angle points toward body; outward is opposite; schematic flips y
    ox = -math.cos(ar)
    oy = math.sin(ar)   # (= -(-sin)): -sin(symbol) then y-flip -> +sin
    # normalize tiny fp error
    ox = round(ox, 3); oy = round(oy, 3)
    return ox, oy

def label_angle(ox, oy):
    if abs(ox) > abs(oy):
        return 0 if ox > 0 else 180
    return 90 if oy < 0 else 270

def snap(v):
    return round(round(v / 2.54) * 2.54, 2)

instances, extras, manifest = [], [], []
for entry in PARTS:
    ref, lib, val, X, Y, netmap = entry[:6]
    fpv = entry[6] if len(entry) > 6 else FP[lib]
    X, Y = snap(X), snap(Y)
    sym_uuid = U()
    manifest.append(dict(ref=ref, lib=lib, value=val, footprint=fpv,
                         uuid=sym_uuid, nets=netmap))
    body = []
    body.append(f'  (symbol (lib_id "{lib}") (at {X} {Y} 0) (unit 1)')
    body.append('    (exclude_from_sim no) (in_bom yes) (on_board yes) (dnp no)')
    body.append(f'    (uuid {sym_uuid})')
    body.append(f'    (property "Reference" "{ref}" (at {X} {round(Y-18.0,2)} 0) (effects (font (size 1.27 1.27))))')
    body.append(f'    (property "Value" "{val}" (at {X} {round(Y+18.0,2)} 0) (effects (font (size 1.27 1.27))))')
    body.append(f'    (property "Footprint" "{fpv}" (at {X} {Y} 0) (effects (font (size 1.27 1.27)) hide))')
    body.append(f'    (property "Datasheet" "" (at {X} {Y} 0) (effects (font (size 1.27 1.27)) hide))')
    for num in pin_geom[lib]:
        body.append(f'    (pin "{num}" (uuid {U()}))')
    body.append(f'    (instances (project "ISLKey" (path "/{ROOT}" (reference "{ref}") (unit 1))))')
    body.append('  )')
    instances.append("\n".join(body))

    for num, (px, py, ang) in pin_geom[lib].items():
        net = netmap.get(num, NC)
        ex = round(X + px, 3); ey = round(Y - py, 3)   # pin connection endpoint (y flip)
        if net == NC:
            extras.append(f'  (no_connect (at {ex} {ey}) (uuid {U()}))')
            continue
        ox, oy = dir_from_angle(ang)
        sx = round(ex + STUB * ox, 3); sy = round(ey + STUB * oy, 3)
        extras.append(f'  (wire (pts (xy {ex} {ey}) (xy {sx} {sy})) (stroke (width 0) (type default)) (uuid {U()}))')
        la = label_angle(ox, oy)
        just = "left" if la == 0 else "right" if la == 180 else "left"
        extras.append(
            f'  (global_label "{net}" (shape bidirectional) (at {sx} {sy} {la}) (fields_autoplaced yes)\n'
            f'    (effects (font (size 1.27 1.27)) (justify {just})) (uuid {U()}))')

# ── assemble ─────────────────────────────────────────────────────────────────
sch = []
sch.append('(kicad_sch')
sch.append('  (version 20251024)')
sch.append('  (generator "islkey_gen") (generator_version "10.0")')
sch.append(f'  (uuid {ROOT})')
sch.append('  (paper "A3")')
sch.append('  (title_block (title "ISLKey TTGO Carrier Board") (company "ISL Technologies") (rev "2.0.0")')
sch.append('    (comment 1 "Inputs, dual onboard relays w/ status LEDs, monitored fire link, backup-power passthrough"))')
sch.append('  (lib_symbols')
sch.append("\n".join(lib_blocks))
sch.append('  )')
if not os.environ.get("SKIP_EXTRAS"):
    sch.append("\n".join(extras))
if not os.environ.get("SKIP_INST"):
    sch.append("\n".join(instances))
sch.append('  (sheet_instances (path "/" (page "1")))')
sch.append(')')
text = "\n".join(sch) + "\n"

with open(OUT, "w", encoding="utf-8") as f:
    f.write(text)

import json
MANIFEST = r"C:\src\islkey\kicad\gen\manifest.json"
with open(MANIFEST, "w", encoding="utf-8") as f:
    json.dump(dict(root=ROOT, parts=manifest), f, indent=1)

bal = sum((c == '(') - (c == ')') for c in text)
print(f"WROTE {OUT}")
print(f"parts={len(PARTS)} symbols={len(used)} paren_balance={bal}")
print(f"WROTE {MANIFEST}")
