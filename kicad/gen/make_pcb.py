"""Build ISLKey.kicad_pcb from manifest.json using pcbnew (run with KiCad's python).

Loads every footprint, assigns all nets from the schematic manifest, links each
footprint to its schematic symbol (via UUID path), shelf-packs them without
overlap, and adds a board outline + 4 M3 mounting holes. The result opens in
KiCad with a full ratsnest, ready to arrange and route.
"""
import json, os, sys
import pcbnew

HERE = os.path.dirname(__file__)
MANIFEST = os.path.join(HERE, "manifest.json")
OUT = r"C:\src\islkey\kicad\ISLKey.kicad_pcb"
FPBASE = r"C:\Program Files\KiCad\10.0\share\kicad\footprints"
MH_FP = ("MountingHole", "MountingHole_3.2mm_M3")  # lib, name

def mm(v):
    return pcbnew.FromMM(v)

LOCAL_FP = r"C:\src\islkey\kicad\lib"   # project-local .pretty (ISLKey)
def load_fp(fpid):
    lib, name = fpid.split(":", 1)
    if lib == "ISLKey":
        return pcbnew.FootprintLoad(os.path.join(LOCAL_FP, "ISLKey.pretty"), name)
    return pcbnew.FootprintLoad(os.path.join(FPBASE, lib + ".pretty"), name)

data = json.load(open(MANIFEST, encoding="utf-8"))
root = data["root"]
board = pcbnew.BOARD()

# net registry
nets = {}
def get_net(name):
    if name not in nets:
        ni = pcbnew.NETINFO_ITEM(board, name)
        board.Add(ni)
        nets[name] = ni
    return nets[name]

placed = []
for p in data["parts"]:
    if not p["footprint"]:
        continue   # schematic-only symbols (PWR_FLAG) have no footprint
    fp = load_fp(p["footprint"])
    if fp is None:
        print("FAILED to load", p["footprint"]); continue
    board.Add(fp)
    fp.SetReference(p["ref"])
    fp.SetValue(p["value"])
    # link to schematic symbol
    try:
        kp = pcbnew.KIID_PATH()
        kp.push_back(pcbnew.KIID(root))
        kp.push_back(pcbnew.KIID(p["uuid"]))
        fp.SetPath(kp)
    except Exception as e:
        pass
    # assign nets to pads by pad number
    for pad in fp.Pads():
        num = pad.GetNumber()
        net = p["nets"].get(num)
        if net and net != "NC":
            pad.SetNet(get_net(net))
    placed.append((fp, p["ref"]))

# ── routing-aware floorplan: ref -> (x_mm, y_mm, rotation_deg) ────────────────
# Flow: field terminals on edges; TTGO centre; each relay driver->coil->contacts
# ->terminal in a line; power chain L->R with the isolation barrier (U3) splitting
# primary (RAWP/PGND, left) from secondary (12V/5V, right). TTGO_ROW = the two
# 1x12 header rows' centre-to-centre spacing -- VERIFY against the physical module.
PLACE = {
    # field inputs, left edge
    "J3": (14, 24, 180), "J4": (14, 42, 180), "J5": (14, 60, 180),
    # TTGO T-Display module (single footprint), clear of the relay column
    "M1": (34, 30, 0),
    # 5V/3V3 decoupling + power LED, below the module
    "C1": (40, 70, 0), "C2": (48, 70, 0), "C3": (56, 70, 0),
    "D3": (66, 70, 0), "R6": (74, 70, 0),
    # battery passthrough, left edge lower
    "J13": (14, 84, 180), "J14": (14, 102, 180),
    # relay ch1 (lock): RLY1 -> R1 -> Q1 -> K1 coil ; K1 contacts -> J6
    "R1": (96, 18, 0), "R2": (96, 30, 0), "Q1": (105, 25, 0),
    "D4": (114, 15, 0), "R7": (114, 27, 0), "K1": (132, 24, 0),
    "D1": (108, 40, 0), "J6": (162, 24, 0),
    # relay ch2 (aux)
    "R3": (96, 56, 0), "R4": (96, 68, 0), "Q2": (105, 63, 0),
    "D5": (114, 53, 0), "R8": (114, 65, 0), "K2": (132, 62, 0),
    "D2": (108, 78, 0), "J7": (162, 62, 0),
    # fire monitor: GPIO26 <- U1 <- fire terminal ; COM<->fire jumper J9
    "R5": (92, 88, 0), "U1": (104, 88, 0), "J9": (128, 88, 0), "J8": (162, 88, 0),
}
# power chain, placed left->right auto-spaced by real footprint width (F1/BR1/U3
# are wide): IN -> F1 -> BR1 -> C4 -> [U3 isolation barrier] -> C5 -> U4 -> 12V out
POWER_ROW = ["J10", "F1", "BR1", "C4", "U3", "C5", "U4", "J11"]
ROW_Y, ROW_X0, ROW_GAP = 125.0, 10.0, 4.0

fp_by_ref = {ref: fp for fp, ref in placed}
MARGIN = 8.0
maxx = maxy = 0.0
minx = miny = 1e9
def track(bb):
    global maxx, maxy, minx, miny
    maxx = max(maxx, pcbnew.ToMM(bb.GetRight())); maxy = max(maxy, pcbnew.ToMM(bb.GetBottom()))
    minx = min(minx, pcbnew.ToMM(bb.GetLeft())); miny = min(miny, pcbnew.ToMM(bb.GetTop()))

# fixed placements
for fp, ref in placed:
    if ref not in PLACE:
        continue
    x, y, rot = PLACE[ref]
    fp.SetPosition(pcbnew.VECTOR2I(mm(x), mm(y)))
    try:
        fp.SetOrientationDegrees(rot)
    except Exception:
        fp.SetOrientation(pcbnew.EDA_ANGLE(rot, pcbnew.DEGREES_T))
    track(fp.GetBoundingBox())

# power row: walk left->right placing each bbox-left at the cursor
cx = ROW_X0
for ref in POWER_ROW:
    fp = fp_by_ref[ref]
    fp.SetPosition(pcbnew.VECTOR2I(0, 0))
    bb = fp.GetBoundingBox()
    w = pcbnew.ToMM(bb.GetWidth()); h = pcbnew.ToMM(bb.GetHeight())
    ox = pcbnew.ToMM(bb.GetX()); oy = pcbnew.ToMM(bb.GetY())
    fp.SetPosition(pcbnew.VECTOR2I(mm(cx - ox), mm(ROW_Y - h / 2 - oy)))
    track(fp.GetBoundingBox())
    cx += w + ROW_GAP

# shelf-pack fallback for anything not explicitly placed
cx2, cy2, rowh = MARGIN, 150.0, 0.0
for fp, ref in placed:
    if ref in PLACE or ref in POWER_ROW:
        continue
    fp.SetPosition(pcbnew.VECTOR2I(0, 0))
    bb = fp.GetBoundingBox()
    w = pcbnew.ToMM(bb.GetWidth()); h = pcbnew.ToMM(bb.GetHeight())
    ox = pcbnew.ToMM(bb.GetX()); oy = pcbnew.ToMM(bb.GetY())
    if cx2 + w > 170.0:
        cx2 = MARGIN; cy2 += rowh + 2.5; rowh = 0.0
    fp.SetPosition(pcbnew.VECTOR2I(mm(cx2 - ox), mm(cy2 - oy)))
    cx2 += w + 2.5; rowh = max(rowh, h)
    track(fp.GetBoundingBox())

# ── board outline (Edge.Cuts rectangle) ──────────────────────────────────────
x0, y0 = minx - MARGIN, miny - MARGIN
x1, y1 = maxx + MARGIN, maxy + MARGIN
def edge(xa, ya, xb, yb):
    s = pcbnew.PCB_SHAPE(board)
    s.SetShape(pcbnew.SHAPE_T_SEGMENT)
    s.SetStart(pcbnew.VECTOR2I(mm(xa), mm(ya)))
    s.SetEnd(pcbnew.VECTOR2I(mm(xb), mm(yb)))
    s.SetLayer(pcbnew.Edge_Cuts)
    s.SetWidth(mm(0.15))
    board.Add(s)
for a in [(x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)]:
    edge(*a)

# ── 4 M3 mounting holes just inside the corners ──────────────────────────────
corners = [(x0 + 4, y0 + 4), (x1 - 4, y0 + 4), (x1 - 4, y1 - 4), (x0 + 4, y1 - 4)]
for i, (hx, hy) in enumerate(corners, 1):
    mh = pcbnew.FootprintLoad(os.path.join(FPBASE, MH_FP[0] + ".pretty"), MH_FP[1])
    if mh:
        board.Add(mh)
        mh.SetPosition(pcbnew.VECTOR2I(mm(hx), mm(hy)))
        mh.SetReference(f"H{i}")
        mh.Reference().SetVisible(False)
        mh.Value().SetVisible(False)

pcbnew.SaveBoard(OUT, board)
print("WROTE", OUT)
print("footprints=%d nets=%d board=%.1f x %.1f mm" %
      (len(placed), len(nets), x1 - x0, y1 - y0))
