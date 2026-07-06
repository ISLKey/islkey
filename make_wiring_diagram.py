"""Generate the ISLKey TTGO T-Display wiring / pinout diagram PDF.

Sheet 1 — board pinout & GPIO assignment
Sheet 2 — system wiring with attached field devices (sensors, relay, lock, power)
Sheet 3 — lock output & MONITORED fire-alarm link (single volt-free N/C contact + opto)
Sheet 4 — full GPIO reference table
"""
import matplotlib
matplotlib.use("Agg")
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon
from matplotlib.backends.backend_pdf import PdfPages

NAVY="#0a0e17"; BLUE="#2563eb"; GREEN="#16a34a"; RED="#dc2626"
AMBER="#d97706"; PURPLE="#7c3aed"; SLATE="#475569"; INK="#111827"; MUTE="#6b7280"
GND="#334155"; TEAL="#0d9488"

def tint(hexc, a=0.12):
    h=hexc.lstrip("#"); r,g,b=int(h[0:2],16),int(h[2:4],16),int(h[4:6],16)
    return (1-(1-r/255)*a, 1-(1-g/255)*a, 1-(1-b/255)*a)

def new_page():
    fig=plt.figure(figsize=(11.69,8.27))
    ax=fig.add_axes([0,0,1,1]); ax.set_xlim(0,100); ax.set_ylim(0,100); ax.axis("off")
    return fig,ax

def header(ax,title,sub):
    ax.add_patch(Rectangle((0,92),100,8,facecolor=NAVY,edgecolor="none"))
    ax.text(3,96.2,"ISLKey",fontsize=17,fontweight="bold",color="#38bdf8",va="center")
    ax.text(16.5,96.2,"TTGO T-Display — Wiring & Pinout",fontsize=12,color="white",va="center")
    ax.text(97,96.2,sub,fontsize=8.5,color="#94a3b8",va="center",ha="right")
    ax.text(50,89.3,title,fontsize=12.5,fontweight="bold",color=INK,ha="center")

def footer(ax):
    ax.add_patch(Rectangle((0,0),100,4,facecolor="#f1f5f9",edgecolor="none"))
    ax.text(3,2,"ISL Technologies — ISLKey Door Controller Firmware",fontsize=7.5,color=MUTE,va="center")
    ax.text(97,2,"GPIO map generated from firmware src/  ·  v1.2.0",fontsize=7.5,color=MUTE,va="center",ha="right")

def comp(ax,x,y,w,h,title,sub,color):
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0.2,rounding_size=1.0",
        linewidth=1.4,edgecolor=color,facecolor=tint(color),zorder=2))
    ax.text(x+w/2,y+h*0.60,title,ha="center",va="center",fontsize=8.3,fontweight="bold",color=INK,zorder=3)
    ax.text(x+w/2,y+h*0.26,sub,ha="center",va="center",fontsize=6.6,color="#374151",zorder=3)

def gpio_tag(ax,x,y,label,color):
    ax.add_patch(Rectangle((x-4.2,y-1.6),8.4,3.2,facecolor=color,edgecolor="none",zorder=5))
    ax.text(x,y,label,ha="center",va="center",fontsize=6.8,color="white",fontweight="bold",zorder=6)

def wire(ax,side,bx,by,bw,bh,chip_x,ty,label,color):
    sy=by+bh/2
    if side=="L":
        x1=bx+bw
        ax.plot([x1,chip_x-8,chip_x-8,chip_x],[sy,sy,ty,ty],color=color,lw=1.5,zorder=1)
        gpio_tag(ax,chip_x-8,ty,label,color)
    else:
        x1=bx
        ax.plot([x1,chip_x+8,chip_x+8,chip_x],[sy,sy,ty,ty],color=color,lw=1.5,zorder=1)
        gpio_tag(ax,chip_x+8,ty,label,color)

def board(ax,cx,y0,y1):
    w=16; x=cx-w/2
    ax.add_patch(FancyBboxPatch((x,y0),w,y1-y0,boxstyle="round,pad=0.2,rounding_size=1.4",
        linewidth=2,edgecolor=INK,facecolor="#1f2937",zorder=4))
    ax.add_patch(Rectangle((x+2.2,y1-12),w-4.4,9,facecolor="#0ea5e9",edgecolor="#9ca3af",lw=0.8,zorder=5))
    ax.text(cx,y1-7.5,"1.14\" TFT",ha="center",va="center",fontsize=6.5,color="white",zorder=6)
    ax.add_patch(Rectangle((x+w/2-2.0,y0+0.2),4.0,2.6,facecolor="#374151",edgecolor="#9ca3af",lw=0.8,zorder=5))
    ax.text(cx,y0+1.5,"USB-C",ha="center",va="center",fontsize=5.0,color="#cbd5e1",zorder=6)
    ax.text(cx,(y0+y1)/2-4,"TTGO",ha="center",va="center",fontsize=12,fontweight="bold",color="white",zorder=6)
    ax.text(cx,(y0+y1)/2-8,"T-Display",ha="center",va="center",fontsize=8,color="#9ca3af",zorder=6)
    ax.add_patch(Rectangle((x-1.4,y1-20),1.4,2.2,facecolor="#9ca3af",edgecolor="none",zorder=5))
    ax.add_patch(Rectangle((x-1.4,y1-25),1.4,2.2,facecolor="#9ca3af",edgecolor="none",zorder=5))

# ── generic wiring primitives ─────────────────────────────────────────────────
def route(ax,pts,color,lw=1.7,z=1):
    ax.plot([p[0] for p in pts],[p[1] for p in pts],color=color,lw=lw,
            zorder=z,solid_capstyle="round",solid_joinstyle="round")

def dot(ax,x,y,color=INK,r=0.55):
    ax.add_patch(Circle((x,y),r,color=color,zorder=8))

def wlabel(ax,x,y,text,color):
    ax.text(x,y,text,fontsize=6.2,color=color,ha="center",va="center",zorder=9,
            bbox=dict(boxstyle="round,pad=0.16",fc="white",ec=color,lw=0.6))

def gnd_sym(ax,x,y,color=GND,label="GND"):
    route(ax,[(x,y),(x,y-1.8)],color,1.4)
    for i,wd in enumerate([2.4,1.5,0.7]):
        ax.plot([x-wd/2,x+wd/2],[y-1.8-i*0.7,y-1.8-i*0.7],color=color,lw=1.4,zorder=6)
    if label: ax.text(x,y-4.8,label,fontsize=5.4,color=color,ha="center",va="top")

def resistor(ax,x1,y,x2,label,color=INK):
    ax.add_patch(Rectangle((x1,y-1.4),x2-x1,2.8,facecolor="white",edgecolor=color,lw=1.3,zorder=5))
    ax.text((x1+x2)/2,y+2.6,label,fontsize=5.6,color=color,ha="center",zorder=6)

def spdt(ax,cx,cy,length=7.0,lift=4.2,color=INK):
    """Relay contact, drawn closed COM->NC, with an open NO stub above."""
    dot(ax,cx,cy,color); dot(ax,cx+length,cy,color); dot(ax,cx+length,cy+lift,color)
    route(ax,[(cx,cy),(cx+length,cy)],color,2.2)          # closed COM-NC
    ax.text(cx+length+0.8,cy-1.6,"NC",fontsize=5.2,color=color)
    ax.text(cx+length+0.8,cy+lift-0.4,"NO",fontsize=5.2,color=MUTE)
    ax.text(cx-0.4,cy-2.2,"COM",fontsize=5.2,color=color,ha="center")

def ncswitch(ax,cx,cy,length=8.0,color=RED):
    """External fire contact, N/C — drawn closed with a hinge to show it can open."""
    dot(ax,cx,cy,color); dot(ax,cx+length,cy,color)
    route(ax,[(cx,cy),(cx+length,cy)],color,2.2)
    # hinge arrow at moving end suggesting it opens upward on alarm
    route(ax,[(cx+length,cy),(cx+length-2.6,cy+2.6)],color,1.1)
    ax.annotate("",xy=(cx+length-2.4,cy+3.4),xytext=(cx+length-1.0,cy+1.6),
        arrowprops=dict(arrowstyle="->",color=color,lw=1.0),zorder=7)

pdf=PdfPages(r"C:\src\ISLKey-Wiring-Diagram.pdf")

# ══ PAGE 1 : TTGO pinout ══════════════════════════════════════════════════════
fig,ax=new_page()
header(ax,"TTGO T-Display — door-controller pinout (GPIO free of the TFT)","Sheet 1 of 4")
cx=50; cy0,cy1=15,82
board(ax,cx,cy0,cy1)
left=[
    ("Top Button","next screen (on-board)","GPIO0", SLATE),
    ("Input 1 — Exit Button","push to GND  (N/O)","GPIO13", BLUE),
    ("Input 2 — Door Contact","door sensor  (N/C)","GPIO25", BLUE),
    ("Input 3 — Fire (monitored)","opto link  (see Sheet 3)","GPIO26", BLUE),
    ("Input 4 — Tamper","tamper switch  (N/C)","GPIO27", BLUE),
]
right=[
    ("Relay 1 — Primary Lock","relay module IN1 · active-HIGH","GPIO32", RED),
    ("Relay 2 — Secondary","disabled by default","GPIO33", RED),
    ("Bottom Button","toggle backlight (on-board)","GPIO35", SLATE),
]
bw,bh=27,7.5
lx=5
lys=np.linspace(cy1-bh-2,cy0+2,len(left)); tys_l=np.linspace(cy1-6,cy0+6,len(left))
for (t,s,g,c),yb,ty in zip(left,lys,tys_l):
    comp(ax,lx,yb,bw,bh,t,s,c); wire(ax,"L",lx,yb,bw,bh,cx-8,ty,g,c)
rx=68
rys=np.linspace(cy1-bh-2,cy0+8,len(right)); tys_r=np.linspace(cy1-8,cy0+12,len(right))
for (t,s,g,c),yb,ty in zip(right,rys,tys_r):
    comp(ax,rx,yb,bw,bh,t,s,c); wire(ax,"R",rx,yb,bw,bh,cx+8,ty,g,c)
ax.text(cx,cy0-2.4,"PWR: 5 V (USB-C / 5V pin) + GND",ha="center",va="center",fontsize=7.5,color=INK,fontweight="bold")
ax.add_patch(FancyBboxPatch((5,5.0),90,6.6,boxstyle="round,pad=0.2,rounding_size=0.8",
    linewidth=1,edgecolor="#cbd5e1",facecolor="#f8fafc"))
ax.text(6.5,9.7,"Notes",fontsize=8,fontweight="bold",color=INK)
ax.text(6.5,7.8,"• Inputs use internal pull-ups. N/C sensors short to GND when secure; N/O (exit) shorts to GND when pressed.  Fire is a MONITORED opto link — Sheet 3.",fontsize=6.7,color="#374151")
ax.text(6.5,6.3,"• On-board TFT uses GPIO 4/5/16/18/19/23 (not on the headers); RGB LED disabled on TTGO.  Spare for expansion: GPIO 2/12/15 and 36-39.",fontsize=6.7,color="#374151")
footer(ax)
fig.savefig(r"C:\src\_wiring_p1.png",dpi=150)
pdf.savefig(fig); plt.close(fig)

# ══ PAGE 2 : SYSTEM WIRING WITH ATTACHED DEVICES ══════════════════════════════
fig,ax=new_page()
header(ax,"System wiring — controller, field devices, relay-driven lock & backup power","Sheet 2 of 4")

bx,by,bw2,bh2=40,42,20,34
ax.add_patch(FancyBboxPatch((bx,by),bw2,bh2,boxstyle="round,pad=0.3,rounding_size=1.4",
    linewidth=2,edgecolor=INK,facecolor="#1f2937",zorder=4))
ax.add_patch(Rectangle((bx+3,by+bh2-8),bw2-6,5.5,facecolor="#0ea5e9",edgecolor="#9ca3af",lw=0.8,zorder=5))
ax.text(bx+bw2/2,by+bh2-5.2,"ISLKey",ha="center",va="center",fontsize=7,color="white",fontweight="bold",zorder=6)
ax.text(bx+bw2/2,by+bh2/2-1,"ISLKey Controller",ha="center",va="center",fontsize=8.5,fontweight="bold",color="white",zorder=6)
ax.text(bx+bw2/2,by+bh2/2-4.5,"ESP32 · TTGO T-Display",ha="center",va="center",fontsize=6.5,color="#9ca3af",zorder=6)
ax.text(bx+bw2/2,by+2.2,"5V IN · GND",ha="center",va="center",fontsize=6.3,color="#cbd5e1",zorder=6)

inputs=[
    ("Exit Button","N/O — push to GND","GPIO13"),
    ("Door Contact (reed)","N/C — closed = secure","GPIO25"),
    ("Fire (monitored link)","opto — Sheet 3","GPIO26"),
    ("Tamper switch","N/C — enclosure","GPIO27"),
]
iy=[70.5,61.0,51.5,42.0]; ix,iw,ih=4,21,7.5
for (t,s,g),y in zip(inputs,iy):
    col = TEAL if "monitored" in t else BLUE
    comp(ax,ix,y,iw,ih,t,s,col)
    my=y+ih/2
    route(ax,[(ix+iw,my),(bx-3,my),(bx,my)],col,1.6)
    gpio_tag(ax,bx-3,my,g,col); dot(ax,ix+iw,my,col)
ax.text(ix+iw/2,iy[0]+ih+1.6,"SECURITY INPUTS  (2-wire: signal + GND)",ha="center",fontsize=7,fontweight="bold",color=BLUE)

# relay module
rmx,rmy,rmw,rmh=68,52,18,13
ax.add_patch(FancyBboxPatch((rmx,rmy),rmw,rmh,boxstyle="round,pad=0.25,rounding_size=1.0",
    linewidth=1.5,edgecolor=RED,facecolor=tint(RED),zorder=2))
ax.text(rmx+rmw/2,rmy+rmh-2.4,"2-Ch Relay Module",ha="center",fontsize=8,fontweight="bold",color=INK,zorder=3)
ax.text(rmx+rmw/2,rmy+rmh-5.0,"opto-isolated · active-HIGH",ha="center",fontsize=6.2,color="#374151",zorder=3)
ax.text(rmx+1.5,rmy+4.6,"IN1",fontsize=6.4,color=INK,va="center")
ax.text(rmx+1.5,rmy+2.0,"IN2",fontsize=6.4,color=INK,va="center")
ax.text(rmx+rmw-1.5,rmy+3.2,"K1 COM/NC",fontsize=5.8,color=INK,va="center",ha="right")
route(ax,[(bx+bw2,rmy+4.6),(rmx,rmy+4.6)],RED,1.6); gpio_tag(ax,bx+bw2+4,rmy+4.6,"GPIO32",RED)
route(ax,[(bx+bw2,rmy+2.0),(rmx,rmy+2.0)],RED,1.6); gpio_tag(ax,bx+bw2+4,rmy+2.0,"GPIO33",RED)

# lock-output reference block (detail on Sheet 3)
lx0,ly0,lw0,lh0=63,12,34,26
ax.add_patch(FancyBboxPatch((lx0,ly0),lw0,lh0,boxstyle="round,pad=0.3,rounding_size=1.0",
    linewidth=1.4,edgecolor=AMBER,facecolor="#fffdf5",zorder=1))
ax.text(lx0+lw0/2,ly0+lh0-3.0,"LOCK OUTPUT + MONITORED FIRE LINK",ha="center",fontsize=8,fontweight="bold",color=AMBER)
ax.text(lx0+lw0/2,ly0+lh0-6.4,"Relay K1 (COM/NC) switches the 12 V lock PSU.",ha="center",fontsize=6.4,color="#374151")
ax.text(lx0+lw0/2,ly0+lh0-9.0,"A single volt-free fire N/C contact sits in the",ha="center",fontsize=6.4,color="#374151")
ax.text(lx0+lw0/2,ly0+lh0-11.4,"lock series loop and is opto-monitored to GPIO26.",ha="center",fontsize=6.4,color="#374151")
ax.add_patch(FancyBboxPatch((lx0+7,ly0+2.4),lw0-14,4.4,boxstyle="round,pad=0.15,rounding_size=0.6",
    linewidth=1,edgecolor=AMBER,facecolor=tint(AMBER)))
ax.text(lx0+lw0/2,ly0+4.6,"➜  full detail on Sheet 3",ha="center",fontsize=7,fontweight="bold",color=AMBER)
route(ax,[(rmx+rmw-3,rmy),(rmx+rmw-3,ly0+lh0)],RED,1.6); wlabel(ax,rmx+rmw-3,rmy-2.0,"lock + fire",RED)

# power (mains + 18650 backup)
px0,py0,pw0,ph0=4,12,32,22
ax.add_patch(FancyBboxPatch((px0,py0),pw0,ph0,boxstyle="round,pad=0.3,rounding_size=1.0",
    linewidth=1.2,edgecolor=SLATE,facecolor="#f8fafc",zorder=1))
ax.text(px0+pw0/2,py0+ph0-2.2,"POWER — controller only (backup ≈ 7 h+)",ha="center",fontsize=7,fontweight="bold",color=SLATE)
comp(ax,px0+2,py0+12.5,13,6.5,"5 V Mains PSU","USB-C / 5V pin",GREEN)
comp(ax,px0+2,py0+3.8,13,6.5,"2×18650 UPS","boost → 5 V backup",AMBER)
busx=px0+20
route(ax,[(px0+15,py0+15.7),(busx,py0+15.7),(busx,py0+7.0),(px0+15,py0+7.0)],RED,1.6)
route(ax,[(busx,py0+11.3),(busx+3,py0+11.3)],RED,1.6)
dot(ax,busx,py0+15.7,RED); dot(ax,busx,py0+7.0,RED); wlabel(ax,busx+6,py0+11.3,"5 V",RED)
route(ax,[(busx+3,py0+11.3),(bx+4,py0+11.3),(bx+4,by)],RED,1.7); gpio_tag(ax,bx+4,by-2.3,"5V",RED)
route(ax,[(px0+15,py0+2.2),(bx+14,py0+2.2),(bx+14,by)],GND,1.6)
ax.text(px0+16,py0+3.1,"GND (common)",fontsize=6,color=GND); gpio_tag(ax,bx+14,by-2.3,"GND",GND)

ax.add_patch(FancyBboxPatch((4,4.6),93,4.2,boxstyle="round,pad=0.2,rounding_size=0.6",
    linewidth=1,edgecolor="#cbd5e1",facecolor="#f8fafc"))
ax.text(5.5,7.4,"Note:",fontsize=6.6,fontweight="bold",color=INK)
ax.text(9,7.4,"Relay contacts are DRY — they switch the separate 12 V lock PSU, never the ESP32 rail.  The backup UPS powers the CONTROLLER only; the lock PSU is not backed up.",fontsize=6.0,color="#374151")
ax.text(9,5.6,"The fire link both releases the door in hardware AND is monitored by the controller — see Sheet 3 for the CO/NC + opto wiring and the state table.",fontsize=6.0,color="#374151")
footer(ax)
fig.savefig(r"C:\src\_wiring_p2.png",dpi=150)
pdf.savefig(fig); plt.close(fig)

# ══ PAGE 3 : LOCK OUTPUT + MONITORED FIRE LINK ════════════════════════════════
fig,ax=new_page()
header(ax,"Lock output & monitored fire-alarm link — single volt-free N/C contact + opto","Sheet 3 of 4")

yF=74; yR=44           # +12V feed rail, 0V return rail
# 12V lock PSU (vertical)
ax.add_patch(FancyBboxPatch((6,yR),8,yF-yR,boxstyle="round,pad=0.2,rounding_size=0.8",
    linewidth=1.4,edgecolor=GREEN,facecolor=tint(GREEN),zorder=2))
ax.text(10,(yF+yR)/2+2,"12 V",ha="center",fontsize=8,fontweight="bold",color=GREEN,zorder=3)
ax.text(10,(yF+yR)/2-1.4,"Lock",ha="center",fontsize=6.4,color="#374151",zorder=3)
ax.text(10,(yF+yR)/2-3.6,"PSU",ha="center",fontsize=6.4,color="#374151",zorder=3)
ax.text(14.6,yF,"+",fontsize=9,color=GREEN,fontweight="bold",va="center")
ax.text(14.6,yR,"–",fontsize=9,color=INK,fontweight="bold",va="center")
dot(ax,10,yF,GREEN); dot(ax,10,yR,INK)

# top feed rail to lock
route(ax,[(10,yF),(22,yF)],GREEN,1.9); wlabel(ax,16,yF+0.2,"+12 V",GREEN)
# lock (strike / maglock)
ax.add_patch(Rectangle((22,yF-3.5),12,7,facecolor=tint(AMBER),edgecolor=AMBER,lw=1.4,zorder=2))
ax.text(28,yF+0.4,"Electric Strike",ha="center",fontsize=6.6,fontweight="bold",color=INK,zorder=3)
ax.text(28,yF-2.0,"/ Maglock  12 V",ha="center",fontsize=6.0,color="#374151",zorder=3)
route(ax,[(22,yF),(22,yF)],AMBER); # lock left already met by feed
route(ax,[(34,yF),(40,yF)],INK,1.9)   # lock -> relay COM
# flyback diode across lock (below)
dbx=28
route(ax,[(22,yF),(22,yF-8),(dbx+2,yF-8)],PURPLE,1.2)
route(ax,[(34,yF),(34,yF-8),(dbx+2,yF-8)],PURPLE,1.2)
tri=Polygon([(dbx-2,yF-8),(dbx+2,yF-8),(dbx,yF-10)],closed=True,facecolor=PURPLE,edgecolor=PURPLE,zorder=3)
# draw diode symbol horizontally on the lower link instead
ax.add_patch(Polygon([(dbx-1.6,yF-6.6),(dbx-1.6,yF-9.4),(dbx+1.4,yF-8)],closed=True,facecolor=PURPLE,edgecolor=PURPLE,zorder=4))
ax.plot([dbx+1.4,dbx+1.4],[yF-6.6,yF-9.4],color=PURPLE,lw=1.4,zorder=4)
ax.text(dbx+3,yF-8,"1N4007",fontsize=5.4,color=PURPLE,va="center")
ax.text(dbx-3.2,yF-8,"flyback",fontsize=5.2,color=PURPLE,va="center",ha="right")

# relay module contact (COM–NC)
spdt(ax,40,yF,length=7.0,lift=4.6,color=INK)
# relay module box (drive) above, dashed link to the contact
ax.add_patch(FancyBboxPatch((38,yF+7),16,7,boxstyle="round,pad=0.2,rounding_size=0.8",
    linewidth=1.3,edgecolor=RED,facecolor=tint(RED),zorder=2))
ax.text(46,yF+11.6,"2-Ch Relay Module",ha="center",fontsize=6.6,fontweight="bold",color=INK,zorder=3)
ax.text(46,yF+9.0,"IN1 ← GPIO32 (active-HIGH)",ha="center",fontsize=5.8,color="#374151",zorder=3)
ax.plot([46,46],[yF+7,yF+0.8],color=RED,lw=1.0,ls=(0,(2,2)),zorder=0)   # module drives the contact

# NC -> FIRE_A terminal
route(ax,[(47,yF),(58,yF)],INK,1.9)
dot(ax,58,yF,RED); ax.text(58,yF+2.2,"FIRE_A",fontsize=5.8,color=RED,ha="center")
# external fire contact (N/C) FIRE_A -> FIRE_B
ncswitch(ax,58,yF,length=12.0,color=RED)
dot(ax,70,yF,RED); ax.text(70,yF+2.2,"FIRE_B",fontsize=5.8,color=RED,ha="center")
ax.text(64,yF+5.8,"FIRE ALARM — volt-free N/C",ha="center",fontsize=6.2,fontweight="bold",color=RED)
ax.text(64,yF+4.0,"(opens on fire / cut)",ha="center",fontsize=5.6,color=MUTE)
# FIRE_B down to return rail; return rail back to PSU –
route(ax,[(70,yF),(70,yR)],INK,1.9)
route(ax,[(70,yR),(10,yR)],INK,1.9); wlabel(ax,40,yR-0.1,"0 V return",INK)

# ── opto monitor across the fire contact ──────────────────────────────────────
oy=yF-16
# FIRE_A tap down through R1 to the opto LED anode
route(ax,[(58,yF),(58,oy+7)],TEAL,1.5)
ax.add_patch(Rectangle((56.6,oy+4),2.8,3.0,facecolor="white",edgecolor=TEAL,lw=1.3,zorder=6))
ax.text(60.6,oy+5.5,"R1 2k2",fontsize=5.4,color=TEAL,va="center")
route(ax,[(58,oy+4),(58,oy+2)],TEAL,1.5)
# opto package
ax.add_patch(FancyBboxPatch((50,oy-8),20,10,boxstyle="round,pad=0.2,rounding_size=0.8",
    linewidth=1.4,edgecolor=TEAL,facecolor=tint(TEAL),zorder=2))
ax.text(60,oy+0.6,"PC817 opto-isolator",ha="center",fontsize=6.6,fontweight="bold",color=INK,zorder=6)
ax.plot([61,61],[oy-8,oy+2],color=TEAL,lw=0.8,ls=(0,(3,2)),zorder=3)   # isolation barrier
# LED (field side) vertical: anode top, cathode bottom
ax.add_patch(Polygon([(56.6,oy-1.5),(59.4,oy-1.5),(58,oy-4.2)],closed=True,facecolor=TEAL,edgecolor=TEAL,zorder=6))
ax.plot([56.6,59.4],[oy-4.2,oy-4.2],color=TEAL,lw=1.6,zorder=6)
ax.text(55.0,oy-2.6,"LED",fontsize=5.0,color=TEAL,ha="right",va="center")
route(ax,[(58,oy+2),(58,oy-1.5)],TEAL,1.5)             # anode
route(ax,[(58,oy-4.2),(58,yR)],TEAL,1.5)               # cathode -> 0V return (field side)
dot(ax,58,yR,TEAL)
# transistor (controller side, isolated)
ax.add_patch(Circle((64.5,oy-3),2.0,facecolor="white",edgecolor=INK,lw=1.2,zorder=6))
ax.text(64.5,oy-3,"Q",fontsize=5.4,color=INK,ha="center",va="center",zorder=7)
route(ax,[(64.5,oy-1.0),(64.5,oy+2),(80,oy+2)],INK,1.4)   # collector -> GPIO26
gpio_tag(ax,84,oy+2,"GPIO26",TEAL)
route(ax,[(64.5,oy-5.0),(64.5,oy-9),(74,oy-9)],INK,1.4)   # emitter -> CTRL GND (isolated)
gnd_sym(ax,74,oy-9,color=GND,label="CTRL GND")
ax.text(66.6,oy+3.6,"isolated",fontsize=5.4,color=MUTE,ha="center",style="italic")
ax.text(50,38.5,"Opto LED is wired across the fire contact — it lights only when the contact OPENS (~12 V appears), pulling GPIO26 LOW.",ha="center",fontsize=5.9,color=TEAL)

# ── state table ───────────────────────────────────────────────────────────────
tx,ty0,tw=6,10,58; rowh=3.6
ax.text(tx,ty0+ (5)*rowh +1.5,"State table",fontsize=8.5,fontweight="bold",color=INK)
rows=[
    ("Condition","Relay K1","Fire contact","Lock","GPIO26"),
    ("Secure (idle)","COM–NC closed","closed","POWERED / locked","secure"),
    ("Access granted","energised, opens","closed","released (unlock)","secure"),
    ("FIRE","COM–NC closed","OPENS","released (hardware)","ALARM (opto)"),
    ("Cut cable / link out","—","open","released","ALARM (supervised)"),
]
col=[tx+1,tx+16,tx+29,tx+40,tx+52]
for i,r in enumerate(rows):
    y=ty0+(len(rows)-1-i)*rowh
    if i==0:
        ax.add_patch(Rectangle((tx,y-0.9),tw,rowh,facecolor=NAVY,edgecolor="none")); tc="white"; fw="bold"
    else:
        if i%2==1: ax.add_patch(Rectangle((tx,y-0.9),tw,rowh,facecolor="#f1f5f9",edgecolor="none"))
        tc=INK; fw="normal"
    for cxx,val in zip(col,r):
        ax.text(cxx,y+0.5,val,fontsize=5.9,color=tc,fontweight=fw,va="center")

# ── notes ─────────────────────────────────────────────────────────────────────
ax.add_patch(FancyBboxPatch((67,5),30,26,boxstyle="round,pad=0.3,rounding_size=0.8",
    linewidth=1,edgecolor=AMBER,facecolor="#fffdf5"))
ax.text(68.5,29.4,"Fire-link notes",fontsize=7.4,fontweight="bold",color=AMBER)
notes=[
    "• Uses the fire panel's single volt-free",
    "  contact as N/C (opens on fire). This is",
    "  the fail-safe fire-interface convention.",
    "• Contact in series with the lock loop →",
    "  releases the door in HARDWARE, even if",
    "  the TTGO is dead.",
    "• Opto (isolated) tells GPIO26 the link is",
    "  open on fire OR a cut/removed cable →",
    "  cloud alert + supervision.",
    "• Firmware: set Fire input logic = active-",
    "  LOW (opto pulls GPIO26 to GND).",
    "• If the contact is N/O-only (closes on",
    "  fire): add a 12 V trip relay — its N/C",
    "  gives the series break + monitored link.",
]
for i,n in enumerate(notes):
    ax.text(68.5,27.3-i*1.62,n,fontsize=5.5,color="#374151")
footer(ax)
fig.savefig(r"C:\src\_wiring_p3.png",dpi=150)
pdf.savefig(fig); plt.close(fig)

# ══ PAGE 4 : TTGO GPIO reference ══════════════════════════════════════════════
fig,ax=new_page()
header(ax,"TTGO T-Display — full GPIO reference","Sheet 4 of 4")
ax.add_patch(FancyBboxPatch((5,62),43,24,boxstyle="round,pad=0.3,rounding_size=1.0",
    linewidth=1.4,edgecolor=RED,facecolor=tint(RED)))
ax.text(7,83.6,"On-board TFT — NOT on the headers",fontsize=9,fontweight="bold",color=RED)
ax.text(7,81.4,"Drive the 1.14\" ST7789 screen; do not wire to these:",fontsize=6.9,color="#374151")
intern=[("GPIO4","backlight (BL)"),("GPIO5","chip-select (CS)"),("GPIO16","data/command (DC)"),
        ("GPIO18","clock (SCLK)"),("GPIO19","data (MOSI)"),("GPIO23","reset (RST)")]
for i,(g,d) in enumerate(intern):
    yy=78.8-i*2.4
    ax.text(8.5,yy,g,fontsize=7.2,color=RED,fontweight="bold",va="center")
    ax.text(19,yy,d,fontsize=7.2,color="#374151",va="center")
ax.text(7,63.4,"Buttons: GPIO0 (top) · GPIO35 (bottom)",fontsize=6.9,color="#374151")

ax.add_patch(FancyBboxPatch((52,62),43,24,boxstyle="round,pad=0.3,rounding_size=1.0",
    linewidth=1.4,edgecolor=GREEN,facecolor=tint(GREEN)))
ax.text(54,83.6,"Spare & reserved header pins",fontsize=9,fontweight="bold",color=GREEN)
ax.text(54,81.0,"Spare (free for expansion):",fontsize=7.2,color=INK,fontweight="bold")
ax.text(56,79.4,"GPIO2, 12, 15  — usable but boot-strapping (use with care)",fontsize=7.0,color="#374151")
ax.text(56,77.8,"GPIO36, 37, 38, 39  — input-only, ADC1 (OK with Wi-Fi; add 10k pull-up)",fontsize=7.0,color="#374151")
ax.text(54,75.4,"Reserved — do not use:",fontsize=7.2,color=INK,fontweight="bold")
ax.text(56,73.8,"GPIO1, GPIO3  = USB serial (debug / commissioning)",fontsize=7.0,color="#374151")
ax.text(56,72.2,"RGB LED disabled on TTGO (pins reused for inputs)",fontsize=7.0,color="#374151")
ax.text(54,69.6,"Power: 3V3, GND, 5V (USB-C / VBAT)",fontsize=7.0,color="#374151")
ax.text(54,66.4,"Note: GPIO26 = ADC2 — usable as a digital fire input, but",fontsize=6.5,color=MUTE)
ax.text(54,65.0,"NOT for analog EOL supervision while Wi-Fi is on (use ADC1 36-39).",fontsize=6.5,color=MUTE)

ax.text(5,57.4,"ISLKey function map (TTGO T-Display)",fontsize=9.5,fontweight="bold",color=INK)
rows=[
    ("GPIO","Function","Wiring"),
    ("0",  "Top button + BOOT",          "on-board · hold 5 s = factory reset"),
    ("13", "Input 1 — Exit Button",      "N/O — push to GND"),
    ("25", "Input 2 — Door Contact",     "N/C — door sensor to GND"),
    ("26", "Input 3 — Fire (monitored)", "opto collector · active-LOW · Sheet 3"),
    ("27", "Input 4 — Tamper",           "N/C — tamper switch to GND"),
    ("32", "Relay 1 — Primary Lock",     "relay module IN1 · 5 s pulse · active-HIGH"),
    ("33", "Relay 2 — Secondary",        "relay module IN2 · disabled by default"),
    ("35", "Bottom button",              "on-board · toggle backlight"),
    ("4 / 5 / 16 / 18 / 19 / 23", "On-board TFT (BL/CS/DC/SCLK/MOSI/RST)", "do not wire"),
    ("2 / 12 / 15",  "Spare (boot-strap)",  "usable with care"),
    ("36 / 37 / 38 / 39", "Spare (input-only, ADC1)", "10k pull-up · OK for analog while Wi-Fi on"),
    ("1 / 3",  "USB serial (UART0)",     "leave for debug / commissioning"),
]
tx,tw=5,90; top=53; rowh=3.7; colr=[tx+2,tx+24,tx+56]
for i,(a,b,c) in enumerate(rows):
    y=top-i*rowh
    if i==0:
        ax.add_patch(Rectangle((tx,y-rowh*0.25),tw,rowh,facecolor=NAVY,edgecolor="none")); tc="white"; fs=8
    else:
        if i%2==0: ax.add_patch(Rectangle((tx,y-rowh*0.25),tw,rowh,facecolor="#f1f5f9",edgecolor="none"))
        tc=INK; fs=7.5
    ax.text(colr[0],y+rowh*0.20,a,fontsize=fs,color=tc,fontweight="bold",va="center")
    ax.text(colr[1],y+rowh*0.20,b,fontsize=fs,color=tc,fontweight="bold" if i==0 else "normal",va="center")
    ax.text(colr[2],y+rowh*0.20,c,fontsize=fs,color=tc,fontweight="bold" if i==0 else "normal",va="center")
ax.text(5,5.4,"Relay-board / DevKit / WT32 variants instead use: Inputs GPIO4/5/18/19 · Relays GPIO16/17 · onboard LED GPIO23 · RGB LED GPIO25/26/27.",
        fontsize=6.8,color=MUTE)
footer(ax)
fig.savefig(r"C:\src\_wiring_p4.png",dpi=150)
pdf.savefig(fig); plt.close(fig)

pdf.close()
print("WROTE C:\\src\\ISLKey-Wiring-Diagram.pdf")
