"""Generate a branded ISLKey icon.ico (multi-size) for the flasher installer."""
from PIL import Image, ImageDraw, ImageFont

SIZE = 256
BG = (10, 14, 23)        # #0a0e17 dark navy
ACCENT = (14, 165, 233)  # #0ea5e9 ISL blue
WHITE = (226, 232, 240)

img = Image.new("RGBA", (SIZE, SIZE), BG + (255,))
d = ImageDraw.Draw(img)

# Rounded-ish border accent
d.rounded_rectangle([8, 8, SIZE - 8, SIZE - 8], radius=36, outline=ACCENT, width=6)

# Try a bold font; fall back to default
def load_font(px):
    for name in ("segoeuib.ttf", "arialbd.ttf", "Arial Bold.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, px)
        except Exception:
            continue
    return ImageFont.load_default()

# "ISL" large
f1 = load_font(96)
t1 = "ISL"
b1 = d.textbbox((0, 0), t1, font=f1)
d.text(((SIZE - (b1[2] - b1[0])) / 2 - b1[0], 52), t1, font=f1, fill=WHITE)

# "KEY" accent
f2 = load_font(54)
t2 = "KEY"
b2 = d.textbbox((0, 0), t2, font=f2)
d.text(((SIZE - (b2[2] - b2[0])) / 2 - b2[0], 150), t2, font=f2, fill=ACCENT)

img.save("icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("icon.ico written")
