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
    fp.Value().SetVisible(False)   # hide value silk (keeps refs; declutters + shrinks bbox)
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

# ── tight placement: pack parts edge-to-edge in functional order ──────────────
# Row-pack at a fixed width (the 78mm 18650 holders set the floor) with small
# gaps, keeping related parts adjacent. Priority here is a SMALL board; fine-
# tune positions/rotations in the GUI before routing.
ORDER = [
    "J3", "J4", "J5",                                   # field inputs
    "M1",                                               # TTGO module
    "C1", "C2", "C3", "D3", "R6",                       # 5V/3V3 decoupling + LED
    "U5", "C6", "BT3",                                  # RTC + coin cell
    "R1", "R2", "Q1", "D1", "D4", "R7", "K1", "J6",     # relay ch1 (lock)
    "R3", "R4", "Q2", "D2", "D5", "R8", "K2", "J7",     # relay ch2 (aux)
    "R5", "U1", "J9", "J8",                             # fire monitor
    "J10", "F1", "BR1", "C4", "U3", "C5", "U4", "J11",  # power chain
    "BT1", "BT2",                                       # 2x18650 holders
]
fp_by_ref = {ref: fp for fp, ref in placed}
ORDER += [ref for _f, ref in placed if ref not in set(ORDER) and ref != "J13"]

W, GAP, MARGIN = 130.0, 2.0, 6.0
maxx = maxy = 0.0
minx = miny = 1e9
def track(bb):
    global maxx, maxy, minx, miny
    maxx = max(maxx, pcbnew.ToMM(bb.GetRight())); maxy = max(maxy, pcbnew.ToMM(bb.GetBottom()))
    minx = min(minx, pcbnew.ToMM(bb.GetLeft())); miny = min(miny, pcbnew.ToMM(bb.GetTop()))

# measure every part, then First-Fit-Decreasing-Height shelf pack (parts of
# similar height share a row -> minimal wasted vertical space -> compact board)
BATTERIES = ("BT1",)   # single 78mm 18650 holder -> own block, not mixed into the pack
items = []
for ref in ORDER:
    fp = fp_by_ref.get(ref)
    if fp is None or ref in BATTERIES:
        continue
    try:
        fp.SetOrientationDegrees(0)
    except Exception:
        pass
    fp.SetPosition(pcbnew.VECTOR2I(0, 0))
    bb = fp.GetBoundingBox(False, False)
    items.append((fp, pcbnew.ToMM(bb.GetWidth()), pcbnew.ToMM(bb.GetHeight()),
                  pcbnew.ToMM(bb.GetX()), pcbnew.ToMM(bb.GetY())))
items.sort(key=lambda it: -it[2])   # tallest first

cx, cy, rowh = MARGIN, MARGIN, 0.0
for fp, w, h, ox, oy in items:
    if cx > MARGIN and cx + w > W + MARGIN:      # wrap to next shelf
        cx = MARGIN; cy += rowh + GAP; rowh = 0.0
    fp.SetPosition(pcbnew.VECTOR2I(mm(cx - ox), mm(cy - oy)))
    track(fp.GetBoundingBox(False, False))
    cx += w + GAP; rowh = max(rowh, h)

# battery: single 18650 holder (3.7V), horizontal below the circuit
by = cy + rowh + GAP
bx = MARGIN
for ref in BATTERIES:
    fp = fp_by_ref.get(ref)
    if fp is None:
        continue
    fp.SetPosition(pcbnew.VECTOR2I(0, 0))
    bb = fp.GetBoundingBox(False, False)
    w = pcbnew.ToMM(bb.GetWidth()); ox = pcbnew.ToMM(bb.GetX()); oy = pcbnew.ToMM(bb.GetY())
    fp.SetPosition(pcbnew.VECTOR2I(mm(bx - ox), mm(by - oy)))
    track(fp.GetBoundingBox(False, False))
    bx += w + GAP

# battery pads J13: centre them between M1's two header rows (TTGO batt lead)
m1 = fp_by_ref.get("M1"); j13 = fp_by_ref.get("J13")
if m1 and j13:
    xs = [pad.GetPosition().x for pad in m1.Pads()]
    ys = [pad.GetPosition().y for pad in m1.Pads()]
    j13.SetPosition(pcbnew.VECTOR2I(sum(xs) // len(xs), sum(ys) // len(ys)))
    track(j13.GetBoundingBox())

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
corners = [(x0 + 3, y0 + 3), (x1 - 3, y0 + 3), (x1 - 3, y1 - 3), (x0 + 3, y1 - 3)]
for i, (hx, hy) in enumerate(corners, 1):
    mh = pcbnew.FootprintLoad(os.path.join(FPBASE, MH_FP[0] + ".pretty"), MH_FP[1])
    if mh:
        board.Add(mh)
        mh.SetPosition(pcbnew.VECTOR2I(mm(hx), mm(hy)))
        mh.SetReference(f"H{i}")
        mh.Reference().SetVisible(False)
        mh.Value().SetVisible(False)

# ── ground pour on both copper layers (GND) ──────────────────────────────────
gnd = nets.get("GND")
if gnd is not None and not os.environ.get("NO_POUR"):
    inset = 0.5
    rect = [(x0 + inset, y0 + inset), (x1 - inset, y0 + inset),
            (x1 - inset, y1 - inset), (x0 + inset, y1 - inset)]
    for layer in (pcbnew.F_Cu, pcbnew.B_Cu):
        z = pcbnew.ZONE(board)
        z.SetLayer(layer)
        z.SetNetCode(gnd.GetNetCode())
        z.SetAssignedPriority(0)
        z.SetPadConnection(pcbnew.ZONE_CONNECTION_THERMAL)
        outline = z.Outline()
        outline.NewOutline()
        for (px, py) in rect:
            outline.Append(mm(px), mm(py))
        board.Add(z)

pcbnew.SaveBoard(OUT, board)
# Fill zones on a RELOADED board — filling the freshly-built in-memory board
# segfaults (no board setup yet); a loaded board fills cleanly.
if gnd is not None and not os.environ.get("NO_POUR"):
    b2 = pcbnew.LoadBoard(OUT)
    b2.BuildConnectivity()
    pcbnew.ZONE_FILLER(b2).Fill(b2.Zones())
    pcbnew.SaveBoard(OUT, b2)

print("WROTE", OUT)
print("footprints=%d nets=%d board=%.1f x %.1f mm" %
      (len(placed), len(nets), x1 - x0, y1 - y0))
