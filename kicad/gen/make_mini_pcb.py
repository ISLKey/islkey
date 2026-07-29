"""Build ISLKey-Mini.kicad_pcb (60x60mm, UK 1-gang) from manifest_mini.json.
Layout: TTGO at the bottom, relay top-left, terminals top-right, power across
the middle. Outline = 60x60 with semicircular screw notches on the L/R edges
at mid-height (for the back-box fixing screws ~62mm centres). Run with KiCad python.
"""
import json, os
import pcbnew

HERE = os.path.dirname(__file__)
MANIFEST = os.path.join(HERE, "..", "mini", "manifest_mini.json")
OUT = r"C:\src\islkey\kicad\mini\ISLKey-Mini.kicad_pcb"
FPBASE = r"C:\Program Files\KiCad\10.0\share\kicad\footprints"
LOCAL_FP = r"C:\src\islkey\kicad\lib"

def mm(v): return pcbnew.FromMM(v)
def TM(v): return pcbnew.ToMM(v)

def load_fp(fpid):
    lib, name = fpid.split(":", 1)
    base = os.path.join(LOCAL_FP, "ISLKey.pretty") if lib == "ISLKey" else os.path.join(FPBASE, lib + ".pretty")
    return pcbnew.FootprintLoad(base, name)

data = json.load(open(MANIFEST, encoding="utf-8"))
root = data["root"]
board = pcbnew.BOARD()
nets = {}
def get_net(n):
    if n not in nets:
        ni = pcbnew.NETINFO_ITEM(board, n); board.Add(ni); nets[n] = ni
    return nets[n]

fp_by_ref = {}
for p in data["parts"]:
    if not p["footprint"]:
        continue
    fp = load_fp(p["footprint"])
    if fp is None:
        print("FAILED", p["footprint"]); continue
    board.Add(fp)
    fp.SetReference(p["ref"]); fp.SetValue(p["value"]); fp.Value().SetVisible(False)
    try:
        kp = pcbnew.KIID_PATH(); kp.push_back(pcbnew.KIID(root)); kp.push_back(pcbnew.KIID(p["uuid"])); fp.SetPath(kp)
    except Exception:
        pass
    for pad in fp.Pads():
        net = p["nets"].get(pad.GetPadName())
        if net and net != "NC":
            pad.SetNet(get_net(net))
    fp_by_ref[p["ref"]] = fp

# ── placement: ref -> (bbox-topleft x, y, rotation). Board 0..60 in x and y. ──
PLACE = {
    # relay + driver, top-left
    "K1": (2, 1, 0),
    "Q1": (14, 2, 0), "R1": (14, 7, 0), "R2": (14, 10, 0),
    "D1": (2, 19.5, 0), "D4": (8, 19.5, 0), "R7": (8, 23, 0),
    # terminals, top row on the right (wire entry from the top edge)
    "J2": (28.5, 1, 0), "J1": (41.5, 1, 0), "J3": (50.5, 1, 0),
    # power section spread across the middle band (below the terminal row)
    "BR1": (17, 12, 0), "F1": (17, 19, 0),
    "C4": (25.5, 12, 0), "C5": (25.5, 20, 0),
    "U2": (37, 12, 0), "L1": (37, 17, 0), "C6": (37, 24, 0),
    "C7": (46, 12, 0), "R5": (46, 20, 0), "R6": (46, 24, 0),
    "D3": (18, 24, 0), "R4": (18, 27, 0),
    "C1": (54, 20, 0), "C2": (54, 24, 0),
    # TTGO across the bottom
    "M1": (4, 33, 0),
}
maxx = maxy = 0.0; minx = miny = 1e9
def track(bb):
    global maxx, maxy, minx, miny
    maxx = max(maxx, TM(bb.GetRight())); maxy = max(maxy, TM(bb.GetBottom()))
    minx = min(minx, TM(bb.GetLeft())); miny = min(miny, TM(bb.GetTop()))
for ref, (x, y, rot) in PLACE.items():
    fp = fp_by_ref.get(ref)
    if fp is None:
        continue
    try: fp.SetOrientationDegrees(rot)
    except Exception: fp.SetOrientation(pcbnew.EDA_ANGLE(rot, pcbnew.DEGREES_T))
    fp.SetPosition(pcbnew.VECTOR2I(0, 0))
    bb = fp.GetBoundingBox(False, False)
    fp.SetPosition(pcbnew.VECTOR2I(mm(x - TM(bb.GetX())), mm(y - TM(bb.GetY()))))
    track(fp.GetBoundingBox(False, False))

# ── 60x60 outline with semicircular screw notches on L/R edges at y=30 ────────
W = 60.0; NY = 30.0; NR = 3.0   # notch centre-y, radius
def seg(xa, ya, xb, yb):
    s = pcbnew.PCB_SHAPE(board); s.SetShape(pcbnew.SHAPE_T_SEGMENT)
    s.SetStart(pcbnew.VECTOR2I(mm(xa), mm(ya))); s.SetEnd(pcbnew.VECTOR2I(mm(xb), mm(yb)))
    s.SetLayer(pcbnew.Edge_Cuts); s.SetWidth(mm(0.15)); board.Add(s)
def arc(sx, sy, mx, my, ex, ey):
    a = pcbnew.PCB_SHAPE(board); a.SetShape(pcbnew.SHAPE_T_ARC)
    a.SetArcGeometry(pcbnew.VECTOR2I(mm(sx), mm(sy)), pcbnew.VECTOR2I(mm(mx), mm(my)), pcbnew.VECTOR2I(mm(ex), mm(ey)))
    a.SetLayer(pcbnew.Edge_Cuts); a.SetWidth(mm(0.15)); board.Add(a)
seg(0, 0, W, 0)                        # top
seg(W, 0, W, NY - NR)                  # right upper
arc(W, NY - NR, W - NR, NY, W, NY + NR)  # right notch (bulge inward)
seg(W, NY + NR, W, W)                  # right lower
seg(W, W, 0, W)                        # bottom
seg(0, W, 0, NY + NR)                  # left lower
arc(0, NY + NR, NR, NY, 0, NY - NR)    # left notch
seg(0, NY - NR, 0, 0)                  # left upper

# ── 8mm hole, horizontally centred, just above the TTGO ──────────────────────
HOLE_X, HOLE_Y, HOLE_D = 30.0, 28.0, 8.0
hc = pcbnew.PCB_SHAPE(board); hc.SetShape(pcbnew.SHAPE_T_CIRCLE)
hc.SetCenter(pcbnew.VECTOR2I(mm(HOLE_X), mm(HOLE_Y)))
hc.SetEnd(pcbnew.VECTOR2I(mm(HOLE_X + HOLE_D / 2), mm(HOLE_Y)))
hc.SetLayer(pcbnew.Edge_Cuts); hc.SetWidth(mm(0.15)); board.Add(hc)

# ── GND pour on both layers ──────────────────────────────────────────────────
gnd = board.FindNet("GND")
ins = 0.6
rect = [(ins, ins), (W - ins, ins), (W - ins, W - ins), (ins, W - ins)]
for layer in (pcbnew.F_Cu, pcbnew.B_Cu):
    z = pcbnew.ZONE(board); z.SetLayer(layer); z.SetNetCode(gnd.GetNetCode())
    z.SetPadConnection(pcbnew.ZONE_CONNECTION_FULL)
    o = z.Outline(); o.NewOutline()
    for px, py in rect: o.Append(mm(px), mm(py))
    board.Add(z)

pcbnew.SaveBoard(OUT, board)
print("WROTE", OUT, "| footprints=%d nets=%d" % (len(fp_by_ref), len(nets)))
