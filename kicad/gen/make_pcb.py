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

def load_fp(fpid):
    lib, name = fpid.split(":", 1)
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

# ── shelf-pack so nothing overlaps ───────────────────────────────────────────
MARGIN = 8.0
GAP = 2.5
MAXW = 170.0
cx, cy, rowh = MARGIN, MARGIN, 0.0
maxx = maxy = 0.0
for fp, ref in placed:
    fp.SetPosition(pcbnew.VECTOR2I(0, 0))
    bb = fp.GetBoundingBox()  # includes silk
    w = pcbnew.ToMM(bb.GetWidth()); h = pcbnew.ToMM(bb.GetHeight())
    ox = pcbnew.ToMM(bb.GetX()); oy = pcbnew.ToMM(bb.GetY())  # bbox min at origin placement
    if cx + w > MAXW:
        cx = MARGIN; cy += rowh + GAP; rowh = 0.0
    # place so bbox min lands at (cx, cy)
    fp.SetPosition(pcbnew.VECTOR2I(mm(cx - ox), mm(cy - oy)))
    cx += w + GAP
    rowh = max(rowh, h)
    maxx = max(maxx, cx); maxy = max(maxy, cy + rowh)

# ── board outline (Edge.Cuts rectangle) ──────────────────────────────────────
x0, y0 = MARGIN - MARGIN, MARGIN - MARGIN
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
