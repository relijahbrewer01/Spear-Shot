from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SPRITE_DIR = ROOT / "art" / "sprites"


def draw_shielded_enemy(path: Path) -> None:
    image = Image.new("RGBA", (22, 22), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Broad, grounded silhouette. The shield plates are runtime primitives.
    draw.ellipse((5, 6, 17, 20), fill=(49, 38, 34, 255))
    draw.ellipse((5, 2, 17, 17), fill=(157, 138, 119, 255))
    draw.ellipse((7, 4, 15, 13), fill=(184, 158, 128, 255))
    draw.rectangle((8, 12, 14, 18), fill=(116, 95, 86, 255))
    draw.point((8, 8), fill=(58, 42, 38, 255))
    draw.point((14, 8), fill=(58, 42, 38, 255))
    draw.rectangle((9, 10, 13, 11), fill=(82, 61, 51, 255))

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def draw_shooter_enemy(path: Path) -> None:
    image = Image.new("RGBA", (16, 18), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Small wary skirmisher body; the oversized blowgun is a runtime primitive
    # so it can rotate toward the locked shot direction.
    draw.ellipse((5, 7, 11, 17), fill=(36, 38, 26, 255))
    draw.ellipse((4, 4, 12, 14), fill=(108, 122, 74, 255))
    draw.polygon([(4, 8), (2, 10), (6, 10)], fill=(65, 77, 48, 255))
    draw.polygon([(12, 8), (14, 10), (10, 10)], fill=(65, 77, 48, 255))
    draw.ellipse((5, 1, 11, 7), fill=(139, 131, 78, 255))
    draw.rectangle((6, 8, 10, 12), fill=(86, 70, 46, 255))
    draw.point((6, 5), fill=(31, 28, 22, 255))
    draw.point((10, 5), fill=(31, 28, 22, 255))
    draw.rectangle((6, 7, 10, 8), fill=(48, 37, 28, 255))
    draw.line((11, 10, 15, 13), fill=(190, 161, 91, 255), width=1)
    draw.line((11, 12, 15, 15), fill=(190, 161, 91, 255), width=1)
    draw.rectangle((3, 12, 4, 16), fill=(84, 61, 38, 255))

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def main() -> None:
    draw_shielded_enemy(SPRITE_DIR / "shielded_enemy.png")
    draw_shooter_enemy(SPRITE_DIR / "shooter_enemy.png")


if __name__ == "__main__":
    main()
