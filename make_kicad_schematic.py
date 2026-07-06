"""Generate a KiCad 7/8 schematic (.kicad_sch) for the ISLKey TTGO door controller.

Builds simple rectangular symbols (controller, relay module, field-device
connectors, lock, PSUs, diode), places them, and connects everything by NET NAME
using global labels on short wire stubs off each pin — electrically valid in KiCad.
"""
import uuid, json, os

OUT_DIR = r"C:\src\islkey\kicad"
os.makedirs(OUT_DIR, exist_ok=True)
SCH = os.path.join(OUT_DIR, "ISLKey.kicad_sch")
PRO = os.path.join(OUT_DIR, "ISLKey.kicad_pro")

def U():  # deterministic-enough unique ids
    return str(uuid.uuid4())

ROOT_UUID = U()
SP = 5.08          # pin spacing
PINLEN = 5.08      # pin length
STUB = 7.62        # wire stub past the pin
FS = "(effects (font (size 1.27 1.27)))"

# ── symbol library definitions ────────────────────────────────────────────────
lib_defs = {}   # name -> (hw, hh, left_pins, right_pins, etype)

def def_symbol(name, hw, left, right, etype="passive"):
    ny = max(len(left), len(right))
    hh = max((ny - 1) / 2 * SP + 3.81, 7.62)
    lib_defs[name] = (hw, hh, left, right, etype)
    return hw, hh

def pin_ys(k, hh):
    top = (k - 1) / 2 * SP
    return [round(top - i * SP, 3) for i in range(k)]

def render_lib_symbol(name):
    hw, hh, left, right, etype = lib_defs[name]
    s = []
    s.append(f'  (symbol "islkey:{name}"')
    s.append('    (pin_names (offset 1.016)) (in_bom yes) (on_board yes)')
    s.append(f'    (property "Reference" "REF" (at {-hw} {round(hh+2.54,3)} 0) (effects (font (size 1.27 1.27)) (justify left)))')
    s.append(f'    (property "Value" "{name}" (at {-hw} {round(-hh-2.54,3)} 0) (effects (font (size 1.27 1.27)) (justify left)))')
    s.append(f'    (property "Footprint" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    s.append(f'    (property "Datasheet" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    s.append(f'    (symbol "{name}_0_1"')
    s.append(f'      (rectangle (start {-hw} {hh}) (end {hw} {-hh})')
    s.append('        (stroke (width 0.254) (type default)) (fill (type background))))')
    s.append(f'    (symbol "{name}_1_1"')
    num = 1
    for (pname, _net), y in zip(left, pin_ys(len(left), hh)):
        px = round(-(hw + PINLEN), 3)
        s.append(f'      (pin {etype} line (at {px} {y} 0) (length {PINLEN})')
        s.append(f'        (name "{pname}" {FS}) (number "{num}" {FS}))')
        num += 1
    for (pname, _net), y in zip(right, pin_ys(len(right), hh)):
        px = round(hw + PINLEN, 3)
        s.append(f'      (pin {etype} line (at {px} {y} 180) (length {PINLEN})')
        s.append(f'        (name "{pname}" {FS}) (number "{num}" {FS}))')
        num += 1
    s.append('    )')
    s.append('  )')
    return "\n".join(s)

# ── placement / instances ─────────────────────────────────────────────────────
instances = []
extras = []   # wires + global labels

def place(name, ref, value, X, Y):
    hw, hh, left, right, etype = lib_defs[name]
    body = []
    body.append(f'  (symbol (lib_id "islkey:{name}") (at {X} {Y} 0) (unit 1)')
    body.append('    (in_bom yes) (on_board yes) (dnp no)')
    body.append(f'    (uuid {U()})')
    body.append(f'    (property "Reference" "{ref}" (at {round(X-hw,3)} {round(Y-hh-3.81,3)} 0) (effects (font (size 1.27 1.27)) (justify left)))')
    body.append(f'    (property "Value" "{value}" (at {round(X-hw,3)} {round(Y+hh+3.81,3)} 0) (effects (font (size 1.27 1.27)) (justify left)))')
    body.append(f'    (property "Footprint" "" (at {X} {Y} 0) (effects (font (size 1.27 1.27)) hide))')
    body.append(f'    (property "Datasheet" "" (at {X} {Y} 0) (effects (font (size 1.27 1.27)) hide))')
    n = len(left) + len(right)
    for i in range(1, n + 1):
        body.append(f'    (pin "{i}" (uuid {U()}))')
    body.append(f'    (instances (project "ISLKey" (path "/{ROOT_UUID}" (reference "{ref}") (unit 1))))')
    body.append('  )')
    instances.append("\n".join(body))

    # wires + global labels for every pin
    for (pname, net), y in zip(left, pin_ys(len(left), hh)):
        cx = round(X - (hw + PINLEN), 3); cy = round(Y + y, 3)
        lx = round(cx - STUB, 3)
        add_wire(cx, cy, lx, cy)
        add_glabel(net, lx, cy, 180)
    for (pname, net), y in zip(right, pin_ys(len(right), hh)):
        cx = round(X + (hw + PINLEN), 3); cy = round(Y + y, 3)
        lx = round(cx + STUB, 3)
        add_wire(cx, cy, lx, cy)
        add_glabel(net, lx, cy, 0)

def add_wire(x1, y1, x2, y2):
    extras.append(
        f'  (wire (pts (xy {x1} {y1}) (xy {x2} {y2})) '
        f'(stroke (width 0) (type default)) (uuid {U()}))')

def add_glabel(net, x, y, ang):
    just = "left" if ang == 0 else "right"
    extras.append(
        f'  (global_label "{net}" (shape bidirectional) (at {x} {y} {ang}) '
        f'(fields_autoplaced yes)\n'
        f'    (effects (font (size 1.27 1.27)) (justify {just})) (uuid {U()}))')

# ── define the symbols used ───────────────────────────────────────────────────
def_symbol("ESP32_TTGO", 17.78,
           left=[("GPIO13", "EXIT"), ("GPIO25", "DOOR"), ("GPIO26", "FIRE"), ("GPIO27", "TAMPER")],
           right=[("GPIO32", "IN1"), ("GPIO33", "IN2"), ("5V", "+5V"), ("GND", "GND")],
           etype="bidirectional")
def_symbol("Relay_2Ch", 15.24,
           left=[("IN1", "IN1"), ("IN2", "IN2"), ("VCC", "+5V"), ("GND", "GND")],
           right=[("K1_COM", "LOCK_SW"), ("K1_NC", "FIRE_A")])
def_symbol("Conn_Exit",   10.16, left=[], right=[("SIG", "EXIT"),   ("GND", "GND")])
def_symbol("Conn_Door",   10.16, left=[], right=[("SIG", "DOOR"),   ("GND", "GND")])
def_symbol("Conn_Tamper", 10.16, left=[], right=[("SIG", "TAMPER"), ("GND", "GND")])
def_symbol("Lock",     10.16, left=[("+", "+12V"), ("-", "LOCK_SW")], right=[])
def_symbol("Lock_PSU", 10.16, left=[], right=[("+12V", "+12V"), ("0V", "L12_RTN")])
def_symbol("Mains_PSU", 10.16, left=[], right=[("5V", "+5V"), ("GND", "GND")])
def_symbol("UPS_18650", 10.16, left=[], right=[("+5V", "+5V"), ("GND", "GND")])
def_symbol("Diode_1N4007", 7.62, left=[("A", "LOCK_SW")], right=[("K", "+12V")])
# Fire-alarm interface: single volt-free N/C contact in the lock series loop,
# monitored across the contact by an opto-isolator (fire OR cut/removed = open).
def_symbol("Fire_Contact", 10.16, left=[], right=[("FIRE_A", "FIRE_A"), ("FIRE_B", "L12_RTN")])
def_symbol("R_Opto", 5.08, left=[("1", "FIRE_A")], right=[("2", "OPTO_A")])
def_symbol("Opto_PC817", 10.16, left=[("A", "OPTO_A"), ("K", "L12_RTN")],
           right=[("C", "FIRE"), ("E", "GND")])

# ── place the instances (mm on an A3 sheet) ───────────────────────────────────
place("ESP32_TTGO", "U1", "ISLKey Controller (TTGO)", 210, 120)
place("Conn_Exit",   "J1", "Exit Button N/O",   110, 100)
place("Conn_Door",   "J2", "Door Contact N/C",  110, 122)
place("Conn_Tamper", "J4", "Tamper N/C",        110, 144)
place("Relay_2Ch",   "K1", "2-Ch Relay Module", 300, 108)
place("Lock",        "LK1", "Electric Strike / Maglock 12V", 372, 150)
place("Lock_PSU",    "PS2", "12V Lock PSU",      300, 180)
place("Diode_1N4007","D1",  "1N4007 flyback",    300, 148)
place("Fire_Contact","J5",  "Fire volt-free N/C (series, opens on fire)", 372, 108)
place("R_Opto",      "R1",  "2k2 opto LED series", 372, 88)
place("Opto_PC817",  "U2",  "PC817 fire-link monitor -> GPIO26", 300, 78)
place("Mains_PSU",   "PS1", "5V Mains PSU",      110, 210)
place("UPS_18650",   "BT1", "2x18650 UPS 5V",    110, 235)

# ── assemble the file ─────────────────────────────────────────────────────────
lib_syms = "\n".join(render_lib_symbol(n) for n in lib_defs)
sch = []
sch.append('(kicad_sch')
sch.append('  (version 20231120)')
sch.append('  (generator "islkey_gen")')
sch.append(f'  (uuid {ROOT_UUID})')
sch.append('  (paper "A3")')
sch.append('  (title_block')
sch.append('    (title "ISLKey Door Controller — TTGO T-Display")')
sch.append('    (company "ISL Technologies")')
sch.append('    (rev "1.2.0")')
sch.append('    (comment 1 "Access-control controller: inputs, relay-driven lock, backup power")')
sch.append('  )')
sch.append('  (lib_symbols')
sch.append(lib_syms)
sch.append('  )')
sch.append("\n".join(extras))
sch.append("\n".join(instances))
sch.append('  (sheet_instances (path "/" (page "1")))')
sch.append(')')
sch_text = "\n".join(sch) + "\n"

with open(SCH, "w", encoding="utf-8") as f:
    f.write(sch_text)

# minimal project file so it opens as a project
pro = {
    "board": {"design_settings": {}, "layer_presets": [], "viewports": []},
    "boards": [],
    "meta": {"filename": "ISLKey.kicad_pro", "version": 1},
    "net_settings": {"classes": [{"name": "Default", "clearance": 0.2}]},
    "schematic": {"legacy_lib_dir": "", "legacy_lib_list": []},
    "sheets": [[ROOT_UUID, "Root"]],
    "text_variables": {}
}
with open(PRO, "w", encoding="utf-8") as f:
    json.dump(pro, f, indent=2)

# quick paren-balance sanity check
bal = 0
for ch in sch_text:
    if ch == '(': bal += 1
    elif ch == ')': bal -= 1
print(f"WROTE {SCH}")
print(f"WROTE {PRO}")
print(f"paren balance = {bal}  (0 = OK)   symbols={len(lib_defs)}  instances={len(instances)}")
