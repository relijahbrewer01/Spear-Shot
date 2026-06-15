from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SPRITE_DIR = ROOT / "art" / "sprites"


def draw_shielded_enemy(path: Path) -> None:
    image = Image.new("RGBA", (28, 28), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Broad, grounded silhouette. The shield plates are runtime primitives.
    draw.ellipse((6, 7, 22, 25), fill=(49, 38, 34, 255))
    draw.ellipse((7, 3, 21, 21), fill=(157, 138, 119, 255))
    draw.ellipse((9, 5, 19, 17), fill=(184, 158, 128, 255))
    draw.rectangle((10, 15, 18, 22), fill=(116, 95, 86, 255))
    draw.point((10, 10), fill=(58, 42, 38, 255))
    draw.point((17, 10), fill=(58, 42, 38, 255))
    draw.rectangle((12, 13, 16, 14), fill=(82, 61, 51, 255))

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def main() -> None:
    draw_shielded_enemy(SPRITE_DIR / "shielded_enemy.png")


if __name__ == "__main__":
    main()
