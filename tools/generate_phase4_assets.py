from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass, replace
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SPRITE_DIR = ROOT / "art" / "sprites"
DEV_SHOOTER_DIR = ROOT / "art" / "dev" / "shooter_candidates"
DEV_EXPLODER_DIR = ROOT / "art" / "dev" / "exploder_candidates"
ARENA_TEXTURE_PATH = ROOT / "art" / "arena" / "arena_floor.png"
ARENA_SIZE = (384, 216)
PLAY_RECT = (16, 16, 368, 200)
BOUNDARY_COLOR = (204, 220, 190, 170)
LABEL_TEXT_COLOR = (239, 242, 230, 255)
LABEL_SHADOW_COLOR = (17, 20, 18, 220)
SHOOTER_CANVAS_SIZE = (16, 18)
EXPLODER_CANVAS_SIZE = (16, 18)
SHOOTER_BLOWGUN_LENGTH = 14
SHOOTER_BLOWGUN_WIDTH = 1
SHOOTER_BLOWGUN_ORIGIN = (10, 7)
SHOOTER_BLOWGUN_DIRECTION = (14, -1)


@dataclass(frozen=True)
class ShooterPaletteVariantSpec:
    key: str
    title: str
    file_name: str
    palette_summary: str
    contrast_summary: str
    hood_color: tuple[int, int, int, int]
    face_color: tuple[int, int, int, int]
    shadow_color: tuple[int, int, int, int]
    torso_color: tuple[int, int, int, int]
    strap_color: tuple[int, int, int, int]
    pouch_color: tuple[int, int, int, int]
    canvas_width: int = SHOOTER_CANVAS_SIZE[0]
    canvas_height: int = SHOOTER_CANVAS_SIZE[1]
    apparent_body_width: int = 0
    apparent_body_height: int = 0
    blowgun_length: int = SHOOTER_BLOWGUN_LENGTH
    blowgun_width: int = SHOOTER_BLOWGUN_WIDTH
    blowgun_origin_x: int = SHOOTER_BLOWGUN_ORIGIN[0]
    blowgun_origin_y: int = SHOOTER_BLOWGUN_ORIGIN[1]
    blowgun_direction_x: int = SHOOTER_BLOWGUN_DIRECTION[0]
    blowgun_direction_y: int = SHOOTER_BLOWGUN_DIRECTION[1]
    silhouette_summary: str = "Approved A/B hybrid silhouette on the live 16x18 canvas."


@dataclass(frozen=True)
class ExploderVariantSpec:
    key: str
    title: str
    file_name: str
    palette_summary: str
    silhouette_summary: str
    body_color: tuple[int, int, int, int]
    sac_color: tuple[int, int, int, int]
    mark_color: tuple[int, int, int, int]
    eye_color: tuple[int, int, int, int]
    canvas_width: int = EXPLODER_CANVAS_SIZE[0]
    canvas_height: int = EXPLODER_CANVAS_SIZE[1]
    apparent_body_width: int = 0
    apparent_body_height: int = 0


def draw_exploder_enemy(path: Path) -> None:
    image = Image.new("RGBA", EXPLODER_CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _draw_exploder_variant_silhouette(draw, build_exploder_variant_specs()[1])

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


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
    image = Image.new("RGBA", SHOOTER_CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Final approved live Shooter palette: Variant 2 from the palette cleanup
    # pass. The silhouette stays identical to the approval board.
    _draw_palette_variant_silhouette(draw, build_shooter_palette_variant_specs()[1])

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def build_exploder_variant_specs() -> list[ExploderVariantSpec]:
    return [
        ExploderVariantSpec(
            key="1",
            title="Seed Pod",
            file_name="exploder_variant_1.png",
            palette_summary="dry bark body, ochre seed-pod sac, dark sap cracks",
            silhouette_summary="A squat hopper with a side-loaded seed pod bulge and stubby forward paws.",
            body_color=(112, 86, 61, 255),
            sac_color=(190, 153, 100, 255),
            mark_color=(79, 55, 38, 255),
            eye_color=(228, 214, 170, 255),
        ),
        ExploderVariantSpec(
            key="2",
            title="Throat Sac",
            file_name="exploder_variant_2.png",
            palette_summary="peat-brown body, pale stretched throat sac, dark root markings",
            silhouette_summary="A hunched frog-locust hopper with a swollen forward throat sac and clear crouched legs.",
            body_color=(96, 72, 54, 255),
            sac_color=(208, 177, 126, 255),
            mark_color=(69, 47, 36, 255),
            eye_color=(237, 224, 181, 255),
        ),
        ExploderVariantSpec(
            key="3",
            title="Resin Bladder",
            file_name="exploder_variant_3.png",
            palette_summary="darker bark body, amber resin bladder, sharp charcoal cracks",
            silhouette_summary="A compressed hopper with a larger rear bladder, sharper crack lines, and a flatter predatory head.",
            body_color=(88, 66, 49, 255),
            sac_color=(198, 146, 96, 255),
            mark_color=(54, 39, 31, 255),
            eye_color=(228, 209, 161, 255),
        ),
    ]


def build_shooter_palette_variant_specs() -> list[ShooterPaletteVariantSpec]:
    return [
        ShooterPaletteVariantSpec(
            key="1",
            title="Olive Hood",
            file_name="shooter_palette_variant_1.png",
            palette_summary="olive hood, warm tan face, dark umber torso, muted ochre pouch",
            contrast_summary="Warm face pulls focus first, the olive hood stays distinct, and the torso shadows stay clean against the arena.",
            hood_color=(96, 111, 61, 255),
            face_color=(191, 167, 124, 255),
            shadow_color=(43, 34, 26, 255),
            torso_color=(76, 59, 41, 255),
            strap_color=(124, 132, 86, 255),
            pouch_color=(153, 119, 68, 255),
        ),
        ShooterPaletteVariantSpec(
            key="2",
            title="Moss Hood",
            file_name="shooter_palette_variant_2.png",
            palette_summary="moss-green hood, pale ochre face, charcoal-brown torso, restrained rust accent",
            contrast_summary="The pale face reads fastest, the darker charcoal torso anchors the legs, and the rust pouch keeps the lower silhouette from turning to mud.",
            hood_color=(83, 103, 63, 255),
            face_color=(205, 186, 133, 255),
            shadow_color=(37, 31, 27, 255),
            torso_color=(68, 57, 48, 255),
            strap_color=(116, 122, 88, 255),
            pouch_color=(137, 96, 66, 255),
        ),
        ShooterPaletteVariantSpec(
            key="3",
            title="Peat Hood",
            file_name="shooter_palette_variant_3.png",
            palette_summary="darker peat hood, light bone/tan face, medium bark torso, muted sage accent",
            contrast_summary="This version leans darkest overall, so the face pops strongly and the sage accent helps the forward-leaning posture stay readable.",
            hood_color=(69, 76, 52, 255),
            face_color=(214, 196, 150, 255),
            shadow_color=(34, 28, 24, 255),
            torso_color=(94, 72, 50, 255),
            strap_color=(121, 133, 97, 255),
            pouch_color=(122, 113, 80, 255),
        ),
    ]


def draw_exploder_variant(spec: ExploderVariantSpec, path: Path) -> ExploderVariantSpec:
    image = Image.new("RGBA", (spec.canvas_width, spec.canvas_height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _draw_exploder_variant_silhouette(draw, spec)

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)

    apparent_body_width, apparent_body_height = _measure_nontransparent_bounds(image)
    return replace(
        spec,
        apparent_body_width=apparent_body_width,
        apparent_body_height=apparent_body_height,
    )


def draw_shooter_palette_variant(spec: ShooterPaletteVariantSpec, path: Path) -> ShooterPaletteVariantSpec:
    image = Image.new("RGBA", (spec.canvas_width, spec.canvas_height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _draw_palette_variant_silhouette(draw, spec)

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)

    apparent_body_width, apparent_body_height = _measure_nontransparent_bounds(image)
    return replace(
        spec,
        apparent_body_width=apparent_body_width,
        apparent_body_height=apparent_body_height,
    )


def _draw_exploder_variant_silhouette(draw: ImageDraw.ImageDraw, spec: ExploderVariantSpec) -> None:
    if spec.key == "1":
        draw.ellipse((3, 8, 12, 15), fill=spec.body_color)
        draw.ellipse((8, 4, 14, 11), fill=spec.sac_color)
        draw.polygon([(3, 10), (1, 12), (3, 13)], fill=spec.body_color)
        draw.polygon([(6, 14), (5, 17), (7, 15)], fill=spec.mark_color)
        draw.polygon([(10, 14), (9, 17), (11, 15)], fill=spec.mark_color)
        draw.point((5, 9), fill=spec.eye_color)
        draw.line((9, 6, 12, 8), fill=spec.mark_color, width=1)
        draw.line((9, 9, 12, 10), fill=spec.mark_color, width=1)
        return

    if spec.key == "2":
        draw.ellipse((4, 8, 12, 15), fill=spec.body_color)
        draw.ellipse((6, 5, 11, 10), fill=spec.body_color)
        draw.ellipse((7, 9, 14, 15), fill=spec.sac_color)
        draw.polygon([(4, 12), (2, 14), (5, 14)], fill=spec.body_color)
        draw.polygon([(5, 14), (4, 17), (6, 15)], fill=spec.mark_color)
        draw.polygon([(9, 14), (8, 17), (10, 15)], fill=spec.mark_color)
        draw.point((7, 8), fill=spec.eye_color)
        draw.point((9, 8), fill=spec.eye_color)
        draw.line((10, 10, 12, 12), fill=spec.mark_color, width=1)
        draw.line((8, 11, 11, 13), fill=spec.mark_color, width=1)
        return

    draw.ellipse((4, 8, 11, 15), fill=spec.body_color)
    draw.ellipse((8, 5, 14, 12), fill=spec.sac_color)
    draw.ellipse((4, 5, 9, 10), fill=spec.body_color)
    draw.polygon([(3, 12), (1, 13), (3, 14)], fill=spec.body_color)
    draw.polygon([(5, 14), (4, 17), (6, 15)], fill=spec.mark_color)
    draw.polygon([(9, 14), (8, 17), (10, 15)], fill=spec.mark_color)
    draw.point((6, 8), fill=spec.eye_color)
    draw.line((9, 7, 12, 8), fill=spec.mark_color, width=1)
    draw.line((10, 9, 13, 11), fill=spec.mark_color, width=1)


def _draw_palette_variant_silhouette(draw: ImageDraw.ImageDraw, spec: ShooterPaletteVariantSpec) -> None:
    draw.ellipse((6, 9, 11, 17), fill=spec.shadow_color)
    draw.polygon(
        [(5, 5), (7, 3), (10, 3), (11, 5), (11, 10), (10, 12), (7, 12), (5, 9)],
        fill=spec.hood_color,
    )
    draw.ellipse((6, 2, 10, 4), fill=spec.face_color)
    draw.ellipse((6, 5, 10, 8), fill=spec.face_color)
    draw.polygon([(5, 7), (3, 9), (5, 10)], fill=spec.torso_color)
    draw.polygon([(11, 7), (12, 8), (10, 10)], fill=spec.torso_color)
    draw.rectangle((7, 9, 9, 11), fill=spec.torso_color)
    draw.point((7, 6), fill=spec.shadow_color)
    draw.point((9, 6), fill=spec.shadow_color)
    draw.rectangle((7, 7, 9, 8), fill=spec.shadow_color)
    draw.line((10, 11, 12, 13), fill=spec.strap_color, width=1)
    draw.rectangle((4, 12, 5, 15), fill=spec.pouch_color)


def _measure_nontransparent_bounds(image: Image.Image) -> tuple[int, int]:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return (0, 0)
    return (bbox[2] - bbox[0], bbox[3] - bbox[1])


def generate_shooter_candidate_assets() -> dict[str, object]:
    DEV_SHOOTER_DIR.mkdir(parents=True, exist_ok=True)
    comparison_path = DEV_SHOOTER_DIR / "shooter_palette_comparison.png"
    manifest_path = DEV_SHOOTER_DIR / "shooter_palette_manifest.json"

    variant_specs: list[ShooterPaletteVariantSpec] = []
    manifest_candidates: list[dict[str, object]] = []

    for spec in build_shooter_palette_variant_specs():
        variant_path = DEV_SHOOTER_DIR / spec.file_name
        finalized_spec = draw_shooter_palette_variant(spec, variant_path)
        variant_specs.append(finalized_spec)
        manifest_candidates.append({
            **asdict(finalized_spec),
            "path": str(variant_path),
        })

    draw_shooter_palette_comparison(variant_specs, comparison_path)
    manifest = {
        "comparison_path": str(comparison_path),
        "active_reference_path": str(SPRITE_DIR / "shooter_enemy.png"),
        "candidates": manifest_candidates,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


def generate_exploder_candidate_assets() -> dict[str, object]:
    DEV_EXPLODER_DIR.mkdir(parents=True, exist_ok=True)
    comparison_path = DEV_EXPLODER_DIR / "exploder_comparison.png"
    manifest_path = DEV_EXPLODER_DIR / "exploder_manifest.json"

    variant_specs: list[ExploderVariantSpec] = []
    manifest_candidates: list[dict[str, object]] = []

    for spec in build_exploder_variant_specs():
        variant_path = DEV_EXPLODER_DIR / spec.file_name
        finalized_spec = draw_exploder_variant(spec, variant_path)
        variant_specs.append(finalized_spec)
        manifest_candidates.append({
            **asdict(finalized_spec),
            "path": str(variant_path),
        })

    draw_exploder_comparison(variant_specs, comparison_path)
    manifest = {
        "comparison_path": str(comparison_path),
        "active_reference_path": str(SPRITE_DIR / "exploder_enemy.png"),
        "candidates": manifest_candidates,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


def draw_shooter_palette_comparison(
    variant_specs: list[ShooterPaletteVariantSpec], comparison_path: Path
) -> None:
    background = _load_arena_background()
    draw = ImageDraw.Draw(background)
    font = ImageFont.load_default()

    _draw_label(draw, (8, 8), "Shooter Palette Cleanup Comparison", font)
    _draw_label(draw, (8, 20), "Approved 16x18 silhouette + proposed 14x1 runtime blowgun", font)

    benchmark_row = [
        ("Akedra", ROOT / "art" / "sprites" / "player_hunter.png", (48, 116), False, None),
        ("Normal", ROOT / "art" / "sprites" / "enemy_creature.png", (116, 116), False, None),
        ("Shielded", ROOT / "art" / "sprites" / "shielded_enemy.png", (184, 116), False, None),
        ("Charger", ROOT / "art" / "sprites" / "charger_beast.png", (252, 116), False, None),
        ("Current", SPRITE_DIR / "shooter_enemy.png", (332, 116), True, _build_active_blowgun_spec()),
    ]
    variant_row = [
        ("Variant 1", DEV_SHOOTER_DIR / variant_specs[0].file_name, (96, 194), True, variant_specs[0]),
        ("Variant 2", DEV_SHOOTER_DIR / variant_specs[1].file_name, (192, 194), True, variant_specs[1]),
        ("Variant 3", DEV_SHOOTER_DIR / variant_specs[2].file_name, (288, 194), True, variant_specs[2]),
    ]

    for label, sprite_path, feet_position, draw_blowgun, blowgun_spec in benchmark_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        if draw_blowgun and blowgun_spec is not None:
            _draw_candidate_blowgun(background, blowgun_spec, feet_position)
        _draw_label(draw, (feet_position[0] - 16, feet_position[1] + 4), label, font)

    for label, sprite_path, feet_position, draw_blowgun, blowgun_spec in variant_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        if draw_blowgun and blowgun_spec is not None:
            _draw_candidate_blowgun(background, blowgun_spec, feet_position)
        _draw_label(draw, (feet_position[0] - 22, feet_position[1] + 4), label, font)

    comparison_path.parent.mkdir(parents=True, exist_ok=True)
    background.save(comparison_path)


def draw_exploder_comparison(
    variant_specs: list[ExploderVariantSpec], comparison_path: Path
) -> None:
    background = _load_arena_background()
    draw = ImageDraw.Draw(background)
    font = ImageFont.load_default()

    _draw_label(draw, (8, 8), "Exploder Candidate Comparison", font)
    _draw_label(draw, (8, 20), "Small hopper scale against the live arena and current roster", font)

    benchmark_row = [
        ("Akedra", ROOT / "art" / "sprites" / "player_hunter.png", (48, 116)),
        ("Normal", ROOT / "art" / "sprites" / "enemy_creature.png", (116, 116)),
        ("Shielded", ROOT / "art" / "sprites" / "shielded_enemy.png", (184, 116)),
        ("Shooter", ROOT / "art" / "sprites" / "shooter_enemy.png", (252, 116)),
        ("Charger", ROOT / "art" / "sprites" / "charger_beast.png", (332, 116)),
    ]
    variant_row = [
        ("Variant 1", DEV_EXPLODER_DIR / variant_specs[0].file_name, (96, 194)),
        ("Variant 2", DEV_EXPLODER_DIR / variant_specs[1].file_name, (192, 194)),
        ("Variant 3", DEV_EXPLODER_DIR / variant_specs[2].file_name, (288, 194)),
    ]

    for label, sprite_path, feet_position in benchmark_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        _draw_label(draw, (feet_position[0] - 16, feet_position[1] + 4), label, font)

    for label, sprite_path, feet_position in variant_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        _draw_label(draw, (feet_position[0] - 22, feet_position[1] + 4), label, font)

    comparison_path.parent.mkdir(parents=True, exist_ok=True)
    background.save(comparison_path)


def _build_active_blowgun_spec() -> ShooterPaletteVariantSpec:
    return ShooterPaletteVariantSpec(
        key="current",
        title="Current",
        file_name="shooter_enemy.png",
        palette_summary="Current live palette reference",
        contrast_summary="Active in-game sprite used for side-by-side comparison only.",
        hood_color=(0, 0, 0, 0),
        face_color=(0, 0, 0, 0),
        shadow_color=(0, 0, 0, 0),
        torso_color=(0, 0, 0, 0),
        strap_color=(0, 0, 0, 0),
        pouch_color=(0, 0, 0, 0),
    )


def _load_arena_background() -> Image.Image:
    if ARENA_TEXTURE_PATH.exists():
        background = Image.open(ARENA_TEXTURE_PATH).convert("RGBA")
    else:
        background = Image.new("RGBA", ARENA_SIZE, (70, 84, 73, 255))

    draw = ImageDraw.Draw(background, "RGBA")
    draw.rectangle(PLAY_RECT, outline=BOUNDARY_COLOR, width=2)
    return background


def _paste_grounded_sprite(
    image: Image.Image, sprite_path: Path, feet_position: tuple[int, int]
) -> None:
    sprite = Image.open(sprite_path).convert("RGBA")
    top_left = (
        int(feet_position[0] - sprite.width // 2),
        int(feet_position[1] - sprite.height),
    )
    image.alpha_composite(sprite, top_left)


def _draw_candidate_blowgun(
    image: Image.Image,
    spec: ShooterPaletteVariantSpec,
    feet_position: tuple[int, int],
) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    sprite_top_left = (
        int(feet_position[0] - spec.canvas_width // 2),
        int(feet_position[1] - spec.canvas_height),
    )
    start_point = (
        sprite_top_left[0] + spec.blowgun_origin_x,
        sprite_top_left[1] + spec.blowgun_origin_y,
    )
    end_point = (
        start_point[0] + spec.blowgun_direction_x,
        start_point[1] + spec.blowgun_direction_y,
    )
    shaft_color = (132, 101, 58, 255)
    tip_color = (220, 206, 158, 255)
    draw.line(
        (start_point[0], start_point[1] + 1, end_point[0], end_point[1] + 1),
        fill=(0, 0, 0, 70),
        width=max(spec.blowgun_width, 1),
    )
    draw.line((start_point, end_point), fill=shaft_color, width=spec.blowgun_width)
    draw.line(((end_point[0] - 2, end_point[1]), end_point), fill=tip_color, width=max(spec.blowgun_width, 1))


def _draw_label(
    draw: ImageDraw.ImageDraw,
    position: tuple[int, int],
    text: str,
    font: ImageFont.ImageFont,
) -> None:
    draw.text((position[0] + 1, position[1] + 1), text, font=font, fill=LABEL_SHADOW_COLOR)
    draw.text(position, text, font=font, fill=LABEL_TEXT_COLOR)


def draw_standard_assets() -> None:
    draw_shielded_enemy(SPRITE_DIR / "shielded_enemy.png")
    draw_shooter_enemy(SPRITE_DIR / "shooter_enemy.png")
    draw_exploder_enemy(SPRITE_DIR / "exploder_enemy.png")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Spear Shot Phase 4 art assets.")
    parser.add_argument(
        "--generate-dev-shooter-concepts",
        action="store_true",
        help="Generate temporary Blowgun Shooter palette-variant outputs and comparison board.",
    )
    parser.add_argument(
        "--generate-dev-exploder-concepts",
        action="store_true",
        help="Generate temporary Exploder candidate outputs and comparison board.",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Generate both live assets and the temporary Shooter palette outputs.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.all or (not args.generate_dev_shooter_concepts and not args.generate_dev_exploder_concepts):
        draw_standard_assets()
    if args.all or args.generate_dev_shooter_concepts:
        generate_shooter_candidate_assets()
    if args.all or args.generate_dev_exploder_concepts:
        generate_exploder_candidate_assets()


if __name__ == "__main__":
    main()
