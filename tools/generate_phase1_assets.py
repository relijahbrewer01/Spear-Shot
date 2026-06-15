from __future__ import annotations

from pathlib import Path
import random

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ART_DIR = ROOT / "art"


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    hex_color = hex_color.lstrip("#")
    return (
        int(hex_color[0:2], 16),
        int(hex_color[2:4], 16),
        int(hex_color[4:6], 16),
        alpha,
    )


def new_canvas(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, (0, 0, 0, 0))


def save(image: Image.Image, relative_path: str) -> None:
    path = ART_DIR / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def generate_player() -> None:
    image = new_canvas((16, 16))
    draw = ImageDraw.Draw(image)

    outline = rgba("#1E2430")
    hood = rgba("#7FA7C8")
    hood_shadow = rgba("#4D6885")
    cloak = rgba("#3B5164")
    cloak_shadow = rgba("#273949")
    trim = rgba("#D6D0B0")
    face = rgba("#E6C8A9")
    satchel = rgba("#7A5A3E")

    draw.polygon([(4, 4), (8, 3), (12, 5), (11, 8), (7, 9), (4, 7)], fill=hood, outline=outline)
    draw.polygon([(3, 8), (7, 6), (11, 7), (12, 12), (5, 13), (3, 11)], fill=cloak, outline=outline)
    draw.polygon([(6, 5), (9, 5), (10, 7), (7, 8), (6, 7)], fill=face)
    draw.rectangle((6, 10, 9, 11), fill=trim)
    draw.rectangle((5, 11, 10, 12), fill=satchel)
    draw.point((10, 6), fill=outline)
    draw.point((11, 6), fill=outline)
    draw.point((7, 4), fill=hood_shadow)
    draw.point((8, 4), fill=hood_shadow)
    draw.point((4, 9), fill=cloak_shadow)
    draw.point((5, 10), fill=cloak_shadow)
    draw.point((10, 9), fill=trim)
    draw.point((11, 10), fill=trim)

    save(image, "sprites/player_hunter.png")


def generate_enemy() -> None:
    image = new_canvas((16, 16))
    draw = ImageDraw.Draw(image)

    outline = rgba("#1C1316")
    mid = rgba("#A7A0A5")
    bright = rgba("#ECE5EA")
    shade = rgba("#6E6670")

    draw.polygon([(4, 4), (9, 3), (12, 5), (11, 10), (7, 12), (4, 10), (3, 7)], fill=mid, outline=outline)
    draw.rectangle((5, 6, 10, 9), fill=bright)
    draw.rectangle((5, 9, 10, 10), fill=shade)
    draw.point((6, 7), fill=outline)
    draw.point((9, 7), fill=outline)
    draw.point((4, 11), fill=shade)
    draw.point((10, 11), fill=shade)
    draw.point((11, 9), fill=shade)

    save(image, "sprites/enemy_creature.png")


def generate_charger() -> None:
    image = new_canvas((16, 16))
    draw = ImageDraw.Draw(image)

    outline = rgba("#21180F")
    mid = rgba("#B0A59A")
    bright = rgba("#F2E8D8")
    shade = rgba("#75695F")

    draw.polygon([(3, 6), (8, 3), (12, 5), (13, 8), (10, 11), (5, 12), (2, 9)], fill=mid, outline=outline)
    draw.polygon([(9, 4), (12, 2), (13, 4), (11, 5)], fill=bright, outline=outline)
    draw.rectangle((5, 6, 10, 9), fill=bright)
    draw.point((6, 7), fill=outline)
    draw.point((9, 7), fill=outline)
    draw.point((4, 10), fill=shade)
    draw.point((11, 9), fill=shade)
    draw.point((12, 7), fill=shade)

    save(image, "sprites/charger_beast.png")


def generate_spear() -> None:
    image = new_canvas((20, 8))
    draw = ImageDraw.Draw(image)

    outline = rgba("#261B15")
    wood = rgba("#7C6042")
    wrap = rgba("#B69263")
    metal = rgba("#D8DEE5")
    metal_shadow = rgba("#8E98A6")

    draw.rectangle((1, 3, 12, 4), fill=wood, outline=outline)
    draw.rectangle((6, 2, 8, 5), fill=wrap)
    draw.polygon([(12, 1), (18, 3), (12, 6), (14, 3)], fill=metal, outline=outline)
    draw.line((12, 3, 17, 3), fill=metal_shadow)
    draw.point((3, 2), fill=wrap)
    draw.point((4, 5), fill=wrap)

    save(image, "sprites/spear_hunter.png")


def generate_arena() -> None:
    width, height = 384, 216
    image = Image.new("RGBA", (width, height), rgba("#455449"))
    draw = ImageDraw.Draw(image)

    wall_dark = rgba("#29322E")
    floor_dark = rgba("#455449")
    floor_mid = rgba("#506150")
    floor_light = rgba("#5A6D59")
    dirt = rgba("#61624B")
    grass = rgba("#718164")
    stone = rgba("#78857A")
    stone_shadow = rgba("#536056")
    scuff = rgba("#667763")
    crack = rgba("#38423C")
    flower = rgba("#9DB59E")

    play_rect = (16, 16, 368, 200)
    draw.rectangle((0, 0, width - 1, height - 1), fill=wall_dark)
    draw.rectangle(play_rect, fill=floor_mid)

    rng = random.Random(7)

    for y in range(play_rect[1], play_rect[3], 4):
        for x in range(play_rect[0], play_rect[2], 4):
            tone = rng.choice([floor_dark, floor_mid, floor_mid, floor_light])
            draw.rectangle((x, y, x + 3, y + 3), fill=tone)

    for _ in range(18):
        patch_x = rng.randint(28, 330)
        patch_y = rng.randint(28, 170)
        patch_w = rng.randint(18, 42)
        patch_h = rng.randint(12, 28)
        draw.ellipse((patch_x, patch_y, patch_x + patch_w, patch_y + patch_h), fill=dirt)

    for _ in range(26):
        tuft_x = rng.randint(28, 344)
        tuft_y = rng.randint(28, 184)
        draw.point((tuft_x, tuft_y), fill=grass)
        draw.point((tuft_x + 1, tuft_y), fill=grass)
        draw.point((tuft_x, tuft_y - 1), fill=flower)

    for _ in range(20):
        crack_x = rng.randint(30, 340)
        crack_y = rng.randint(30, 182)
        length = rng.randint(5, 12)
        for step in range(length):
            draw.point((crack_x + step, crack_y + (step % 2)), fill=crack)

    draw.line((154, 100, 162, 102), fill=scuff, width=1)
    draw.line((225, 117, 233, 120), fill=scuff, width=1)
    draw.line((186, 134, 191, 137), fill=scuff, width=1)
    draw.arc((160, 95, 176, 111), start=18, end=94, fill=scuff, width=1)
    draw.arc((209, 96, 223, 110), start=205, end=302, fill=scuff, width=1)

    for x in range(20, 364, 12):
        draw.rectangle((x, 12, x + 7, 15), fill=stone)
        draw.rectangle((x, 200, x + 7, 203), fill=stone_shadow)
    for y in range(20, 196, 12):
        draw.rectangle((12, y, 15, y + 7), fill=stone)
        draw.rectangle((368, y, 371, y + 7), fill=stone_shadow)

    for corner in [(24, 24), (344, 24), (24, 176), (344, 176)]:
        cx, cy = corner
        draw.rectangle((cx, cy, cx + 6, cy + 6), fill=stone)
        draw.rectangle((cx + 2, cy + 2, cx + 4, cy + 4), fill=floor_light)

    save(image, "arena/arena_floor.png")


def main() -> None:
    generate_player()
    generate_enemy()
    generate_charger()
    generate_spear()
    generate_arena()


if __name__ == "__main__":
    main()
