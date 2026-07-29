"""Generate the ISLKey 1-MINI (V2.0.0) schematic — stripped-down single-relay
door controller for a UK 1-gang back box. Non-isolated 12VAC/DC -> 5V buck,
1 lock relay (dry contacts), 1 exit input. Reuses kicad_lib helpers.
"""
import os, sys, math, json
sys.path.insert(0, os.path.dirname(__file__))
from kicad_lib import extract_symbol, rename_symbol, parse_pins, U

OUTDIR = r"C:\src\islkey\kicad\mini"
os.makedirs(OUTDIR, exist_ok=True)
OUT = os.path.join(OUTDIR, "ISLKey-Mini.kicad_sch")
MANIFEST = os.path.join(OUTDIR, "manifest_mini.json")
ROOT = U()
STUB = 3.81

CAT = {
    "ISLKey:TTGO_ESP32_TDISPLAY_V1.1": ("ISLKey.kicad_sym", "TTGO_ESP32_TDISPLAY_V1.1"),
    "Connector:Screw_Terminal_01x02": ("Connector.kicad_sym", "Screw_Terminal_01x02"),
    "Connector:Screw_Terminal_01x03": ("Connector.kicad_sym", "Screw_Terminal_01x03"),
    "Device:Polyfuse":            ("Device.kicad_sym", "Polyfuse"),
    "Diode_Bridge:ABS2":          ("Diode_Bridge.kicad_sym", "ABS2"),          # base; value ABS10
    "Device:C_Polarized":         ("Device.kicad_sym", "C_Polarized"),
    "Device:C":                   ("Device.kicad_sym", "C"),
    "Regulator_Switching:AP63200WU": ("Regulator_Switching.kicad_sym", "AP63200WU"),  # base; value AP63203WU
    "Device:L":                   ("Device.kicad_sym", "L"),
    "Device:R":                   ("Device.kicad_sym", "R"),
    "Transistor_BJT:Q_NPN_BEC":   ("Transistor_BJT.kicad_sym", "Q_NPN_BEC"),   # base; value MMBT2222A
    "Relay:G6E":                  ("Relay.kicad_sym", "G6E"),
    "Device:D":                   ("Device.kicad_sym", "D"),
    "Device:LED":                 ("Device.kicad_sym", "LED"),
    "power:PWR_FLAG":             ("power.kicad_sym", "PWR_FLAG"),
}
FP = {
    "ISLKey:TTGO_ESP32_TDISPLAY_V1.1": "ISLKey:TTGO_ESP32_TDisplay_v1.1",
    "Connector:Screw_Terminal_01x02": "TerminalBlock_Phoenix:TerminalBlock_Phoenix_PT-1,5-2-3.5-H_1x02_P3.50mm_Horizontal",
    "Connector:Screw_Terminal_01x03": "TerminalBlock_Phoenix:TerminalBlock_Phoenix_PT-1,5-3-3.5-H_1x03_P3.50mm_Horizontal",
    "Device:Polyfuse":            "Fuse:Fuse_1812_4532Metric",
    "Diode_Bridge:ABS2":          "Diode_SMD:Diode_Bridge_Diotec_ABS",
    "Device:C_Polarized":         "Capacitor_SMD:CP_Elec_6.3x5.3",
    "Device:C":                   "Capacitor_SMD:C_0805_2012Metric",
    "Regulator_Switching:AP63200WU": "Package_TO_SOT_SMD:TSOT-23-6",
    "Device:L":                   "Inductor_SMD:L_6.3x6.3_H3",
    "Device:R":                   "Resistor_SMD:R_0805_2012Metric",
    "Transistor_BJT:Q_NPN_BEC":   "Package_TO_SOT_SMD:SOT-23",
    "Relay:G6E":                  "Relay_THT:Relay_SPDT_Omron_G6E",
    "Device:D":                   "Diode_SMD:D_SOD-123",
    "Device:LED":                 "LED_SMD:LED_0805_2012Metric",
    "power:PWR_FLAG":             "",
}
NC = "NC"
# G6E relay: 1&6=coil, 7=COM, 10=NC, 12=NO.  ABS10: 1=+,2=-,3/4=~.
# AP63200WU: 1=FB,2=EN,3=IN,4=GND,5=SW,6=BST.  Q_NPN_BEC: 1=B,2=E,3=C.
PARTS = [
    ("M1", "ISLKey:TTGO_ESP32_TDISPLAY_V1.1", "TTGO T-Display", 40, 60,
     {"7":"RLY", "20":"EXIT", "1":"+5V", "12":"+3V3", "24":"+3V3",
      "2":"GND", "13":"GND", "14":"GND", "22":"GND", "23":"GND"}),

    # Power: 12VAC/DC -> bridge -> 5V buck (non-isolated)
    ("J1", "Connector:Screw_Terminal_01x02", "12V AC/DC IN", 120, 40, {"1":"ACL","2":"ACN"}),
    ("F1", "Device:Polyfuse", "500mA PTC", 140, 40, {"1":"ACL","2":"ACLF"}),
    ("BR1","Diode_Bridge:ABS2", "ABS10", 160, 45, {"1":"RAWP","2":"GND","3":"ACLF","4":"ACN"}),
    ("C4", "Device:C_Polarized", "22uF/25V", 180, 45, {"1":"RAWP","2":"GND"}),
    ("C5", "Device:C", "100nF", 195, 45, {"1":"RAWP","2":"GND"}),
    ("U2", "Regulator_Switching:AP63200WU", "AP63203WU", 220, 45,
     {"3":"RAWP","2":"RAWP","4":"GND","5":"SW","6":"BST","1":"FB"}),
    ("L1", "Device:L", "4.7uH", 245, 40, {"1":"SW","2":"+5V"}),
    ("C6", "Device:C", "100nF", 235, 30, {"1":"BST","2":"SW"}),
    ("C7", "Device:C_Polarized", "22uF/16V", 260, 45, {"1":"+5V","2":"GND"}),
    ("R5", "Device:R", "53k6", 245, 60, {"1":"+5V","2":"FB"}),
    ("R6", "Device:R", "10k", 245, 72, {"1":"FB","2":"GND"}),

    # Relay (lock)
    ("R1", "Device:R", "1k",  95, 130, {"1":"RLY","2":"RLY_B"}),
    ("R2", "Device:R", "10k", 115,130, {"1":"RLY_B","2":"GND"}),
    ("Q1", "Transistor_BJT:Q_NPN_BEC", "MMBT2222A", 115, 160, {"1":"RLY_B","2":"GND","3":"K_C"}),
    ("K1", "Relay:G6E", "G6E (2A)", 150, 150,
     {"1":"+5V","6":"K_C","7":"LK_COM","10":"LK_NC","12":"LK_NO"}),
    ("D1", "Device:D", "1N4148", 130, 190, {"1":"+5V","2":"K_C"}),   # flyback
    ("D4", "Device:LED", "GRN", 170, 185, {"1":"D4K","2":"+5V"}),
    ("R7", "Device:R", "1k", 170, 200, {"1":"D4K","2":"K_C"}),
    ("J2", "Connector:Screw_Terminal_01x03", "LOCK COM/NO/NC", 200, 150, {"1":"LK_COM","2":"LK_NO","3":"LK_NC"}),

    # Exit input
    ("J3", "Connector:Screw_Terminal_01x02", "EXIT", 40, 130, {"1":"EXIT","2":"GND"}),

    # Power LED + decoupling
    ("D3", "Device:LED", "PWR", 280, 45, {"1":"D3K","2":"+5V"}),
    ("R4", "Device:R", "1k", 280, 60, {"1":"D3K","2":"GND"}),
    ("C1", "Device:C", "100nF", 60, 90, {"1":"+5V","2":"GND"}),
    ("C2", "Device:C", "100nF", 75, 90, {"1":"+3V3","2":"GND"}),

    # PWR_FLAGs (bridge/buck rails are 'passive' to ERC)
    ("#FLG1", "power:PWR_FLAG", "PWR_FLAG", 170, 30, {"1":"RAWP"}),
    ("#FLG2", "power:PWR_FLAG", "PWR_FLAG", 175, 75, {"1":"GND"}),
    ("#FLG3", "power:PWR_FLAG", "PWR_FLAG", 265, 35, {"1":"+5V"}),
]

# ── build embedded lib_symbols (unique) ──────────────────────────────────────
used, seen = [], set()
for p in PARTS:
    lib = p[1]
    if lib not in seen:
        seen.add(lib); used.append(lib)
lib_blocks, pin_geom = [], {}
for lib in used:
    f, name = CAT[lib]
    blk = extract_symbol(f, name)
    pin_geom[lib] = {pp["number"]: (pp["x"], pp["y"], pp["angle"]) for pp in parse_pins(blk)}
    lib_blocks.append(rename_symbol(blk, lib))

def dir_from_angle(a):
    ar = math.radians(a)
    return round(-math.cos(ar), 3), round(math.sin(ar), 3)
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
    uid = U()
    manifest.append(dict(ref=ref, lib=lib, value=val, footprint=fpv, uuid=uid, nets=netmap))
    onb = "no" if fpv == "" else "yes"
    b = []
    b.append(f'  (symbol (lib_id "{lib}") (at {X} {Y} 0) (unit 1)')
    b.append(f'    (exclude_from_sim no) (in_bom {onb}) (on_board {onb}) (dnp no)')
    b.append(f'    (uuid {uid})')
    b.append(f'    (property "Reference" "{ref}" (at {X} {round(Y-18,2)} 0) (effects (font (size 1.27 1.27))))')
    b.append(f'    (property "Value" "{val}" (at {X} {round(Y+18,2)} 0) (effects (font (size 1.27 1.27))))')
    b.append(f'    (property "Footprint" "{fpv}" (at {X} {Y} 0) (effects (font (size 1.27 1.27)) hide))')
    b.append(f'    (property "Datasheet" "" (at {X} {Y} 0) (effects (font (size 1.27 1.27)) hide))')
    for num in pin_geom[lib]:
        b.append(f'    (pin "{num}" (uuid {U()}))')
    b.append(f'    (instances (project "ISLKey-Mini" (path "/{ROOT}" (reference "{ref}") (unit 1))))')
    b.append('  )')
    instances.append("\n".join(b))
    for num, (px, py, ang) in pin_geom[lib].items():
        net = netmap.get(num, NC)
        ex = round(X + px, 3); ey = round(Y - py, 3)
        if net == NC:
            extras.append(f'  (no_connect (at {ex} {ey}) (uuid {U()}))'); continue
        ox, oy = dir_from_angle(ang)
        sx = round(ex + STUB*ox, 3); sy = round(ey + STUB*oy, 3)
        extras.append(f'  (wire (pts (xy {ex} {ey}) (xy {sx} {sy})) (stroke (width 0) (type default)) (uuid {U()}))')
        la = label_angle(ox, oy); just = "left" if la == 0 else "right"
        extras.append(f'  (global_label "{net}" (shape bidirectional) (at {sx} {sy} {la}) (fields_autoplaced yes)\n'
                      f'    (effects (font (size 1.27 1.27)) (justify {just})) (uuid {U()}))')

sch = ['(kicad_sch', '  (version 20251024)', '  (generator "islkey_gen") (generator_version "10.0")',
       f'  (uuid {ROOT})', '  (paper "A4")',
       '  (title_block (title "ISLKey 1-MINI") (company "ISL Technologies") (rev "2.0.0")',
       '    (comment 1 "1-MINI: 1-gang controller - 1 relay (lock), 1 input (exit), 12VAC/DC->5V"))',
       '  (lib_symbols', "\n".join(lib_blocks), '  )',
       "\n".join(extras), "\n".join(instances),
       '  (sheet_instances (path "/" (page "1")))', ')']
text = "\n".join(sch) + "\n"
open(OUT, "w", encoding="utf-8").write(text)
json.dump(dict(root=ROOT, parts=manifest), open(MANIFEST, "w", encoding="utf-8"), indent=1)
bal = sum((c == '(') - (c == ')') for c in text)
print(f"WROTE {OUT}  parts={len(PARTS)} symbols={len(used)} paren={bal}")
