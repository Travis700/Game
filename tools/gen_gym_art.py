"""Paints the gym's flat art into assets/textures/gym/: python3 tools/gen_gym_art.py

court.png        the court lines and paint, laid over the wooden floor (1 m of floor round it)
scoreboard.png   the scoreboard face; scoreboard_glow.png is what lights up on it
banner_*.png     the hanging banners (cut to a pennant point at the bottom)
basketball.png   a ball's skin (equirectangular, for a sphere)
net.png          one strip of hoop net, tiled round a cone
"""
import math, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'textures', 'gym')
FONT = os.path.join(HERE, '..', 'assets', 'fonts', 'BebasNeue.ttf')
os.makedirs(OUT, exist_ok=True)

WHITE = (240, 238, 228)
RED = (128, 22, 26)
NAVY = (22, 34, 66)
GOLD = (214, 168, 52)


def font(size):
    return ImageFont.truetype(FONT, size)


def centred_text(draw, xy, text, size, fill, angle=0, img=None):
    """Text centred on xy; when angle is set it's drawn on its own layer and rotated."""
    f = font(size)
    box = draw.textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    if angle == 0:
        draw.text((xy[0] - w / 2 - box[0], xy[1] - h / 2 - box[1]), text, font=f, fill=fill)
        return
    layer = Image.new('RGBA', (w + 20, h + 20), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((10 - box[0], 10 - box[1]), text, font=f, fill=fill)
    layer = layer.rotate(angle, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(layer, (int(xy[0] - layer.width / 2), int(xy[1] - layer.height / 2)))


# --- The court -------------------------------------------------------------------------------
# A high school court, 25.6 x 15.2 m, with its length along the image's width.
PX = 64                    # pixels per metre
MARGIN = 1.0               # metres of floor round the court that the image also covers
LENGTH, WIDTH = 25.6, 15.2
W, H = int((LENGTH + 2 * MARGIN) * PX), int((WIDTH + 2 * MARGIN) * PX)
LINE = 0.05                # line width, metres


def court():
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    px = lambda m: m * PX
    left, top = px(MARGIN), px(MARGIN)
    right, bottom = px(MARGIN + LENGTH), px(MARGIN + WIDTH)
    mid_x, mid_y = (left + right) / 2, (top + bottom) / 2
    lw = max(2, round(px(LINE)))
    paint = RED + (215,)
    for end in (-1, 1):
        base = left if end < 0 else right
        inward = -end
        # The lane, painted, out to the free-throw line (5.79 m), 3.66 m wide.
        lane_far = base + inward * px(5.79)
        lane = [min(base, lane_far), mid_y - px(1.83), max(base, lane_far), mid_y + px(1.83)]
        d.rectangle(lane, fill=paint, outline=WHITE, width=lw)
        # Free-throw circle: solid outside the lane, dashed inside it.
        r = px(1.83)
        circle = [lane_far - r, mid_y - r, lane_far + r, mid_y + r]
        outside = (270, 90) if inward > 0 else (90, 270)
        d.arc(circle, outside[0], outside[1], fill=WHITE, width=lw)
        inside_start = outside[1]
        for k in range(8):
            a0 = inside_start + k * 22.5
            d.arc(circle, a0, a0 + 11, fill=WHITE, width=lw)
        # Lane hash marks.
        for along in (2.13, 3.05, 3.96, 4.88):
            x = base + inward * px(along)
            for side in (-1, 1):
                y = mid_y + side * px(1.83)
                d.line([x, y, x, y + side * px(0.2)], fill=WHITE, width=lw)
        # Three-point line: 6.02 m from the basket (1.575 m in from the baseline), straight
        # down to the baseline where the arc meets the sideline's parallel.
        basket = base + inward * px(1.575)
        r3 = px(6.02)
        d.arc([basket - r3, mid_y - r3, basket + r3, mid_y + r3],
                270 if inward > 0 else 90, 90 if inward > 0 else 270, fill=WHITE, width=lw)
        for side in (-1, 1):
            y = mid_y + side * r3
            d.line([base, y, basket, y], fill=WHITE, width=lw)
        # Small no-charge arc under the basket.
        r1 = px(1.22)
        d.arc([basket - r1, mid_y - r1, basket + r1, mid_y + r1],
                270 if inward > 0 else 90, 90 if inward > 0 else 270, fill=WHITE, width=lw)
        # The team name behind each baseline, reading from the court.
        centred_text(d, (base + end * px(MARGIN * 0.5), mid_y), 'BULLDOGS', int(px(0.75)),
                NAVY + (230,), angle=90 if end < 0 else -90, img=img)
    # Boundary, half-court line and centre circle (with the school's W).
    d.rectangle([left, top, right, bottom], outline=WHITE, width=lw)
    d.line([mid_x, top, mid_x, bottom], fill=WHITE, width=lw)
    r = px(1.83)
    d.ellipse([mid_x - r, mid_y - r, mid_x + r, mid_y + r], fill=NAVY + (225,), outline=WHITE, width=lw)
    r2 = px(0.61)
    d.ellipse([mid_x - r2, mid_y - r2, mid_x + r2, mid_y + r2], outline=GOLD + (255,), width=lw)
    centred_text(d, (mid_x, mid_y + px(0.05)), 'W', int(px(1.9)), GOLD + (240,))
    # WESTFIELD along both sidelines, outside the court.
    for side in (-1, 1):
        y = (top if side < 0 else bottom) + side * px(MARGIN * 0.5)
        centred_text(d, (mid_x, y), 'WESTFIELD', int(px(0.6)), RED + (220,), angle=0 if side > 0 else 180, img=img)
    img.save(os.path.join(OUT, 'court.png'))


# --- Scoreboard -------------------------------------------------------------------------------

def scoreboard():
    w, h = 1024, 512
    face = Image.new('RGB', (w, h), (14, 14, 16))
    glow = Image.new('RGB', (w, h), (0, 0, 0))
    d, g = ImageDraw.Draw(face), ImageDraw.Draw(glow)
    d.rectangle([0, 0, w - 1, h - 1], outline=(70, 70, 76), width=10)
    d.rectangle([10, 10, w - 11, 70], fill=RED)
    centred_text(d, (w / 2, 40), 'WESTFIELD BULLDOGS', 52, WHITE)
    unlit = (40, 12, 10)
    lit = (255, 60, 30)
    for label, x in (('HOME', 200), ('GUEST', 824)):
        centred_text(d, (x, 110), label, 56, (225, 225, 225))
        for target, colour in ((d, unlit), (g, lit)):
            centred_text(target, (x, 250), '00', 190, colour)
    for target, colour in ((d, unlit), (g, (255, 200, 40))):
        centred_text(target, (w / 2, 200), '00:00', 120, colour if target is g else (40, 34, 8))
    centred_text(d, (w / 2, 330), 'PERIOD', 44, (225, 225, 225))
    for target, colour in ((d, unlit), (g, lit)):
        centred_text(target, (w / 2, 400), '4', 110, colour)
    for label, x in (('FOULS', 200), ('FOULS', 824)):
        centred_text(d, (x, 400), label, 40, (200, 200, 200))
    face.save(os.path.join(OUT, 'scoreboard.png'))
    glow.save(os.path.join(OUT, 'scoreboard_glow.png'))


# --- Banners ----------------------------------------------------------------------------------

BANNERS = {
    'banner_home': ((960, 320), NAVY, GOLD, ['HOME OF THE', 'BULLDOGS'], False),
    'banner_state_87': ((256, 400), RED, WHITE, ['STATE', 'CHAMPIONS', '1987'], True),
    'banner_district_94': ((256, 400), NAVY, GOLD, ['DISTRICT', 'CHAMPIONS', '1994'], True),
    'banner_conference_03': ((256, 400), RED, WHITE, ['CONFERENCE', 'CHAMPIONS', '2003'], True),
    'banner_state_11': ((256, 400), NAVY, WHITE, ['STATE', 'FINALISTS', '2011'], True),
}


def banners():
    for name, ((w, h), back, ink, lines, pennant) in BANNERS.items():
        img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        if pennant:
            point = int(h * 0.82)
            d.polygon([(0, 0), (w, 0), (w, point), (w / 2, h - 1), (0, point)], fill=back + (255,))
            d.line([(8, 8), (w - 8, 8)], fill=ink + (255,), width=6)
        else:
            d.rectangle([0, 0, w - 1, h - 1], fill=back + (255,))
            d.rectangle([12, 12, w - 13, h - 13], outline=ink + (255,), width=8)
        size = int(h * (0.2 if pennant else 0.36))
        y = h * (0.22 if pennant else 0.3)
        for line in lines:
            line_size = size if line != lines[-1] or not pennant else int(size * 1.25)
            # Shrunk to fit across the banner with a little room either side.
            while d.textlength(line, font=font(line_size)) > w * 0.84:
                line_size -= 2
            centred_text(d, (w / 2, y), line, line_size, ink + (255,))
            y += size * (1.05 if pennant else 1.15)
        img.save(os.path.join(OUT, name + '.png'))


# --- Ball and net -----------------------------------------------------------------------------

def basketball():
    w, h = 512, 256
    img = Image.new('RGB', (w, h), (196, 92, 34))
    px = img.load()
    for y in range(h):
        lat = (y / h - 0.5) * math.pi
        for x in range(w):
            lon = x / w * 2 * math.pi
            # The pebbled skin, then the seams: the equator, a meridian ring, and two curves.
            shade = 0.92 + 0.08 * math.sin(x * 1.7) * math.sin(y * 1.9)
            px[x, y] = tuple(int(c * shade) for c in (196, 92, 34))
            vx, vy, vz = math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)
            near = min(abs(vy), abs(vz), abs(abs(vx) - 0.62 - 0.12 * vy * vy))
            if near < 0.022:
                px[x, y] = (24, 16, 12)
    img.save(os.path.join(OUT, 'basketball.png'))


def net():
    w, h = 256, 256
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(-8, 9):
        d.line([(k * 32, 0), (k * 32 + h, h)], fill=(240, 240, 235, 255), width=5)
        d.line([(k * 32 + h, 0), (k * 32, h)], fill=(240, 240, 235, 255), width=5)
    img.save(os.path.join(OUT, 'net.png'))


court()
scoreboard()
banners()
basketball()
net()
print('written to', os.path.normpath(OUT))
