from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass, replace
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SPRITE_DIR = ROOT / "art" / "sprites"
DEV_SHOOTER_DIR = ROOT / "art" / "dev" / "shooter_candidates"
DEV_BOOMER_DIR = ROOT / "art" / "dev" / "boomer_candidates"
DEV_HEART_RUNNER_DIR = ROOT / "art" / "dev" / "heart_runner_candidates"
DEV_HEART_RUNNER_ANIMATION_DIR = ROOT / "art" / "dev" / "heart_runner_animation"
ARENA_TEXTURE_PATH = ROOT / "art" / "arena" / "arena_floor.png"
ARENA_SIZE = (384, 216)
PLAY_RECT = (16, 16, 368, 200)
BOUNDARY_COLOR = (204, 220, 190, 170)
LABEL_TEXT_COLOR = (239, 242, 230, 255)
LABEL_SHADOW_COLOR = (17, 20, 18, 220)
SHOOTER_CANVAS_SIZE = (16, 18)
BOOMER_CANVAS_SIZE = (16, 18)
HEART_RUNNER_CANVAS_SIZE = (16, 16)
HEART_PICKUP_CANVAS_SIZE = (10, 10)
HEART_RUNNER_ANIMATION_SHEET_ROWS = ["casual_strut", "startled_hop", "panicked_sprint"]
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
class BoomerVariantSpec:
    key: str
    title: str
    file_name: str
    palette_summary: str
    silhouette_summary: str
    body_color: tuple[int, int, int, int]
    sac_color: tuple[int, int, int, int]
    mark_color: tuple[int, int, int, int]
    eye_color: tuple[int, int, int, int]
    canvas_width: int = BOOMER_CANVAS_SIZE[0]
    canvas_height: int = BOOMER_CANVAS_SIZE[1]
    apparent_body_width: int = 0
    apparent_body_height: int = 0


@dataclass(frozen=True)
class HeartRunnerVariantSpec:
    key: str
    title: str
    file_name: str
    palette_summary: str
    silhouette_summary: str
    body_color: tuple[int, int, int, int]
    accent_color: tuple[int, int, int, int]
    eye_color: tuple[int, int, int, int]
    shadow_color: tuple[int, int, int, int]
    canvas_width: int = HEART_RUNNER_CANVAS_SIZE[0]
    canvas_height: int = HEART_RUNNER_CANVAS_SIZE[1]
    apparent_body_width: int = 0
    apparent_body_height: int = 0


def draw_boomer_enemy(path: Path) -> None:
    image = Image.new("RGBA", BOOMER_CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _draw_boomer_variant_silhouette(draw, build_boomer_variant_specs()[1])

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


def draw_heart_runner(path: Path) -> None:
    image = Image.new("RGBA", HEART_RUNNER_CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _draw_heart_runner_variant_silhouette(draw, build_heart_runner_variant_specs()[1])

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def draw_heart_pickup(path: Path) -> None:
    image = Image.new("RGBA", HEART_PICKUP_CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((2, 2, 7, 7), fill=(181, 62, 64, 255))
    draw.ellipse((3, 1, 6, 4), fill=(224, 146, 128, 255))
    draw.point((4, 4), fill=(255, 228, 190, 255))
    draw.line((4, 1, 5, 0), fill=(126, 152, 98, 255), width=1)
    draw.line((5, 0, 6, 1), fill=(167, 183, 124, 255), width=1)

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def draw_heart_runner_animation_sheet(path: Path) -> None:
    sequence_specs = build_heart_runner_animation_sequences()
    frame_width, frame_height = HEART_RUNNER_CANVAS_SIZE
    image = Image.new(
        "RGBA",
        (
            frame_width * sequence_specs["casual_strut"]["frame_count"],
            frame_height * len(HEART_RUNNER_ANIMATION_SHEET_ROWS),
        ),
        (0, 0, 0, 0),
    )

    for row_index, sequence_key in enumerate(HEART_RUNNER_ANIMATION_SHEET_ROWS):
        for frame_index in range(sequence_specs[sequence_key]["frame_count"]):
            frame_image = _render_heart_runner_animation_frame(sequence_key, frame_index)
            image.alpha_composite(
                frame_image,
                (frame_index * frame_width, row_index * frame_height),
            )

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def build_boomer_variant_specs() -> list[BoomerVariantSpec]:
    return [
        BoomerVariantSpec(
            key="1",
            title="Seed Pod",
            file_name="boomer_variant_1.png",
            palette_summary="dry bark body, ochre seed-pod sac, dark sap cracks",
            silhouette_summary="A squat hopper with a side-loaded seed pod bulge and stubby forward paws.",
            body_color=(112, 86, 61, 255),
            sac_color=(190, 153, 100, 255),
            mark_color=(79, 55, 38, 255),
            eye_color=(228, 214, 170, 255),
        ),
        BoomerVariantSpec(
            key="2",
            title="Throat Sac",
            file_name="boomer_variant_2.png",
            palette_summary="peat-brown body, pale stretched throat sac, dark root markings",
            silhouette_summary="A hunched frog-locust hopper with a swollen forward throat sac and clear crouched legs.",
            body_color=(96, 72, 54, 255),
            sac_color=(208, 177, 126, 255),
            mark_color=(69, 47, 36, 255),
            eye_color=(237, 224, 181, 255),
        ),
        BoomerVariantSpec(
            key="3",
            title="Resin Bladder",
            file_name="boomer_variant_3.png",
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


def build_heart_runner_variant_specs() -> list[HeartRunnerVariantSpec]:
    return [
        HeartRunnerVariantSpec(
            key="1",
            title="Seedling",
            file_name="heart_runner_variant_1.png",
            palette_summary="deep berry seed body, pale sprout accent, dark bark legs",
            silhouette_summary="Compact seed-creature with a forward lean, one visible sprout flick, and short quick legs.",
            body_color=(157, 54, 57, 255),
            accent_color=(232, 168, 138, 255),
            eye_color=(253, 236, 198, 255),
            shadow_color=(76, 40, 35, 255),
        ),
        HeartRunnerVariantSpec(
            key="2",
            title="Pulse Beast",
            file_name="heart_runner_variant_2.png",
            palette_summary="crimson core body, warm peach chest pulse, umber legs and back ridge",
            silhouette_summary="Tiny quick beast with a rounded pulse-sac torso, narrow head, and clear sprint posture.",
            body_color=(166, 60, 58, 255),
            accent_color=(235, 154, 122, 255),
            eye_color=(253, 241, 203, 255),
            shadow_color=(70, 38, 34, 255),
        ),
        HeartRunnerVariantSpec(
            key="3",
            title="Fruit Skitter",
            file_name="heart_runner_variant_3.png",
            palette_summary="muted cherry body, pale gold underside, root-brown feet and tail",
            silhouette_summary="Small fruit-bodied runner with a longer rear counterbalance and sharper nose.",
            body_color=(148, 63, 66, 255),
            accent_color=(225, 180, 128, 255),
            eye_color=(251, 238, 200, 255),
            shadow_color=(73, 45, 34, 255),
        ),
    ]


def draw_boomer_variant(spec: BoomerVariantSpec, path: Path) -> BoomerVariantSpec:
    image = Image.new("RGBA", (spec.canvas_width, spec.canvas_height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _draw_boomer_variant_silhouette(draw, spec)

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


def draw_heart_runner_variant(spec: HeartRunnerVariantSpec, path: Path) -> HeartRunnerVariantSpec:
    image = Image.new("RGBA", (spec.canvas_width, spec.canvas_height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _draw_heart_runner_variant_silhouette(draw, spec)

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)

    apparent_body_width, apparent_body_height = _measure_nontransparent_bounds(image)
    return replace(
        spec,
        apparent_body_width=apparent_body_width,
        apparent_body_height=apparent_body_height,
    )


def _draw_boomer_variant_silhouette(draw: ImageDraw.ImageDraw, spec: BoomerVariantSpec) -> None:
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


def _draw_heart_runner_variant_silhouette(draw: ImageDraw.ImageDraw, spec: HeartRunnerVariantSpec) -> None:
    if spec.key == "1":
        draw.ellipse((5, 6, 11, 11), fill=spec.body_color)
        draw.ellipse((8, 5, 12, 9), fill=spec.body_color)
        draw.ellipse((6, 7, 10, 10), fill=spec.accent_color)
        draw.line((8, 4, 9, 2), fill=spec.accent_color, width=1)
        draw.line((9, 2, 10, 3), fill=spec.accent_color, width=1)
        draw.point((10, 7), fill=spec.eye_color)
        draw.line((6, 11, 5, 14), fill=spec.shadow_color, width=1)
        draw.line((9, 11, 10, 14), fill=spec.shadow_color, width=1)
        draw.line((4, 9, 2, 10), fill=spec.shadow_color, width=1)
        return

    if spec.key == "2":
        draw.ellipse((5, 6, 11, 11), fill=spec.body_color)
        draw.ellipse((8, 5, 12, 8), fill=spec.body_color)
        draw.ellipse((6, 8, 10, 11), fill=spec.accent_color)
        draw.line((7, 5, 8, 4), fill=spec.shadow_color, width=1)
        draw.point((10, 7), fill=spec.eye_color)
        draw.point((9, 9), fill=spec.accent_color)
        draw.line((6, 11, 5, 14), fill=spec.shadow_color, width=1)
        draw.line((9, 11, 10, 14), fill=spec.shadow_color, width=1)
        draw.line((4, 9, 2, 8), fill=spec.shadow_color, width=1)
        draw.line((5, 8, 3, 6), fill=spec.shadow_color, width=1)
        return

    draw.ellipse((5, 6, 11, 11), fill=spec.body_color)
    draw.ellipse((8, 6, 11, 9), fill=spec.body_color)
    draw.ellipse((6, 8, 10, 10), fill=spec.accent_color)
    draw.point((10, 8), fill=spec.eye_color)
    draw.line((6, 11, 5, 14), fill=spec.shadow_color, width=1)
    draw.line((9, 11, 10, 14), fill=spec.shadow_color, width=1)
    draw.line((4, 9, 2, 11), fill=spec.shadow_color, width=1)
    draw.line((5, 7, 3, 5), fill=spec.shadow_color, width=1)
    draw.line((9, 6, 12, 4), fill=spec.shadow_color, width=1)


def _draw_heart_runner_animation_silhouette(
    draw: ImageDraw.ImageDraw,
    spec: HeartRunnerVariantSpec,
    sequence_key: str,
    frame_index: int,
) -> None:
    if sequence_key == "casual_strut":
        body_offsets = [(0, 0), (0, 1), (0, 0), (0, -1)]
        tail_offsets = [(-2, -1), (-2, 0), (-2, 1), (-2, 0)]
        leg_pairs = [
            [(6, 11), (5, 14), (9, 11), (10, 14)],
            [(6, 11), (4, 14), (9, 11), (9, 14)],
            [(6, 11), (5, 14), (9, 11), (10, 14)],
            [(6, 11), (6, 14), (9, 11), (11, 14)],
        ]
        _draw_heart_runner_frame(
            draw,
            spec,
            body_offsets[frame_index],
            tail_offsets[frame_index],
            leg_pairs[frame_index],
            False,
            False,
        )
        return

    if sequence_key == "panicked_sprint":
        body_offsets = [(0, 0), (1, -1), (2, -2), (1, 0)]
        head_offsets = [(1, -1), (2, -1), (3, -1), (2, 0)]
        accent_offsets = [(0, 0), (1, 0), (1, -1), (0, 0)]
        tail_offsets = [(-4, 0), (-4, 1), (-5, 2), (-4, 2)]
        leg_pairs = [
            [(6, 11), (4, 14), (9, 11), (12, 14)],
            [(7, 10), (4, 14), (10, 10), (13, 13)],
            [(8, 10), (6, 12), (10, 10), (12, 12)],
            [(7, 11), (5, 14), (10, 11), (13, 14)],
        ]
        _draw_heart_runner_frame(
            draw,
            spec,
            body_offsets[frame_index],
            tail_offsets[frame_index],
            leg_pairs[frame_index],
            True,
            False,
            head_offsets[frame_index],
            accent_offsets[frame_index],
        )
        return

    body_offsets = [(0, 1), (0, -2), (1, -3), (0, 0)]
    tail_offsets = [(-2, 0), (-2, -1), (-3, -1), (-2, 1)]
    leg_pairs = [
        [(6, 11), (5, 13), (9, 11), (10, 13)],
        [(6, 9), (5, 12), (9, 9), (10, 12)],
        [(7, 8), (6, 11), (10, 8), (11, 11)],
        [(6, 11), (5, 14), (9, 11), (11, 14)],
    ]
    _draw_heart_runner_frame(
        draw,
        spec,
        body_offsets[frame_index],
        tail_offsets[frame_index],
        leg_pairs[frame_index],
        True,
        True,
    )


def _draw_heart_runner_frame(
    draw: ImageDraw.ImageDraw,
    spec: HeartRunnerVariantSpec,
    body_offset: tuple[int, int],
    tail_offset: tuple[int, int],
    leg_points: list[tuple[int, int]],
    lean_forward: bool,
    startled_peak: bool,
    head_offset: tuple[int, int] = (0, 0),
    accent_offset: tuple[int, int] = (0, 0),
) -> None:
    body_left = 5 + body_offset[0]
    body_top = 6 + body_offset[1]
    head_left = 8 + body_offset[0] + (1 if lean_forward else 0) + head_offset[0]
    head_top = 5 + body_offset[1] + head_offset[1]
    accent_left = body_left + 1 + accent_offset[0]
    accent_top = 8 + body_offset[1] + accent_offset[1]

    draw.ellipse((body_left, body_top, body_left + 6, body_top + 5), fill=spec.body_color)
    draw.ellipse((head_left, head_top, head_left + 4, head_top + 3), fill=spec.body_color)
    draw.ellipse((accent_left, accent_top, accent_left + 4, accent_top + 3), fill=spec.accent_color)
    draw.point((head_left + 2, head_top + 2), fill=spec.eye_color)
    if startled_peak:
        draw.point((head_left + 3, head_top + 1), fill=spec.eye_color)
    else:
        draw.point((accent_left + 3, accent_top + 1), fill=spec.accent_color)

    draw.line((7 + body_offset[0], 5 + body_offset[1], 8 + body_offset[0], 4 + body_offset[1]), fill=spec.shadow_color, width=1)
    draw.line((4 + body_offset[0], 9 + body_offset[1], 2 + tail_offset[0], 8 + tail_offset[1] + body_offset[1]), fill=spec.shadow_color, width=1)
    draw.line((5 + body_offset[0], 8 + body_offset[1], 3 + tail_offset[0], 6 + tail_offset[1] + body_offset[1]), fill=spec.shadow_color, width=1)
    draw.line((leg_points[0][0], leg_points[0][1], leg_points[1][0], leg_points[1][1]), fill=spec.shadow_color, width=1)
    draw.line((leg_points[2][0], leg_points[2][1], leg_points[3][0], leg_points[3][1]), fill=spec.shadow_color, width=1)


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


def generate_boomer_candidate_assets() -> dict[str, object]:
    DEV_BOOMER_DIR.mkdir(parents=True, exist_ok=True)
    comparison_path = DEV_BOOMER_DIR / "boomer_comparison.png"
    manifest_path = DEV_BOOMER_DIR / "boomer_manifest.json"

    variant_specs: list[BoomerVariantSpec] = []
    manifest_candidates: list[dict[str, object]] = []

    for spec in build_boomer_variant_specs():
        variant_path = DEV_BOOMER_DIR / spec.file_name
        finalized_spec = draw_boomer_variant(spec, variant_path)
        variant_specs.append(finalized_spec)
        manifest_candidates.append({
            **asdict(finalized_spec),
            "path": str(variant_path),
        })

    draw_boomer_comparison(variant_specs, comparison_path)
    manifest = {
        "comparison_path": str(comparison_path),
        "active_reference_path": str(SPRITE_DIR / "boomer_enemy.png"),
        "candidates": manifest_candidates,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


def generate_heart_runner_candidate_assets() -> dict[str, object]:
    DEV_HEART_RUNNER_DIR.mkdir(parents=True, exist_ok=True)
    comparison_path = DEV_HEART_RUNNER_DIR / "heart_runner_comparison.png"
    manifest_path = DEV_HEART_RUNNER_DIR / "heart_runner_manifest.json"

    if not (SPRITE_DIR / "heart_pickup.png").exists():
        draw_heart_pickup(SPRITE_DIR / "heart_pickup.png")

    variant_specs: list[HeartRunnerVariantSpec] = []
    manifest_candidates: list[dict[str, object]] = []

    for spec in build_heart_runner_variant_specs():
        variant_path = DEV_HEART_RUNNER_DIR / spec.file_name
        finalized_spec = draw_heart_runner_variant(spec, variant_path)
        variant_specs.append(finalized_spec)
        manifest_candidates.append({
            **asdict(finalized_spec),
            "path": str(variant_path),
        })

    draw_heart_runner_comparison(variant_specs, comparison_path)
    manifest = {
        "comparison_path": str(comparison_path),
        "active_reference_path": str(SPRITE_DIR / "heart_runner.png"),
        "pickup_reference_path": str(SPRITE_DIR / "heart_pickup.png"),
        "candidates": manifest_candidates,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


def generate_heart_runner_animation_preview() -> dict[str, object]:
    DEV_HEART_RUNNER_ANIMATION_DIR.mkdir(parents=True, exist_ok=True)
    board_path = DEV_HEART_RUNNER_ANIMATION_DIR / "heart_runner_animation_board.png"
    manifest_path = DEV_HEART_RUNNER_ANIMATION_DIR / "heart_runner_animation_manifest.json"
    sequence_specs = build_heart_runner_animation_sequences()
    manifest_sequences: dict[str, object] = {}

    for sequence_key, sequence_spec in sequence_specs.items():
        frame_paths: list[str] = []
        for frame_index in range(sequence_spec["frame_count"]):
            frame_path = DEV_HEART_RUNNER_ANIMATION_DIR / (
                f"{sequence_key}_frame_{frame_index + 1}.png"
            )
            draw_heart_runner_animation_frame(sequence_key, frame_index, frame_path)
            frame_paths.append(str(frame_path))
        manifest_sequences[sequence_key] = {
            "title": sequence_spec["title"],
            "description": sequence_spec["description"],
            "timing_note": sequence_spec["timing_note"],
            "frame_paths": frame_paths,
        }

    draw_heart_runner_animation_board(sequence_specs, board_path)
    manifest = {
        "board_path": str(board_path),
        "active_reference_path": str(SPRITE_DIR / "heart_runner_sheet.png"),
        "base_reference_path": str(SPRITE_DIR / "heart_runner.png"),
        "sequence_count": len(sequence_specs),
        "sequences": manifest_sequences,
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


def draw_boomer_comparison(
    variant_specs: list[BoomerVariantSpec], comparison_path: Path
) -> None:
    background = _load_arena_background()
    draw = ImageDraw.Draw(background)
    font = ImageFont.load_default()

    _draw_label(draw, (8, 8), "Boomer Candidate Comparison", font)
    _draw_label(draw, (8, 20), "Small hopper scale against the live arena and current roster", font)

    benchmark_row = [
        ("Akedra", ROOT / "art" / "sprites" / "player_hunter.png", (48, 116)),
        ("Normal", ROOT / "art" / "sprites" / "enemy_creature.png", (116, 116)),
        ("Shielded", ROOT / "art" / "sprites" / "shielded_enemy.png", (184, 116)),
        ("Shooter", ROOT / "art" / "sprites" / "shooter_enemy.png", (252, 116)),
        ("Charger", ROOT / "art" / "sprites" / "charger_beast.png", (332, 116)),
    ]
    variant_row = [
        ("Variant 1", DEV_BOOMER_DIR / variant_specs[0].file_name, (96, 194)),
        ("Variant 2", DEV_BOOMER_DIR / variant_specs[1].file_name, (192, 194)),
        ("Variant 3", DEV_BOOMER_DIR / variant_specs[2].file_name, (288, 194)),
    ]

    for label, sprite_path, feet_position in benchmark_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        _draw_label(draw, (feet_position[0] - 16, feet_position[1] + 4), label, font)

    for label, sprite_path, feet_position in variant_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        _draw_label(draw, (feet_position[0] - 22, feet_position[1] + 4), label, font)

    comparison_path.parent.mkdir(parents=True, exist_ok=True)
    background.save(comparison_path)


def draw_heart_runner_comparison(
    variant_specs: list[HeartRunnerVariantSpec], comparison_path: Path
) -> None:
    background = _load_arena_background()
    draw = ImageDraw.Draw(background)
    font = ImageFont.load_default()

    _draw_label(draw, (8, 8), "Heart Runner Candidate Comparison", font)
    _draw_label(draw, (8, 20), "Small vitality-runner scale against the live arena and current roster", font)

    benchmark_row = [
        ("Akedra", ROOT / "art" / "sprites" / "player_hunter.png", (44, 116)),
        ("Normal", ROOT / "art" / "sprites" / "enemy_creature.png", (96, 116)),
        ("Shielded", ROOT / "art" / "sprites" / "shielded_enemy.png", (148, 116)),
        ("Shooter", ROOT / "art" / "sprites" / "shooter_enemy.png", (200, 116)),
        ("Boomer", ROOT / "art" / "sprites" / "boomer_enemy.png", (252, 116)),
        ("Charger", ROOT / "art" / "sprites" / "charger_beast.png", (316, 116)),
    ]
    variant_row = [
        ("Variant 1", DEV_HEART_RUNNER_DIR / variant_specs[0].file_name, (96, 194)),
        ("Variant 2", DEV_HEART_RUNNER_DIR / variant_specs[1].file_name, (192, 194)),
        ("Variant 3", DEV_HEART_RUNNER_DIR / variant_specs[2].file_name, (288, 194)),
    ]

    for label, sprite_path, feet_position in benchmark_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        _draw_label(draw, (feet_position[0] - 18, feet_position[1] + 4), label, font)

    for label, sprite_path, feet_position in variant_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        _draw_label(draw, (feet_position[0] - 22, feet_position[1] + 4), label, font)

    _paste_grounded_sprite(background, SPRITE_DIR / "heart_pickup.png", (344, 194))
    _draw_label(draw, (322, 198), "Pickup", font)

    comparison_path.parent.mkdir(parents=True, exist_ok=True)
    background.save(comparison_path)


def build_heart_runner_animation_sequences() -> dict[str, dict[str, object]]:
    return {
        "casual_strut": {
            "title": "Casual Strut",
            "description": "Confident strut with a slower bob.",
            "timing_note": "4-frame calm cadence for wandering and casual exit.",
            "frame_labels": ["plant", "reach", "plant", "reach"],
            "frame_count": 4,
        },
        "startled_hop": {
            "title": "Startled Hop",
            "description": "Recognize, pop, peak, then land/hold.",
            "timing_note": "4-frame 0.40s startle with a short landing beat.",
            "frame_labels": ["recognize", "pop", "peak", "land/hold"],
            "frame_count": 4,
        },
        "panicked_sprint": {
            "title": "Panicked Sprint",
            "description": "Hard lean, wide stride, near-airborne scramble.",
            "timing_note": "4-frame flee cadence with a more desperate silhouette.",
            "frame_labels": ["launch", "stretch", "airborne", "catch"],
            "frame_count": 4,
        },
    }


def draw_heart_runner_animation_frame(
    sequence_key: str,
    frame_index: int,
    path: Path,
) -> None:
    image = _render_heart_runner_animation_frame(sequence_key, frame_index)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def _render_heart_runner_animation_frame(
    sequence_key: str,
    frame_index: int,
) -> Image.Image:
    image = Image.new("RGBA", HEART_RUNNER_CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    spec = build_heart_runner_variant_specs()[1]
    _draw_heart_runner_animation_silhouette(draw, spec, sequence_key, frame_index)
    return image


def _scale_image_nearest_integer(
    image: Image.Image,
    scale_factor: int,
) -> Image.Image:
    if scale_factor <= 0:
        raise ValueError("scale_factor must be positive")

    scaled_size = (image.width * scale_factor, image.height * scale_factor)
    scaled_image = Image.new("RGBA", scaled_size, (0, 0, 0, 0))

    for y in range(image.height):
        for x in range(image.width):
            pixel = image.getpixel((x, y))
            if pixel[3] == 0:
                continue
            left = x * scale_factor
            top = y * scale_factor
            scaled_image.paste(
                pixel,
                (left, top, left + scale_factor, top + scale_factor),
            )

    return scaled_image


def draw_heart_runner_animation_board(
    sequence_specs: dict[str, dict[str, object]],
    board_path: Path,
) -> None:
    board = Image.new("RGBA", (768, 600), (25, 29, 26, 255))
    draw = ImageDraw.Draw(board, "RGBA")
    font = ImageFont.load_default()

    draw.rectangle((12, 12, 756, 588), outline=(93, 102, 91, 255), width=2)
    _draw_label(draw, (24, 20), "Heart Runner Animation Approval Gate", font)
    _draw_label(draw, (24, 34), "Current live sprite remains active; these are preview-only movement treatments.", font)
    _draw_label(draw, (24, 48), "Transition strip: calm -> startled hop -> landing beat -> panic sprint", font)

    current_image = Image.open(SPRITE_DIR / "heart_runner.png").convert("RGBA")
    board.alpha_composite(current_image, (40, 92))
    _draw_label(draw, (28, 72), "Current Base", font)
    current_zoom = _scale_image_nearest_integer(current_image, 4)
    board.alpha_composite(current_zoom, (28, 132))

    _draw_heart_runner_transition_strip(board, font)

    sequence_order = ["casual_strut", "startled_hop", "panicked_sprint"]
    native_row_y = {
        "casual_strut": 96,
        "startled_hop": 156,
        "panicked_sprint": 216,
    }
    zoom_row_y = {
        "casual_strut": 368,
        "startled_hop": 440,
        "panicked_sprint": 512,
    }

    for sequence_key in sequence_order:
        sequence_spec = sequence_specs[sequence_key]
        _draw_label(draw, (140, native_row_y[sequence_key] - 12), sequence_spec["title"], font)
        _draw_label(draw, (140, zoom_row_y[sequence_key] - 12), sequence_spec["timing_note"], font)
        _draw_label(draw, (500, zoom_row_y[sequence_key]), sequence_spec["description"], font)

        for frame_index in range(sequence_spec["frame_count"]):
            frame_path = DEV_HEART_RUNNER_ANIMATION_DIR / f"{sequence_key}_frame_{frame_index + 1}.png"
            frame_image = Image.open(frame_path).convert("RGBA")
            board.alpha_composite(frame_image, (300 + frame_index * 28, native_row_y[sequence_key]))
            zoom_image = _scale_image_nearest_integer(frame_image, 3)
            board.alpha_composite(zoom_image, (240 + frame_index * 62, zoom_row_y[sequence_key]))
            _draw_label(
                draw,
                (236 + frame_index * 62, zoom_row_y[sequence_key] + 52),
                sequence_spec["frame_labels"][frame_index],
                font,
            )

    board_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(board_path)


def _draw_heart_runner_transition_strip(
    board: Image.Image,
    font: ImageFont.ImageFont,
) -> None:
    draw = ImageDraw.Draw(board, "RGBA")
    sequence_specs = [
        ("casual_strut", 0, "calm"),
        ("startled_hop", 0, "startle"),
        ("startled_hop", 3, "land"),
        ("panicked_sprint", 1, "panic"),
    ]
    x_positions = [154, 260, 366, 472]
    y_position = 274
    for index, (sequence_key, frame_index, label) in enumerate(sequence_specs):
        frame_path = DEV_HEART_RUNNER_ANIMATION_DIR / f"{sequence_key}_frame_{frame_index + 1}.png"
        frame_image = _scale_image_nearest_integer(
            Image.open(frame_path).convert("RGBA"),
            3,
        )
        board.alpha_composite(frame_image, (x_positions[index], y_position))
        _draw_label(draw, (x_positions[index] - 6, y_position + 52), label, font)
        if index < len(sequence_specs) - 1:
            _draw_label(draw, (x_positions[index] + 54, y_position + 18), "->", font)


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
    draw_boomer_enemy(SPRITE_DIR / "boomer_enemy.png")
    draw_heart_runner(SPRITE_DIR / "heart_runner.png")
    draw_heart_runner_animation_sheet(SPRITE_DIR / "heart_runner_sheet.png")
    draw_heart_pickup(SPRITE_DIR / "heart_pickup.png")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Spear Shot Phase 4 art assets.")
    parser.add_argument(
        "--generate-dev-shooter-concepts",
        action="store_true",
        help="Generate temporary Blowgun Shooter palette-variant outputs and comparison board.",
    )
    parser.add_argument(
        "--generate-dev-boomer-concepts",
        action="store_true",
        help="Generate temporary Boomer candidate outputs and comparison board.",
    )
    parser.add_argument(
        "--generate-dev-heart-runner-concepts",
        action="store_true",
        help="Generate temporary Heart Runner candidate outputs and comparison board.",
    )
    parser.add_argument(
        "--generate-dev-heart-runner-animations",
        action="store_true",
        help="Generate temporary Heart Runner animation preview frames and approval board.",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Generate live assets plus the temporary Shooter, Boomer, Heart Runner concept, and Heart Runner animation outputs.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.all or (
        not args.generate_dev_shooter_concepts
        and not args.generate_dev_boomer_concepts
        and not args.generate_dev_heart_runner_concepts
    ):
        draw_standard_assets()
    if args.all or args.generate_dev_shooter_concepts:
        generate_shooter_candidate_assets()
    if args.all or args.generate_dev_boomer_concepts:
        generate_boomer_candidate_assets()
    if args.all or args.generate_dev_heart_runner_concepts:
        generate_heart_runner_candidate_assets()
    if args.all or args.generate_dev_heart_runner_animations:
        generate_heart_runner_animation_preview()


if __name__ == "__main__":
    main()
