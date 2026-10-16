"""Paints the school's flat art into assets/textures/school/: python3 tools/gen_school_art.py

poster_*.png      posters for the walls (some of them are hints)
bookcase.png      one bay of a library bookcase seen from the front: shelves full of books
painting_*.png    the art class's canvases
periodic.png      the periodic table for the science lab
"""
import os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'textures', 'school')
TITLE = os.path.join(HERE, '..', 'assets', 'fonts', 'BebasNeue.ttf')
TYPED = os.path.join(HERE, '..', 'assets', 'fonts', 'SpecialElite.ttf')
os.makedirs(OUT, exist_ok=True)
random.seed(7)

NAVY, RED, GOLD, CREAM = (22, 34, 66), (128, 22, 26), (214, 168, 52), (238, 232, 214)


def fit(draw, text, path, size, width):
    while draw.textlength(text, font=ImageFont.truetype(path, size)) > width and size > 8:
        size -= 2
    return ImageFont.truetype(path, size)


def lines(draw, w, y, rows, path, size, fill, gap=1.1):
    for row in rows:
        f = fit(draw, row, path, size, w * 0.86)
        box = draw.textbbox((0, 0), row, font=f)
        draw.text(((w - (box[2] - box[0])) / 2 - box[0], y - box[1]), row, font=f, fill=fill)
        y += (box[3] - box[1]) * gap + size * 0.15
    return y


def aged(img):
    """A little sun-fade and grime, and a tape mark at each top corner."""
    img = img.convert('RGB')
    fade = Image.new('RGB', img.size, (230, 222, 200))
    img = Image.blend(img, fade, 0.12)
    d = ImageDraw.Draw(img)
    w, h = img.size
    for x in (18, w - 78):
        d.rectangle([x, 4, x + 60, 26], fill=(220, 214, 180))
    return img


def poster(name, back, rows, ink, sub=None, sub_ink=None, art=None):
    w, h = 512, 720
    img = Image.new('RGB', (w, h), back)
    d = ImageDraw.Draw(img)
    if art in (stripes, stars):
        art(d, w, h)  # a pattern behind everything
    y = lines(d, w, 70, rows, TITLE, 150, ink)
    sub_top = h - 60 - 46 * len(sub) if sub else h - 40
    if art and art not in (stripes, stars):
        # The picture, drawn on its own and fitted into the space between title and small print.
        layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        art(ImageDraw.Draw(layer), w, h)
        layer = layer.crop(layer.getbbox())
        room = (w * 0.7, sub_top - y - 40)
        scale = min(room[0] / layer.width, room[1] / layer.height)
        layer = layer.resize((int(layer.width * scale), int(layer.height * scale)), Image.LANCZOS)
        img.paste(layer, (int((w - layer.width) / 2), int(y + 20 + (room[1] - layer.height) / 2)), layer)
    if sub:
        lines(d, w, max(y + 20, sub_top), sub, TYPED, 38, sub_ink or ink, 1.25)
    aged(img).save(os.path.join(OUT, 'poster_%s.png' % name))


def walker(d, w, h):
    # A tall thin figure with a whistle, in a no-running circle: the Hall Monitor's rule.
    cx, cy = w / 2, h * 0.58
    d.ellipse([cx - 170, cy - 170, cx + 170, cy + 170], outline=RED, width=22)
    d.line([cx - 120, cy + 120, cx + 120, cy - 120], fill=RED, width=22)
    d.ellipse([cx - 22, cy - 150, cx + 22, cy - 100], fill=(20, 20, 20))
    d.line([cx, cy - 100, cx, cy + 40], fill=(20, 20, 20), width=14)
    d.line([cx, cy + 40, cx - 40, cy + 140], fill=(20, 20, 20), width=12)
    d.line([cx, cy + 40, cx + 50, cy + 130], fill=(20, 20, 20), width=12)
    d.line([cx, cy - 70, cx - 60, cy], fill=(20, 20, 20), width=10)
    d.line([cx, cy - 70, cx + 70, cy - 20], fill=(20, 20, 20), width=10)


def stripes(d, w, h):
    for i in range(0, h, 60):
        d.rectangle([0, i, w, i + 26], fill=(28, 44, 84))


def flask(d, w, h):
    cx, cy = w / 2, h * 0.6
    d.polygon([(cx - 40, cy - 150), (cx + 40, cy - 150), (cx + 40, cy - 40), (cx + 140, cy + 140),
            (cx - 140, cy + 140), (cx - 40, cy - 40)], outline=CREAM, fill=(40, 120, 90), width=8)
    for bx, by, r in ((cx - 30, cy + 60, 18), (cx + 40, cy + 20, 12), (cx, cy - 10, 9)):
        d.ellipse([bx - r, by - r, bx + r, by + r], outline=CREAM, width=4)


def book(d, w, h):
    cx, cy = w / 2, h * 0.6
    d.polygon([(cx, cy - 60), (cx - 180, cy - 110), (cx - 180, cy + 110), (cx, cy + 160)], fill=CREAM)
    d.polygon([(cx, cy - 60), (cx + 180, cy - 110), (cx + 180, cy + 110), (cx, cy + 160)], fill=(250, 246, 232))
    for k in range(5):
        y = cy - 60 + k * 36
        d.line([cx - 160, y - 30, cx - 20, y + 10], fill=(150, 140, 120), width=4)
        d.line([cx + 20, y + 10, cx + 160, y - 30], fill=(150, 140, 120), width=4)


def hands(d, w, h):
    cx, cy = w / 2, h * 0.6
    for dx in (-80, 80):
        d.rounded_rectangle([cx + dx - 60, cy - 120, cx + dx + 60, cy + 120], 50, fill=(230, 190, 160))
    for k in range(8):
        x, y = cx + random.randint(-180, 180), cy + random.randint(-170, 160)
        r = random.randint(10, 22)
        d.ellipse([x - r, y - r, x + r, y + r], outline=(120, 180, 230), width=5)


def ball(d, w, h):
    cx, cy, r = w / 2, h * 0.62, 150
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(205, 100, 36), outline=(30, 20, 15), width=8)
    d.line([cx - r, cy, cx + r, cy], fill=(30, 20, 15), width=7)
    d.line([cx, cy - r, cx, cy + r], fill=(30, 20, 15), width=7)
    d.arc([cx - r * 1.6, cy - r, cx - r * 0.2, cy + r], -60, 60, fill=(30, 20, 15), width=7)
    d.arc([cx + r * 0.2, cy - r, cx + r * 1.6, cy + r], 120, 240, fill=(30, 20, 15), width=7)


def stars(d, w, h):
    for k in range(40):
        x, y = random.randint(0, w), random.randint(260, h - 120)
        r = random.randint(3, 9)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(random.randint(200, 255), random.randint(170, 230), 120))


def posters():
    poster('no_running', CREAM, ['WALK,', "DON'T RUN"], RED, ['The hall monitor', 'is always watching.'], NAVY, walker)
    poster('basketball', NAVY, ['BULLDOGS', 'BASKETBALL'], GOLD, ['Home game Friday 7 PM', 'Pack the bleachers!'], CREAM, ball)
    poster('science_fair', (24, 70, 58), ['SCIENCE', 'FAIR'], CREAM, ['Entries due to Room 103', 'by the end of the month'], GOLD, flask)
    poster('read', (176, 70, 40), ['READ!'], CREAM, ['Your library is open', 'until 4 PM every day'], CREAM, book)
    poster('quiet', NAVY, ['QUIET', 'PLEASE'], CREAM, ['Whispers carry.', 'Somebody is listening.'], GOLD)
    poster('wash_hands', (236, 240, 244), ['WASH YOUR', 'HANDS'], (30, 90, 150), ['20 seconds. Soap. Every time.', '- The Nurse'], (60, 60, 60), hands)
    poster('dance', (52, 24, 70), ['SPRING', 'DANCE'], (240, 190, 230), ['Saturday in the gym', 'Tickets at the front office'], CREAM, stars)
    poster('lost_found', CREAM, ['LOST &', 'FOUND'], NAVY, ['Ask at the front office.', 'Unclaimed items are', 'thrown out on Friday.'], (40, 40, 40))
    poster('president', (200, 30, 40), ['VOTE', 'DANA K.'], CREAM, ['for class president', 'Longer lunches! No homework!'], CREAM, stripes)
    poster('stay_in_class', (238, 214, 120), ['STAY IN', 'YOUR SEAT'], (40, 30, 20), ['Wait for the bell.', 'Wait for the bell.', 'Wait for the bell.'], (90, 40, 30))


# --- Bookcase ---------------------------------------------------------------------------------
# One bay, 1.5 m wide and 2 m tall at 512 px per metre-ish: five shelves of books on a dark back.

def bookcase():
    w, h = 768, 1024
    img = Image.new('RGB', (w, h), (34, 24, 18))
    d = ImageDraw.Draw(img)
    board = (110, 76, 48)
    levels = 5
    gap = h / levels
    spines = [(122, 28, 30), (32, 52, 96), (40, 86, 52), (150, 120, 60), (92, 44, 82), (196, 170, 120),
              (60, 60, 64), (176, 92, 40), (24, 24, 28), (210, 200, 180), (70, 110, 130), (130, 40, 50)]
    for level in range(levels):
        top = int(level * gap)
        floor = int(top + gap - 18)
        d.rectangle([0, floor, w, top + gap], fill=board)
        d.line([0, floor, w, floor], fill=(150, 110, 72), width=3)
        x = 6
        while x < w - 10:
            if random.random() < 0.06:
                x += random.randint(20, 60)  # a gap where books are out
                continue
            bw = random.randint(16, 40)
            bh = random.randint(int(gap * 0.55), int(gap * 0.85))
            colour = random.choice(spines)
            shade = random.uniform(0.75, 1.1)
            colour = tuple(max(0, min(255, int(c * shade))) for c in colour)
            leaning = random.random() < 0.05
            if leaning:
                d.polygon([(x, floor), (x + bw, floor), (x + bw + 26, floor - bh), (x + 26, floor - bh)], fill=colour)
                x += bw + 30
                continue
            d.rectangle([x, floor - bh, x + bw, floor], fill=colour)
            # Bands and a title block on the spine.
            band = tuple(min(255, int(c * 1.35)) for c in colour)
            d.rectangle([x + 2, floor - bh + 10, x + bw - 2, floor - bh + 14], fill=band)
            d.rectangle([x + 2, floor - 22, x + bw - 2, floor - 18], fill=band)
            if bw > 22:
                d.rectangle([x + 5, floor - bh * 0.6, x + bw - 5, floor - bh * 0.6 + bh * 0.25], fill=band)
            d.line([x + bw, floor - bh, x + bw, floor], fill=(20, 14, 10), width=2)
            x += bw + random.choice([0, 0, 0, 1, 2])
    # The frame's sides.
    d.rectangle([0, 0, 8, h], fill=board)
    d.rectangle([w - 8, 0, w, h], fill=board)
    img.save(os.path.join(OUT, 'bookcase.png'))


# --- Paintings --------------------------------------------------------------------------------

def paintings():
    palettes = [
        [(222, 120, 60), (40, 80, 140), (240, 210, 120), (30, 30, 40)],
        [(60, 140, 90), (230, 230, 210), (200, 60, 80), (40, 60, 50)],
        [(90, 60, 150), (240, 180, 70), (230, 90, 70), (20, 20, 30)],
        [(100, 160, 210), (250, 245, 230), (60, 90, 120), (210, 150, 100)],
    ]
    for i, palette in enumerate(palettes):
        w, h = 384, 512
        img = Image.new('RGB', (w, h), (236, 230, 216))
        d = ImageDraw.Draw(img)
        if i == 3:
            # A landscape: sky, hills, a house.
            d.rectangle([0, 0, w, h * 0.55], fill=palette[0])
            d.ellipse([-100, h * 0.4, w * 0.8, h * 0.9], fill=(90, 140, 80))
            d.ellipse([w * 0.3, h * 0.45, w + 120, h], fill=(70, 120, 70))
            d.rectangle([w * 0.55, h * 0.48, w * 0.75, h * 0.62], fill=palette[3])
            d.polygon([(w * 0.53, h * 0.48), (w * 0.65, h * 0.4), (w * 0.77, h * 0.48)], fill=palette[2])
            d.ellipse([w * 0.12, h * 0.1, w * 0.28, h * 0.22], fill=palette[1])
        else:
            for k in range(26):
                colour = random.choice(palette)
                x, y = random.randint(-40, w), random.randint(-40, h)
                s = random.randint(40, 180)
                shape = random.random()
                if shape < 0.4:
                    d.ellipse([x, y, x + s, y + s], fill=colour)
                elif shape < 0.7:
                    d.rectangle([x, y, x + s, y + s * 0.6], fill=colour)
                else:
                    d.line([x, y, x + s, y + random.randint(-s, s)], fill=colour, width=random.randint(6, 18))
        img = img.filter(ImageFilter.GaussianBlur(1.2))
        img.save(os.path.join(OUT, 'painting_%d.png' % (i + 1)))


# --- Periodic table ---------------------------------------------------------------------------

SYMBOLS = ('H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr '
           'Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn '
           'Fr Ra Ac Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og').split()


def periodic():
    w, h = 1024, 640
    img = Image.new('RGB', (w, h), (236, 234, 226))
    d = ImageDraw.Draw(img)
    lines(d, w, 14, ['PERIODIC TABLE OF THE ELEMENTS'], TITLE, 52, NAVY)
    cell = 54
    left, top = (w - 18 * cell) / 2, 90
    # Row/column of each element in the short form (lanthanides and actinides left in the main rows).
    layout = []
    for period, count in ((1, 2), (2, 8), (3, 8), (4, 18), (5, 18), (6, 18), (7, 18)):
        if count == 2:
            columns = [1, 18]
        elif count == 8:
            columns = [1, 2] + list(range(13, 19))
        else:
            columns = list(range(1, 19))
        layout += [(period, c) for c in columns]
    groups = {1: (230, 150, 140), 2: (240, 200, 140), 17: (180, 220, 160), 18: (170, 200, 230)}
    small = ImageFont.truetype(TITLE, 26)
    tiny = ImageFont.truetype(TITLE, 13)
    for i, (period, column) in enumerate(layout[:len(SYMBOLS)]):
        x, y = left + (column - 1) * cell, top + (period - 1) * cell
        colour = groups.get(column, (200, 200, 210) if 3 <= column <= 12 else (220, 220, 170))
        d.rectangle([x, y, x + cell - 3, y + cell - 3], fill=colour, outline=(90, 90, 90))
        d.text((x + 4, y + 2), str(i + 1), font=tiny, fill=(50, 50, 50))
        box = d.textbbox((0, 0), SYMBOLS[i], font=small)
        d.text((x + (cell - 3 - (box[2] - box[0])) / 2 - box[0], y + 18 - box[1] + 4), SYMBOLS[i], font=small, fill=(20, 20, 20))
    aged(img).save(os.path.join(OUT, 'periodic.png'))


def menu():
    """The cafeteria's chalkboard menu."""
    w, h = 768, 1024
    img = Image.new('RGB', (w, h), (30, 44, 36))
    d = ImageDraw.Draw(img)
    for k in range(400):
        x, y = random.randint(0, w), random.randint(0, h)
        d.point((x, y), fill=(60, 76, 66))
    d.rectangle([0, 0, w - 1, h - 1], outline=(120, 86, 52), width=26)
    chalk = (232, 232, 220)
    y = lines(d, w, 60, ["TODAY'S LUNCH"], TITLE, 110, chalk)
    days = [('MON', 'Pizza & corn'), ('TUE', 'Tacos'), ('WED', 'Chicken nuggets'), ('THU', 'Meatloaf'),
            ('FRI', 'Fish sticks'), ('', ''), ('SAT', 'Closed'), ('SUN', 'Closed')]
    f_day, f_food = ImageFont.truetype(TITLE, 64), ImageFont.truetype(TYPED, 46)
    y += 30
    for day, food in days:
        if day:
            d.text((70, y), day, font=f_day, fill=(240, 200, 120))
            d.text((210, y + 10), food, font=f_food, fill=chalk)
        y += 84
    lines(d, w, y + 10, ['Seconds: ask the Lunch Lady.', 'Do NOT go into the kitchen.'], TYPED, 40, (240, 160, 150), 1.3)
    img.save(os.path.join(OUT, 'menu.png'))


posters()
menu()
bookcase()
paintings()
periodic()
print('written to', os.path.normpath(OUT))
