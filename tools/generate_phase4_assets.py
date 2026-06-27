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
DEV_PROWLER_DIR = ROOT / "art" / "dev" / "prowler_candidates"
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
PROWLER_CANVAS_SIZE = (20, 18)
HEART_RUNNER_CANVAS_SIZE = (16, 16)
HEART_PICKUP_CANVAS_SIZE = (10, 10)
PROWLER_ANIMATION_SHEET_ROWS = ["stalk", "defensive", "alert", "hunt", "hunt_pounce", "recovery"]
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
class ProwlerVariantSpec:
    key: str
    title: str
    file_name: str
    palette_summary: str
    silhouette_summary: str
    signature_motif: str
    weakness_summary: str
    body_color: tuple[int, int, int, int]
    midtone_color: tuple[int, int, int, int]
    bone_color: tuple[int, int, int, int]
    eye_color: tuple[int, int, int, int]
    shadow_color: tuple[int, int, int, int]
    canvas_width: int = PROWLER_CANVAS_SIZE[0]
    canvas_height: int = PROWLER_CANVAS_SIZE[1]
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


def draw_prowler_enemy(path: Path) -> None:
    image = _render_selected_prowler_frame("stalk", 1)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def draw_prowler_animation_sheet(path: Path) -> None:
    frame_width, frame_height = PROWLER_CANVAS_SIZE
    image = Image.new(
        "RGBA",
        (frame_width * 4, frame_height * len(PROWLER_ANIMATION_SHEET_ROWS)),
        (0, 0, 0, 0),
    )

    for row_index, sequence_key in enumerate(PROWLER_ANIMATION_SHEET_ROWS):
        for frame_index in range(4):
            frame_image = _render_selected_prowler_frame(sequence_key, frame_index)
            image.alpha_composite(
                frame_image,
                (frame_index * frame_width, row_index * frame_height),
            )

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


def build_prowler_variant_specs() -> list[ProwlerVariantSpec]:
    return [
        ProwlerVariantSpec(
            key="1",
            title="Bonejaw Prowler",
            file_name="prowler_variant_1.png",
            palette_summary="peat-black hide, dry reed mane, pale hooked jaw plate, hot ember eye",
            silhouette_summary="Low shoulder wedge, heavy pale jaw hook, and the clearest stylized predator read without growing beyond the approved gameplay footprint.",
            signature_motif="Oversized hooked lower jaw plate that hangs below the snout like scavenged bone armor.",
            weakness_summary="Most readable overall, but it gives up some of Variant B's mane flair to keep the body mass compact and gameplay-legible.",
            body_color=(43, 40, 35, 255),
            midtone_color=(108, 101, 76, 255),
            bone_color=(214, 201, 164, 255),
            eye_color=(246, 70, 58, 255),
            shadow_color=(21, 20, 18, 255),
        ),
        ProwlerVariantSpec(
            key="2",
            title="Bristlemane Prowler",
            file_name="prowler_variant_2.png",
            palette_summary="charred bark hide, thorn-bristle mane, muted bone muzzle, blood-red hostile eye",
            silhouette_summary="A reed-backed skirmisher with the strongest mane profile and the roughest wild-dog outline of the three candidates.",
            signature_motif="Tall bristled mane ridge that makes the cautious crouch and aggressive lean easy to separate.",
            weakness_summary="The mane reads well, but the head becomes slightly more generic from a distance and the body risks blending into dark ground tiles.",
            body_color=(45, 39, 34, 255),
            midtone_color=(124, 111, 73, 255),
            bone_color=(192, 182, 146, 255),
            eye_color=(240, 68, 56, 255),
            shadow_color=(23, 19, 18, 255),
        ),
        ProwlerVariantSpec(
            key="3",
            title="Hollow Hound",
            file_name="prowler_variant_3.png",
            palette_summary="cold charcoal hide, hollow bone mask, dusty sage back plane, ember socket eye",
            silhouette_summary="A gaunter skull-faced tracker with the eeriest head read and the narrowest ribcage of the three.",
            signature_motif="Bone mask head with a hollow socket cut and tucked, almost carrion-bird neck posture.",
            weakness_summary="Memorable face silhouette, but it drifts a little too spectral compared with the grounded physicality of the selected live direction.",
            body_color=(49, 44, 40, 255),
            midtone_color=(89, 92, 74, 255),
            bone_color=(206, 193, 160, 255),
            eye_color=(236, 74, 60, 255),
            shadow_color=(20, 18, 19, 255),
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


def draw_prowler_variant(spec: ProwlerVariantSpec, path: Path) -> ProwlerVariantSpec:
    image = _render_prowler_candidate_pose(spec, "stalk")
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


def _draw_prowler_variant_silhouette(draw: ImageDraw.ImageDraw, spec: ProwlerVariantSpec) -> None:
    if spec.key == "1":
        _draw_grave_hound_preview(draw, spec, False)
        return
    if spec.key == "2":
        _draw_marsh_hound_preview(draw, spec, False)
        return
    _draw_crooked_prowler_preview(draw, spec, False)


def _render_prowler_animation_frame(
    sequence_key: str,
    frame_index: int,
) -> Image.Image:
    return _render_selected_prowler_frame(sequence_key, frame_index)


def _draw_prowler_animation_silhouette(
    draw: ImageDraw.ImageDraw,
    spec: ProwlerVariantSpec,
    sequence_key: str,
    frame_index: int,
) -> None:
    _draw_selected_marsh_hound_frame(draw, spec, sequence_key, frame_index)
    return

    red_eye = (232, 78, 74, 255)
    muzzle_color = spec.accent_color
    back_color = spec.body_color
    shadow_color = spec.shadow_color
    eye_color = spec.eye_color

    if sequence_key == "stalk":
        body_boxes = [
            (4, 8, 11, 12),
            (4, 7, 11, 11),
            (4, 8, 11, 12),
            (4, 7, 11, 11),
        ]
        head_polys = [
            [(8, 7), (11, 6), (13, 7), (13, 9), (10, 10), (8, 9)],
            [(8, 6), (11, 5), (13, 6), (13, 8), (10, 9), (8, 8)],
            [(8, 7), (11, 6), (13, 7), (13, 9), (10, 10), (8, 9)],
            [(8, 6), (11, 5), (13, 6), (13, 8), (10, 9), (8, 8)],
        ]
        tail_lines = [
            ((4, 9), (2, 8), (1, 9)),
            ((4, 8), (2, 7), (1, 8)),
            ((4, 9), (2, 10), (1, 9)),
            ((4, 8), (2, 9), (1, 8)),
        ]
        front_legs = [
            ((10, 12), (13, 13)),
            ((9, 11), (12, 13)),
            ((10, 12), (13, 12)),
            ((9, 11), (12, 12)),
        ]
        hind_legs = [
            ((5, 12), (4, 15), (8, 12), (9, 15)),
            ((5, 11), (4, 14), (8, 11), (9, 14)),
            ((5, 12), (4, 15), (8, 12), (9, 14)),
            ((5, 11), (4, 14), (8, 11), (9, 15)),
        ]
        body_box = body_boxes[frame_index]
        draw.ellipse(body_box, fill=back_color)
        draw.polygon(head_polys[frame_index], fill=back_color)
        draw.polygon(
            [
                (9, head_polys[frame_index][0][1]),
                (12, head_polys[frame_index][0][1]),
                (13, head_polys[frame_index][3][1]),
                (11, head_polys[frame_index][4][1]),
                (9, head_polys[frame_index][5][1]),
            ],
            fill=muzzle_color,
        )
        tail = tail_lines[frame_index]
        draw.line((tail[0][0], tail[0][1], tail[1][0], tail[1][1]), fill=shadow_color, width=1)
        draw.line((tail[1][0], tail[1][1], tail[2][0], tail[2][1]), fill=shadow_color, width=1)
        legs = hind_legs[frame_index]
        draw.line((legs[0][0], legs[0][1], legs[1][0], legs[1][1]), fill=shadow_color, width=1)
        draw.line((legs[2][0], legs[2][1], legs[3][0], legs[3][1]), fill=shadow_color, width=1)
        front_leg = front_legs[frame_index]
        draw.line((front_leg[0][0], front_leg[0][1], front_leg[1][0], front_leg[1][1]), fill=shadow_color, width=1)
        draw.point((11, 8 if frame_index % 2 == 0 else 7), fill=eye_color)
        draw.point((12, 8 if frame_index % 2 == 0 else 7), fill=eye_color)
        return

    if sequence_key == "alert":
        frame_settings = [
            {"body": (4, 8, 11, 12), "head_y": 7, "eye": eye_color, "jaw": False},
            {"body": (4, 7, 11, 11), "head_y": 6, "eye": eye_color, "jaw": False},
            {"body": (4, 7, 11, 11), "head_y": 6, "eye": red_eye, "jaw": True},
            {"body": (4, 8, 11, 12), "head_y": 7, "eye": red_eye, "jaw": True},
        ]
        setting = frame_settings[frame_index]
        draw.ellipse(setting["body"], fill=back_color)
        draw.polygon(
            [(8, setting["head_y"]), (11, setting["head_y"] - 1), (13, setting["head_y"]), (14, setting["head_y"] + 2), (10, setting["head_y"] + 3), (8, setting["head_y"] + 2)],
            fill=back_color,
        )
        draw.polygon(
            [(9, setting["head_y"]), (12, setting["head_y"]), (13, setting["head_y"] + 2), (11, setting["head_y"] + 3), (9, setting["head_y"] + 2)],
            fill=muzzle_color,
        )
        draw.line((4, 9, 2, 8), fill=shadow_color, width=1)
        draw.line((2, 8, 1, 9), fill=shadow_color, width=1)
        draw.line((5, setting["body"][3], 4, 15), fill=shadow_color, width=1)
        draw.line((8, setting["body"][3], 9, 15), fill=shadow_color, width=1)
        draw.line((10, setting["body"][3], 13, 13), fill=shadow_color, width=1)
        draw.point((11, setting["head_y"] + 1), fill=setting["eye"])
        draw.point((12, setting["head_y"] + 1), fill=setting["eye"])
        if setting["jaw"]:
            draw.line((10, setting["head_y"] + 3, 12, setting["head_y"] + 4), fill=shadow_color, width=1)
        return

    if sequence_key == "hunt":
        body_boxes = [
            (4, 8, 11, 12),
            (5, 7, 12, 11),
            (4, 8, 11, 12),
            (5, 7, 12, 11),
        ]
        head_polys = [
            [(8, 7), (11, 6), (13, 7), (14, 8), (11, 10), (8, 9)],
            [(9, 6), (12, 5), (14, 6), (15, 7), (12, 9), (9, 8)],
            [(8, 7), (11, 6), (13, 7), (14, 8), (11, 10), (8, 9)],
            [(9, 6), (12, 5), (14, 6), (15, 7), (12, 9), (9, 8)],
        ]
        tail_lines = [
            ((4, 9), (2, 9), (1, 10)),
            ((5, 8), (3, 8), (2, 9)),
            ((4, 9), (2, 8), (1, 9)),
            ((5, 8), (3, 7), (2, 8)),
        ]
        hind_legs = [
            ((5, 12), (4, 15), (8, 12), (9, 14)),
            ((6, 11), (4, 14), (9, 11), (10, 14)),
            ((5, 12), (4, 15), (8, 12), (9, 14)),
            ((6, 11), (5, 14), (9, 11), (11, 13)),
        ]
        front_legs = [
            ((10, 12), (13, 14)),
            ((11, 11), (14, 13)),
            ((10, 12), (13, 13)),
            ((11, 11), (14, 12)),
        ]
        body_box = body_boxes[frame_index]
        draw.ellipse(body_box, fill=back_color)
        draw.polygon(head_polys[frame_index], fill=back_color)
        draw.polygon(
            [
                (10, head_polys[frame_index][0][1]),
                (13, head_polys[frame_index][0][1]),
                (14, head_polys[frame_index][3][1]),
                (12, head_polys[frame_index][4][1]),
                (10, head_polys[frame_index][5][1]),
            ],
            fill=muzzle_color,
        )
        tail = tail_lines[frame_index]
        draw.line((tail[0][0], tail[0][1], tail[1][0], tail[1][1]), fill=shadow_color, width=1)
        draw.line((tail[1][0], tail[1][1], tail[2][0], tail[2][1]), fill=shadow_color, width=1)
        legs = hind_legs[frame_index]
        draw.line((legs[0][0], legs[0][1], legs[1][0], legs[1][1]), fill=shadow_color, width=1)
        draw.line((legs[2][0], legs[2][1], legs[3][0], legs[3][1]), fill=shadow_color, width=1)
        front_leg = front_legs[frame_index]
        draw.line((front_leg[0][0], front_leg[0][1], front_leg[1][0], front_leg[1][1]), fill=shadow_color, width=1)
        draw.point((12 if frame_index % 2 == 0 else 13, 8 if frame_index % 2 == 0 else 7), fill=red_eye)
        draw.point((13 if frame_index % 2 == 0 else 14, 8 if frame_index % 2 == 0 else 7), fill=red_eye)
        return

    if sequence_key == "pounce":
        if frame_index <= 1:
            crouch_y = 8 if frame_index == 0 else 7
            draw.ellipse((4, crouch_y, 11, crouch_y + 4), fill=back_color)
            draw.polygon([(8, crouch_y - 1), (11, crouch_y - 2), (13, crouch_y - 1), (14, crouch_y + 1), (10, crouch_y + 2), (8, crouch_y + 1)], fill=back_color)
            draw.polygon([(9, crouch_y - 1), (12, crouch_y - 1), (13, crouch_y + 1), (11, crouch_y + 2), (9, crouch_y + 1)], fill=muzzle_color)
            draw.line((4, crouch_y + 1, 2, crouch_y), fill=shadow_color, width=1)
            draw.line((2, crouch_y, 1, crouch_y + 1), fill=shadow_color, width=1)
            draw.line((5, crouch_y + 4, 4, 15), fill=shadow_color, width=1)
            draw.line((8, crouch_y + 4, 9, 15), fill=shadow_color, width=1)
            draw.line((10, crouch_y + 4, 13, 13), fill=shadow_color, width=1)
            draw.point((11, crouch_y), fill=red_eye)
            draw.point((12, crouch_y), fill=red_eye)
            return

        if frame_index == 2:
            draw.ellipse((5, 6, 11, 10), fill=back_color)
            draw.polygon([(9, 5), (12, 4), (14, 5), (15, 7), (12, 8), (9, 7)], fill=back_color)
            draw.polygon([(10, 5), (13, 5), (14, 7), (12, 8), (10, 7)], fill=muzzle_color)
            draw.line((5, 8, 3, 6), fill=shadow_color, width=1)
            draw.line((7, 10, 4, 13), fill=shadow_color, width=1)
            draw.line((9, 10, 12, 13), fill=shadow_color, width=1)
            draw.line((11, 9, 14, 11), fill=shadow_color, width=1)
            draw.point((12, 6), fill=red_eye)
            draw.point((13, 6), fill=red_eye)
            return

        draw.ellipse((6, 6, 12, 10), fill=back_color)
        draw.polygon([(10, 5), (13, 4), (15, 5), (15, 7), (13, 8), (10, 7)], fill=back_color)
        draw.polygon([(11, 5), (14, 5), (15, 7), (13, 8), (11, 7)], fill=muzzle_color)
        draw.line((6, 8, 4, 6), fill=shadow_color, width=1)
        draw.line((8, 10, 5, 13), fill=shadow_color, width=1)
        draw.line((10, 10, 13, 13), fill=shadow_color, width=1)
        draw.line((12, 9, 15, 10), fill=shadow_color, width=1)
        draw.point((13, 6), fill=red_eye)
        draw.point((14, 6), fill=red_eye)
        return

    recovery_frames = [
        {
            "body": (5, 9, 12, 13),
            "head": [(9, 8), (12, 7), (14, 8), (14, 10), (11, 11), (9, 10)],
            "tail": ((5, 10), (3, 11), (2, 12)),
            "eyes": red_eye,
        },
        {
            "body": (4, 9, 11, 13),
            "head": [(8, 8), (11, 7), (13, 8), (13, 10), (10, 11), (8, 10)],
            "tail": ((4, 10), (2, 10), (1, 11)),
            "eyes": red_eye,
        },
        {
            "body": (4, 10, 11, 13),
            "head": [(8, 9), (11, 8), (13, 9), (13, 10), (10, 11), (8, 10)],
            "tail": ((4, 10), (2, 9), (1, 10)),
            "eyes": eye_color,
        },
        {
            "body": (4, 8, 11, 12),
            "head": [(8, 7), (11, 6), (13, 7), (13, 9), (10, 10), (8, 9)],
            "tail": ((4, 9), (2, 8), (1, 9)),
            "eyes": eye_color,
        },
    ]
    frame = recovery_frames[frame_index]
    draw.ellipse(frame["body"], fill=back_color)
    draw.polygon(frame["head"], fill=back_color)
    draw.polygon(
        [
            (9, frame["head"][0][1]),
            (12, frame["head"][0][1]),
            (13, frame["head"][3][1]),
            (11, frame["head"][4][1]),
            (9, frame["head"][5][1]),
        ],
        fill=muzzle_color,
    )
    tail = frame["tail"]
    draw.line((tail[0][0], tail[0][1], tail[1][0], tail[1][1]), fill=shadow_color, width=1)
    draw.line((tail[1][0], tail[1][1], tail[2][0], tail[2][1]), fill=shadow_color, width=1)
    draw.line((5, frame["body"][3], 4, 15), fill=shadow_color, width=1)
    draw.line((8, frame["body"][3], 9, 15), fill=shadow_color, width=1)
    draw.line((10, frame["body"][3], 13, 13), fill=shadow_color, width=1)
    draw.point((11, frame["head"][0][1] + 1), fill=frame["eyes"])
    draw.point((12, frame["head"][0][1] + 1), fill=frame["eyes"])


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


def generate_prowler_candidate_assets() -> dict[str, object]:
    DEV_PROWLER_DIR.mkdir(parents=True, exist_ok=True)
    comparison_path = DEV_PROWLER_DIR / "prowler_comparison.png"
    behavior_board_path = DEV_PROWLER_DIR / "prowler_behavior_board.png"
    manifest_path = DEV_PROWLER_DIR / "prowler_manifest.json"

    variant_specs: list[ProwlerVariantSpec] = []
    manifest_candidates: list[dict[str, object]] = []

    for spec in build_prowler_variant_specs():
        variant_path = DEV_PROWLER_DIR / spec.file_name
        finalized_spec = draw_prowler_variant(spec, variant_path)
        variant_specs.append(finalized_spec)
        manifest_candidates.append({
            **asdict(finalized_spec),
            "path": str(variant_path),
        })

    draw_replacement_prowler_comparison(variant_specs, comparison_path)
    draw_replacement_prowler_behavior_board(behavior_board_path)
    manifest = {
        "comparison_path": str(comparison_path),
        "behavior_board_path": str(behavior_board_path),
        "active_reference_path": str(SPRITE_DIR / "prowler_enemy.png"),
        "active_sheet_path": str(SPRITE_DIR / "prowler_enemy_sheet.png"),
        "selected_concept": "Bonejaw Prowler",
        "signature_motif": "Hooked pale jaw plate under a low shoulder wedge, with a dry mane ridge that stays readable in both stalking and hunting poses.",
        "selected_reasons": [
            "keeps the prowler visually small while giving it a sharper, more authored identity than the generic marsh-hound pass",
            "the hooked jaw reads instantly at native scale and stays distinct from Charger, Boomer, Heart Runner, and Akedra's spear",
            "its low cautious crouch and forward hunting lean separate clearly without needing UI help or oversized effects",
            "the compact body still supports the approved defensive and hunting pounce frames without looking boss-sized",
        ],
        "rejected_weaknesses": {
            "Bristlemane Prowler": "Strong neck silhouette, but the heavier mane risks muddying the face read and makes the body feel more generic from a distance.",
            "Hollow Hound": "Memorable skull-mask head, but it leans too eerie and airy compared with the grounded physical combat roster.",
        },
        "frame_size": [PROWLER_CANVAS_SIZE[0], PROWLER_CANVAS_SIZE[1]],
        "sheet_layout": [4, len(PROWLER_ANIMATION_SHEET_ROWS)],
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


def draw_prowler_comparison(
    variant_specs: list[ProwlerVariantSpec], comparison_path: Path
) -> None:
    background = _load_arena_background()
    draw = ImageDraw.Draw(background)
    font = ImageFont.load_default()

    _draw_label(draw, (8, 8), "Prowler Candidate Comparison", font)
    _draw_label(draw, (8, 20), "Low stalking predator scale against the live arena and current roster", font)

    benchmark_row = [
        ("Akedra", ROOT / "art" / "sprites" / "player_hunter.png", (28, 116)),
        ("Normal", ROOT / "art" / "sprites" / "enemy_creature.png", (76, 116)),
        ("Shielded", ROOT / "art" / "sprites" / "shielded_enemy.png", (124, 116)),
        ("Shooter", ROOT / "art" / "sprites" / "shooter_enemy.png", (172, 116)),
        ("Boomer", ROOT / "art" / "sprites" / "boomer_enemy.png", (220, 116)),
        ("Runner", ROOT / "art" / "sprites" / "heart_runner.png", (268, 116)),
        ("Charger", ROOT / "art" / "sprites" / "charger_beast.png", (332, 116)),
    ]
    variant_row = [
        ("Variant 1", DEV_PROWLER_DIR / variant_specs[0].file_name, (96, 194)),
        ("Variant 2", DEV_PROWLER_DIR / variant_specs[1].file_name, (192, 194)),
        ("Variant 3", DEV_PROWLER_DIR / variant_specs[2].file_name, (288, 194)),
    ]

    for label, sprite_path, feet_position in benchmark_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        _draw_label(draw, (feet_position[0] - 16, feet_position[1] + 4), label, font)

    for label, sprite_path, feet_position in variant_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        _draw_label(draw, (feet_position[0] - 22, feet_position[1] + 4), label, font)

    comparison_path.parent.mkdir(parents=True, exist_ok=True)
    background.save(comparison_path)


def build_prowler_animation_sequences() -> dict[str, dict[str, object]]:
    return {
        "stalk": {
            "title": "Stalk",
            "description": "Low bone-jaw stalk with restrained footfalls while Akedra is armed.",
        },
        "defensive": {
            "title": "Defensive",
            "description": "Crouched defensive wind-up into the frightened pass-through launch.",
        },
        "alert": {
            "title": "Alert",
            "description": "Hostile jaw-snap and red-eye flare on the real HELD-to-unarmed change.",
        },
        "hunt": {
            "title": "Hunt",
            "description": "Forward-leaning aggressive chase with a faster, more predatory cadence.",
        },
        "hunt_pounce": {
            "title": "Hunt Pounce",
            "description": "Committed hunting wind-up, airborne leap, and impact/recoil handoff.",
        },
        "recovery": {
            "title": "Recovery",
            "description": "Miss skid, punishable stun, and the wary end of the failed lunge.",
        },
    }


def draw_prowler_behavior_board(board_path: Path) -> None:
    draw_replacement_prowler_behavior_board(board_path)


def _render_selected_prowler_frame(sequence_key: str, frame_index: int) -> Image.Image:
    image = Image.new("RGBA", PROWLER_CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _draw_selected_bonejaw_frame(draw, build_prowler_variant_specs()[0], sequence_key, frame_index)
    return image


def _render_prowler_candidate_pose(
    spec: ProwlerVariantSpec,
    pose_key: str,
) -> Image.Image:
    image = Image.new("RGBA", PROWLER_CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if spec.key == "1":
        var_frame_map = {
            "stalk": ("stalk", 1),
            "alert": ("alert", 2),
            "hunt": ("hunt", 1),
            "defensive": ("defensive", 2),
        }
        sequence_key, frame_index = var_frame_map.get(pose_key, ("stalk", 1))
        _draw_selected_bonejaw_frame(draw, spec, sequence_key, frame_index)
    elif spec.key == "2":
        _draw_bristlemane_preview(draw, spec, pose_key)
    else:
        _draw_hollow_hound_preview(draw, spec, pose_key)
    return image


def _offset_prowler_shape(
    shape: dict[str, object],
    ox: int,
    oy: int,
) -> dict[str, object]:
    offset_shape: dict[str, object] = {}
    for key, value in shape.items():
        if key == "hostile":
            offset_shape[key] = value
        elif key in {"body", "flank", "mane", "head", "head_mid", "jaw", "tail", "back", "eyes", "shadow_points"}:
            offset_shape[key] = [(point[0] + ox, point[1] + oy) for point in value]
        elif key in {"front", "hind", "spikes", "bone_marks"}:
            offset_shape[key] = [
                ((line[0][0] + ox, line[0][1] + oy), (line[1][0] + ox, line[1][1] + oy))
                for line in value
            ]
        else:
            offset_shape[key] = value
    return offset_shape


def _draw_prowler_pose_shape(
    draw: ImageDraw.ImageDraw,
    spec: ProwlerVariantSpec,
    shape: dict[str, object],
) -> None:
    hostile = bool(shape.get("hostile", False))
    tail = shape.get("tail", [])
    if len(tail) >= 2:
        draw.line(tail, fill=spec.shadow_color, width=1)
    for leg in shape.get("hind", []):
        draw.line(leg, fill=spec.shadow_color, width=1)
    for leg in shape.get("front", []):
        draw.line(leg, fill=spec.shadow_color, width=1)
    if shape.get("flank"):
        draw.polygon(shape["flank"], fill=spec.midtone_color)
    if shape.get("mane"):
        draw.polygon(shape["mane"], fill=spec.midtone_color)
    draw.polygon(shape["body"], fill=spec.body_color)
    if shape.get("head_mid"):
        draw.polygon(shape["head_mid"], fill=spec.midtone_color)
    draw.polygon(shape["head"], fill=spec.body_color)
    draw.polygon(shape["jaw"], fill=spec.bone_color)
    if shape.get("back"):
        draw.line(shape["back"], fill=spec.shadow_color, width=1)
    for spike in shape.get("spikes", []):
        draw.line(spike, fill=spec.midtone_color, width=1)
    for mark in shape.get("bone_marks", []):
        draw.line(mark, fill=spec.shadow_color, width=1)
    for point in shape.get("shadow_points", []):
        draw.point(point, fill=spec.shadow_color)
    eye_fill = spec.eye_color if hostile else spec.shadow_color
    for eye in shape.get("eyes", []):
        draw.point(eye, fill=eye_fill)
    if hostile and len(shape.get("eyes", [])) == 1:
        only_eye = shape["eyes"][0]
        draw.point((only_eye[0] + 1, only_eye[1]), fill=spec.eye_color)


def _draw_selected_bonejaw_frame(
    draw: ImageDraw.ImageDraw,
    spec: ProwlerVariantSpec,
    sequence_key: str,
    frame_index: int,
) -> None:
    pose_library: dict[str, dict[str, object]] = {
        "stalk_low": {
            "body": [(4, 10), (6, 7), (10, 6), (14, 7), (16, 8), (16, 10), (14, 11), (10, 12), (6, 12), (4, 11)],
            "flank": [(7, 10), (11, 9), (15, 9), (14, 11), (10, 13), (7, 12)],
            "mane": [(6, 7), (8, 5), (11, 5), (13, 6), (12, 7), (8, 7)],
            "head": [(14, 8), (17, 7), (18, 8), (17, 10), (14, 10)],
            "head_mid": [(14, 8), (16, 7), (17, 8), (16, 9), (14, 9)],
            "jaw": [(14, 9), (19, 9), (18, 11), (15, 12), (13, 11)],
            "front": [((11, 11), (12, 15)), ((13, 11), (14, 14))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (9, 15))],
            "tail": [(4, 10), (2, 9), (1, 10)],
            "back": [(6, 7), (10, 6), (14, 7)],
            "spikes": [((8, 5), (8, 4)), ((10, 5), (10, 4))],
            "bone_marks": [((16, 10), (17, 10)), ((15, 11), (17, 11))],
            "eyes": [(16, 8)],
            "hostile": False,
        },
        "stalk_step": {
            "body": [(4, 9), (6, 6), (10, 5), (14, 6), (16, 7), (16, 9), (14, 10), (10, 11), (6, 11), (4, 10)],
            "flank": [(7, 9), (11, 8), (15, 8), (14, 10), (10, 12), (7, 11)],
            "mane": [(6, 6), (8, 4), (11, 4), (13, 5), (12, 6), (8, 6)],
            "head": [(14, 7), (17, 6), (18, 7), (17, 9), (14, 9)],
            "head_mid": [(14, 7), (16, 6), (17, 7), (16, 8), (14, 8)],
            "jaw": [(14, 8), (19, 8), (18, 10), (15, 11), (13, 10)],
            "front": [((11, 10), (11, 15)), ((13, 10), (15, 13))],
            "hind": [((7, 11), (6, 14)), ((9, 11), (10, 15))],
            "tail": [(4, 9), (2, 8), (1, 9)],
            "back": [(6, 6), (10, 5), (14, 6)],
            "spikes": [((8, 4), (8, 3)), ((10, 4), (11, 3))],
            "bone_marks": [((16, 9), (17, 9)), ((15, 10), (17, 10))],
            "eyes": [(16, 7)],
            "hostile": False,
        },
        "defensive_crouch": {
            "body": [(4, 11), (6, 8), (10, 7), (13, 7), (15, 8), (15, 10), (13, 11), (9, 12), (5, 12), (3, 12)],
            "flank": [(6, 11), (10, 10), (14, 10), (13, 12), (9, 13), (5, 13)],
            "mane": [(6, 8), (8, 6), (11, 5), (12, 6), (11, 7), (8, 8)],
            "head": [(13, 8), (16, 7), (17, 8), (16, 10), (13, 10)],
            "head_mid": [(13, 8), (15, 7), (16, 8), (15, 9), (13, 9)],
            "jaw": [(13, 9), (18, 8), (19, 9), (18, 11), (14, 12)],
            "front": [((10, 11), (11, 15)), ((12, 11), (14, 14))],
            "hind": [((6, 12), (5, 15)), ((8, 12), (9, 15))],
            "tail": [(3, 12), (2, 11), (1, 12)],
            "back": [(6, 8), (10, 7), (14, 7)],
            "spikes": [((8, 6), (7, 5)), ((10, 5), (10, 4)), ((12, 6), (13, 5))],
            "bone_marks": [((15, 9), (17, 9)), ((14, 10), (17, 10))],
            "eyes": [(15, 8)],
            "hostile": False,
        },
        "defensive_launch": {
            "body": [(5, 10), (9, 8), (13, 8), (16, 8), (18, 9), (17, 10), (13, 11), (9, 11), (6, 11), (4, 11)],
            "flank": [(8, 10), (12, 9), (16, 9), (15, 11), (10, 12), (7, 11)],
            "mane": [(8, 8), (10, 6), (13, 6), (15, 7), (13, 8), (10, 8)],
            "head": [(16, 8), (18, 7), (19, 8), (18, 10), (16, 10)],
            "head_mid": [(16, 8), (17, 7), (18, 8), (17, 9), (16, 9)],
            "jaw": [(16, 9), (19, 9), (18, 11), (15, 12), (13, 11)],
            "front": [((13, 11), (16, 13)), ((16, 10), (18, 12))],
            "hind": [((8, 11), (7, 15)), ((10, 11), (12, 14))],
            "tail": [(4, 11), (2, 10), (1, 11)],
            "back": [(8, 8), (12, 7), (16, 8)],
            "spikes": [((10, 6), (10, 5)), ((12, 6), (13, 5))],
            "bone_marks": [((17, 9), (18, 9)), ((16, 10), (18, 10))],
            "eyes": [(17, 8)],
            "hostile": False,
        },
        "alert_snap": {
            "body": [(4, 10), (6, 7), (10, 6), (14, 7), (16, 8), (16, 10), (14, 11), (10, 12), (6, 12), (4, 11)],
            "flank": [(7, 10), (11, 9), (15, 9), (14, 11), (10, 13), (7, 12)],
            "mane": [(6, 7), (8, 4), (11, 4), (14, 6), (13, 7), (8, 7)],
            "head": [(14, 7), (17, 6), (18, 7), (17, 10), (14, 10)],
            "head_mid": [(14, 7), (16, 6), (17, 7), (16, 8), (14, 8)],
            "jaw": [(14, 8), (19, 8), (18, 11), (15, 12), (13, 10)],
            "front": [((11, 11), (12, 15)), ((13, 11), (14, 14))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (9, 15))],
            "tail": [(4, 10), (2, 11), (1, 10)],
            "back": [(6, 7), (10, 6), (14, 7)],
            "spikes": [((8, 4), (7, 3)), ((10, 4), (10, 3)), ((12, 5), (13, 4))],
            "bone_marks": [((16, 9), (18, 9)), ((15, 10), (17, 11))],
            "eyes": [(16, 7)],
            "hostile": True,
        },
        "alert_rear": {
            "body": [(4, 10), (6, 7), (10, 5), (14, 6), (16, 8), (16, 10), (14, 11), (10, 12), (6, 12), (4, 11)],
            "flank": [(7, 10), (11, 8), (15, 8), (14, 10), (10, 13), (7, 12)],
            "mane": [(6, 7), (8, 3), (11, 3), (14, 5), (13, 6), (8, 6)],
            "head": [(14, 6), (17, 5), (18, 6), (18, 9), (15, 9)],
            "head_mid": [(14, 6), (16, 5), (17, 6), (16, 7), (14, 7)],
            "jaw": [(15, 8), (19, 7), (19, 9), (17, 11), (14, 10)],
            "front": [((11, 11), (12, 15)), ((13, 10), (14, 14))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (10, 15))],
            "tail": [(4, 10), (2, 11), (1, 10)],
            "back": [(6, 7), (10, 5), (14, 6)],
            "spikes": [((8, 3), (7, 2)), ((10, 3), (10, 2)), ((12, 4), (13, 3))],
            "bone_marks": [((16, 8), (18, 8)), ((15, 9), (17, 10))],
            "eyes": [(16, 6)],
            "hostile": True,
        },
        "hunt_stride_a": {
            "body": [(4, 10), (7, 7), (11, 6), (15, 7), (17, 8), (17, 10), (14, 11), (10, 12), (6, 12), (4, 11)],
            "flank": [(8, 10), (12, 9), (16, 9), (15, 11), (10, 13), (7, 12)],
            "mane": [(7, 7), (9, 4), (12, 4), (15, 6), (13, 7), (9, 7)],
            "head": [(15, 7), (18, 6), (19, 7), (18, 9), (15, 9)],
            "head_mid": [(15, 7), (17, 6), (18, 7), (17, 8), (15, 8)],
            "jaw": [(15, 8), (19, 8), (18, 10), (15, 11), (13, 10)],
            "front": [((12, 11), (14, 15)), ((15, 10), (17, 14))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (10, 14))],
            "tail": [(4, 10), (2, 11), (1, 10)],
            "back": [(7, 7), (11, 6), (15, 7)],
            "spikes": [((9, 4), (8, 3)), ((11, 4), (11, 3)), ((13, 5), (14, 4))],
            "bone_marks": [((16, 8), (18, 8)), ((15, 9), (17, 10))],
            "eyes": [(17, 7)],
            "hostile": True,
        },
        "hunt_stride_b": {
            "body": [(4, 10), (7, 7), (11, 6), (15, 7), (17, 8), (17, 10), (14, 11), (10, 12), (6, 12), (4, 11)],
            "flank": [(8, 10), (12, 9), (16, 9), (15, 11), (10, 13), (7, 12)],
            "mane": [(7, 7), (9, 4), (12, 4), (15, 6), (13, 7), (9, 7)],
            "head": [(15, 7), (18, 6), (19, 7), (18, 9), (15, 9)],
            "head_mid": [(15, 7), (17, 6), (18, 7), (17, 8), (15, 8)],
            "jaw": [(15, 8), (19, 8), (18, 10), (15, 11), (13, 10)],
            "front": [((12, 11), (13, 14)), ((15, 10), (16, 15))],
            "hind": [((7, 12), (7, 15)), ((9, 12), (11, 14))],
            "tail": [(4, 10), (2, 11), (1, 10)],
            "back": [(7, 7), (11, 6), (15, 7)],
            "spikes": [((9, 4), (8, 3)), ((11, 4), (11, 3)), ((13, 5), (14, 4))],
            "bone_marks": [((16, 8), (18, 8)), ((15, 9), (17, 10))],
            "eyes": [(17, 7)],
            "hostile": True,
        },
        "hunt_windup": {
            "body": [(4, 11), (6, 8), (10, 7), (14, 7), (16, 8), (16, 10), (14, 11), (10, 12), (6, 12), (4, 12)],
            "flank": [(7, 11), (11, 10), (15, 10), (14, 12), (10, 13), (7, 12)],
            "mane": [(6, 8), (8, 5), (11, 5), (14, 6), (13, 7), (8, 7)],
            "head": [(14, 8), (17, 7), (18, 8), (17, 10), (14, 10)],
            "head_mid": [(14, 8), (16, 7), (17, 8), (16, 9), (14, 9)],
            "jaw": [(14, 9), (19, 8), (19, 10), (17, 12), (14, 11)],
            "front": [((11, 12), (13, 15)), ((14, 11), (16, 14))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (10, 15))],
            "tail": [(4, 12), (2, 11), (1, 12)],
            "back": [(6, 8), (10, 7), (14, 7)],
            "spikes": [((8, 5), (7, 4)), ((10, 5), (10, 4)), ((12, 5), (13, 4))],
            "bone_marks": [((16, 9), (18, 9)), ((15, 10), (17, 11))],
            "eyes": [(16, 8)],
            "hostile": True,
        },
        "hunt_leap": {
            "body": [(6, 10), (10, 7), (14, 7), (17, 8), (19, 8), (18, 9), (14, 10), (10, 10), (7, 10), (5, 11)],
            "flank": [(10, 10), (14, 9), (18, 9), (17, 11), (12, 11), (8, 11)],
            "mane": [(10, 7), (12, 4), (15, 4), (17, 6), (15, 7), (12, 7)],
            "head": [(17, 8), (19, 7), (19, 8), (19, 10), (17, 10)],
            "head_mid": [(17, 8), (18, 7), (19, 8), (18, 9), (17, 9)],
            "jaw": [(17, 9), (19, 9), (18, 11), (16, 12), (14, 11)],
            "front": [((14, 10), (17, 12)), ((17, 10), (19, 11))],
            "hind": [((10, 10), (9, 15)), ((12, 10), (14, 14))],
            "tail": [(5, 11), (3, 10), (2, 11)],
            "back": [(10, 7), (14, 7), (17, 8)],
            "spikes": [((12, 4), (11, 3)), ((14, 4), (14, 3)), ((16, 5), (17, 4))],
            "bone_marks": [((17, 9), (18, 9)), ((16, 10), (18, 10))],
            "eyes": [(18, 8)],
            "hostile": True,
        },
        "hunt_impact": {
            "body": [(8, 10), (12, 8), (16, 8), (18, 9), (18, 11), (15, 12), (11, 12), (8, 12), (6, 11)],
            "flank": [(10, 11), (14, 10), (18, 10), (17, 12), (12, 13), (8, 12)],
            "mane": [(12, 8), (14, 5), (17, 5), (18, 7), (16, 8), (14, 8)],
            "head": [(16, 9), (18, 8), (19, 9), (18, 11), (16, 11)],
            "head_mid": [(16, 9), (17, 8), (18, 9), (17, 10), (16, 10)],
            "jaw": [(16, 10), (19, 9), (18, 11), (15, 12), (13, 11)],
            "front": [((11, 12), (10, 15)), ((14, 11), (15, 15))],
            "hind": [((10, 12), (9, 15)), ((12, 12), (13, 15))],
            "tail": [(6, 11), (4, 10), (3, 11)],
            "back": [(12, 8), (16, 8), (18, 9)],
            "spikes": [((14, 5), (13, 4)), ((16, 5), (16, 4)), ((17, 6), (18, 5))],
            "bone_marks": [((17, 10), (18, 10)), ((16, 11), (17, 11))],
            "eyes": [(17, 9)],
            "hostile": True,
        },
        "hunt_recoil": {
            "body": [(7, 10), (10, 8), (14, 8), (17, 9), (17, 11), (14, 12), (10, 12), (7, 12), (5, 11)],
            "flank": [(9, 11), (13, 10), (17, 10), (16, 12), (11, 13), (8, 12)],
            "mane": [(10, 8), (12, 5), (15, 5), (17, 7), (15, 8), (12, 8)],
            "head": [(15, 9), (17, 8), (18, 9), (17, 11), (15, 11)],
            "head_mid": [(15, 9), (16, 8), (17, 9), (16, 10), (15, 10)],
            "jaw": [(15, 10), (18, 9), (17, 11), (14, 12), (12, 11)],
            "front": [((10, 12), (9, 15)), ((13, 11), (14, 15))],
            "hind": [((8, 12), (7, 15)), ((10, 12), (11, 15))],
            "tail": [(5, 11), (3, 12), (2, 11)],
            "back": [(10, 8), (14, 8), (17, 9)],
            "spikes": [((12, 5), (11, 4)), ((14, 5), (14, 4)), ((16, 6), (17, 5))],
            "bone_marks": [((16, 10), (17, 10)), ((15, 11), (16, 11))],
            "eyes": [(16, 9)],
            "hostile": True,
        },
        "recovery_skid": {
            "body": [(7, 11), (10, 9), (14, 9), (16, 10), (15, 12), (12, 13), (9, 13), (6, 12), (5, 12)],
            "flank": [(9, 12), (12, 11), (16, 11), (15, 13), (10, 14), (7, 13)],
            "mane": [(10, 9), (12, 7), (15, 7), (16, 8), (14, 9), (12, 9)],
            "head": [(14, 10), (17, 9), (18, 10), (17, 12), (14, 12)],
            "head_mid": [(14, 10), (16, 9), (17, 10), (16, 11), (14, 11)],
            "jaw": [(14, 11), (18, 10), (17, 12), (14, 13), (12, 12)],
            "front": [((9, 13), (8, 15)), ((12, 13), (13, 15))],
            "hind": [((7, 13), (6, 15)), ((9, 13), (10, 15))],
            "tail": [(5, 12), (3, 13), (2, 12)],
            "back": [(10, 9), (14, 9), (16, 10)],
            "spikes": [((12, 7), (11, 6)), ((14, 7), (14, 6))],
            "bone_marks": [((15, 11), (17, 11)), ((14, 12), (16, 12))],
            "eyes": [(16, 10)],
            "hostile": True,
        },
        "recovery_stun": {
            "body": [(6, 11), (9, 9), (13, 9), (15, 10), (15, 12), (12, 13), (9, 13), (6, 12), (4, 12)],
            "flank": [(8, 12), (12, 11), (15, 11), (14, 13), (10, 14), (7, 13)],
            "mane": [(9, 9), (11, 6), (14, 6), (15, 8), (13, 9), (11, 9)],
            "head": [(13, 10), (16, 9), (17, 10), (16, 12), (13, 12)],
            "head_mid": [(13, 10), (15, 9), (16, 10), (15, 11), (13, 11)],
            "jaw": [(13, 11), (17, 10), (16, 12), (13, 13), (11, 12)],
            "front": [((8, 13), (7, 15)), ((11, 13), (12, 15))],
            "hind": [((6, 13), (5, 15)), ((8, 13), (9, 15))],
            "tail": [(4, 12), (2, 13), (1, 12)],
            "back": [(9, 9), (13, 9), (15, 10)],
            "spikes": [((11, 6), (10, 5)), ((13, 6), (13, 5))],
            "bone_marks": [((14, 11), (16, 11)), ((13, 12), (15, 12))],
            "eyes": [(15, 10)],
            "hostile": True,
        },
    }

    frame_map = {
        "stalk": [("stalk_low", (0, 0)), ("stalk_step", (0, 0)), ("stalk_low", (0, 0)), ("stalk_step", (0, 0))],
        "defensive": [("defensive_crouch", (0, 0)), ("defensive_crouch", (0, 1)), ("defensive_launch", (1, 0)), ("defensive_launch", (2, 0))],
        "alert": [("alert_snap", (0, 0)), ("alert_snap", (0, -1)), ("alert_rear", (0, -1)), ("alert_rear", (0, -2))],
        "hunt": [("hunt_stride_a", (0, 0)), ("hunt_stride_b", (-1, 0)), ("hunt_stride_a", (0, 0)), ("hunt_stride_b", (-1, 0))],
        "hunt_pounce": [("hunt_windup", (0, 1)), ("hunt_leap", (0, 1)), ("hunt_impact", (2, 0)), ("hunt_recoil", (1, 0))],
        "recovery": [("recovery_skid", (1, 1)), ("recovery_skid", (0, 1)), ("recovery_stun", (0, 1)), ("recovery_stun", (0, 1))],
    }

    pose_name, offset = frame_map[sequence_key][frame_index]
    _draw_prowler_pose_shape(
        draw,
        spec,
        _offset_prowler_shape(pose_library[pose_name], offset[0], offset[1]),
    )


def _draw_bristlemane_preview(draw: ImageDraw.ImageDraw, spec: ProwlerVariantSpec, pose_key: str) -> None:
    pose_shapes = {
        "stalk": {
            "body": [(4, 10), (6, 7), (10, 6), (14, 7), (16, 8), (16, 10), (13, 11), (9, 12), (6, 12), (4, 11)],
            "flank": [(7, 10), (11, 9), (15, 9), (14, 11), (10, 13), (7, 12)],
            "mane": [(6, 7), (8, 4), (10, 3), (12, 4), (14, 6), (12, 7), (8, 7)],
            "head": [(14, 8), (17, 7), (18, 8), (17, 10), (14, 10)],
            "head_mid": [(14, 8), (16, 7), (17, 8), (16, 9), (14, 9)],
            "jaw": [(14, 9), (18, 9), (17, 11), (14, 12), (12, 11)],
            "front": [((11, 11), (12, 15)), ((13, 11), (14, 14))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (10, 15))],
            "tail": [(4, 10), (2, 9), (1, 10)],
            "back": [(6, 7), (10, 6), (14, 7)],
            "spikes": [((8, 4), (7, 3)), ((10, 3), (10, 2)), ((12, 4), (13, 3)), ((14, 6), (15, 5))],
            "bone_marks": [((15, 10), (17, 10))],
            "eyes": [(16, 8)],
            "hostile": False,
        },
        "alert": {
            "body": [(4, 10), (6, 7), (10, 5), (14, 6), (16, 8), (16, 10), (13, 11), (9, 12), (6, 12), (4, 11)],
            "flank": [(7, 10), (11, 8), (15, 8), (14, 10), (10, 13), (7, 12)],
            "mane": [(6, 7), (8, 3), (10, 2), (12, 3), (15, 5), (13, 6), (8, 6)],
            "head": [(14, 7), (17, 6), (18, 7), (17, 10), (14, 10)],
            "head_mid": [(14, 7), (16, 6), (17, 7), (16, 8), (14, 8)],
            "jaw": [(14, 8), (18, 8), (18, 10), (16, 12), (13, 10)],
            "front": [((11, 11), (12, 15)), ((13, 10), (14, 14))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (10, 15))],
            "tail": [(4, 10), (2, 11), (1, 10)],
            "back": [(6, 7), (10, 5), (14, 6)],
            "spikes": [((8, 3), (7, 2)), ((10, 2), (10, 1)), ((12, 3), (13, 2)), ((14, 5), (15, 4))],
            "bone_marks": [((15, 9), (17, 9)), ((14, 10), (16, 11))],
            "eyes": [(16, 7)],
            "hostile": True,
        },
        "hunt": {
            "body": [(4, 10), (7, 7), (11, 6), (15, 7), (17, 8), (17, 10), (14, 11), (10, 12), (6, 12), (4, 11)],
            "flank": [(8, 10), (12, 9), (16, 9), (15, 11), (10, 13), (7, 12)],
            "mane": [(7, 7), (9, 3), (11, 2), (13, 3), (16, 5), (14, 7), (9, 7)],
            "head": [(15, 7), (18, 6), (19, 7), (18, 9), (15, 9)],
            "head_mid": [(15, 7), (17, 6), (18, 7), (17, 8), (15, 8)],
            "jaw": [(15, 8), (19, 8), (18, 10), (15, 11), (13, 10)],
            "front": [((12, 11), (14, 15)), ((15, 10), (17, 14))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (10, 14))],
            "tail": [(4, 10), (2, 11), (1, 10)],
            "back": [(7, 7), (11, 6), (15, 7)],
            "spikes": [((9, 3), (8, 2)), ((11, 2), (11, 1)), ((13, 3), (14, 2)), ((15, 5), (16, 4))],
            "bone_marks": [((16, 8), (18, 8)), ((15, 9), (17, 10))],
            "eyes": [(17, 7)],
            "hostile": True,
        },
        "defensive": {
            "body": [(5, 10), (7, 8), (11, 7), (14, 7), (16, 8), (16, 10), (13, 11), (9, 12), (6, 12), (4, 11)],
            "flank": [(8, 10), (12, 9), (15, 9), (14, 11), (10, 13), (7, 12)],
            "mane": [(7, 8), (9, 4), (11, 3), (13, 4), (15, 6), (13, 7), (9, 7)],
            "head": [(14, 8), (17, 7), (18, 8), (17, 10), (14, 10)],
            "head_mid": [(14, 8), (16, 7), (17, 8), (16, 9), (14, 9)],
            "jaw": [(14, 9), (18, 8), (19, 9), (18, 11), (15, 12)],
            "front": [((12, 11), (15, 13)), ((15, 10), (17, 12))],
            "hind": [((8, 12), (7, 15)), ((10, 12), (12, 14))],
            "tail": [(4, 11), (2, 10), (1, 11)],
            "back": [(7, 8), (11, 7), (15, 7)],
            "spikes": [((9, 4), (8, 3)), ((11, 3), (11, 2)), ((13, 4), (14, 3)), ((15, 6), (16, 5))],
            "bone_marks": [((15, 9), (17, 9)), ((14, 10), (17, 10))],
            "eyes": [(16, 8)],
            "hostile": False,
        },
    }
    _draw_prowler_pose_shape(draw, spec, pose_shapes.get(pose_key, pose_shapes["stalk"]))


def _draw_hollow_hound_preview(draw: ImageDraw.ImageDraw, spec: ProwlerVariantSpec, pose_key: str) -> None:
    pose_shapes = {
        "stalk": {
            "body": [(5, 10), (7, 7), (10, 6), (13, 7), (15, 8), (15, 10), (13, 11), (9, 12), (6, 12), (4, 11)],
            "flank": [(7, 10), (10, 9), (14, 9), (13, 11), (9, 13), (6, 12)],
            "mane": [(7, 7), (9, 5), (11, 5), (13, 6), (12, 7), (9, 7)],
            "head": [(13, 8), (16, 7), (17, 8), (16, 10), (13, 10)],
            "head_mid": [(13, 8), (15, 7), (16, 8), (15, 9), (13, 9)],
            "jaw": [(13, 9), (18, 9), (17, 11), (14, 12), (12, 11)],
            "front": [((10, 11), (11, 15)), ((12, 11), (13, 14))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (10, 15))],
            "tail": [(4, 11), (2, 10), (1, 11)],
            "back": [(7, 7), (10, 6), (13, 7)],
            "spikes": [((9, 5), (8, 4)), ((11, 5), (11, 4))],
            "bone_marks": [((14, 9), (16, 10)), ((15, 8), (15, 8))],
            "shadow_points": [(15, 8)],
            "eyes": [(16, 8)],
            "hostile": False,
        },
        "alert": {
            "body": [(5, 10), (7, 7), (10, 5), (13, 6), (15, 8), (15, 10), (13, 11), (9, 12), (6, 12), (4, 11)],
            "flank": [(7, 10), (10, 8), (14, 8), (13, 10), (9, 13), (6, 12)],
            "mane": [(7, 7), (9, 4), (11, 4), (13, 5), (12, 6), (9, 6)],
            "head": [(13, 7), (16, 6), (17, 7), (16, 10), (13, 10)],
            "head_mid": [(13, 7), (15, 6), (16, 7), (15, 8), (13, 8)],
            "jaw": [(13, 8), (18, 8), (17, 11), (14, 12), (12, 10)],
            "front": [((10, 11), (11, 15)), ((12, 10), (13, 14))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (10, 15))],
            "tail": [(4, 11), (2, 12), (1, 11)],
            "back": [(7, 7), (10, 5), (13, 6)],
            "spikes": [((9, 4), (8, 3)), ((11, 4), (11, 3))],
            "bone_marks": [((14, 8), (16, 9)), ((15, 7), (15, 7))],
            "shadow_points": [(15, 7)],
            "eyes": [(16, 7)],
            "hostile": True,
        },
        "hunt": {
            "body": [(5, 10), (8, 7), (11, 6), (14, 7), (16, 8), (16, 10), (13, 11), (9, 12), (6, 12), (4, 11)],
            "flank": [(8, 10), (11, 9), (15, 9), (14, 11), (10, 13), (7, 12)],
            "mane": [(8, 7), (10, 4), (12, 4), (14, 5), (13, 6), (10, 6)],
            "head": [(14, 7), (17, 6), (18, 7), (17, 9), (14, 9)],
            "head_mid": [(14, 7), (16, 6), (17, 7), (16, 8), (14, 8)],
            "jaw": [(14, 8), (19, 8), (18, 10), (15, 11), (13, 10)],
            "front": [((11, 11), (13, 15)), ((14, 10), (16, 14))],
            "hind": [((8, 12), (7, 15)), ((10, 12), (11, 14))],
            "tail": [(4, 11), (2, 12), (1, 11)],
            "back": [(8, 7), (11, 6), (14, 7)],
            "spikes": [((10, 4), (9, 3)), ((12, 4), (12, 3))],
            "bone_marks": [((15, 8), (17, 9)), ((15, 7), (15, 7))],
            "shadow_points": [(15, 7)],
            "eyes": [(17, 7)],
            "hostile": True,
        },
        "defensive": {
            "body": [(5, 10), (7, 8), (10, 7), (13, 7), (15, 8), (15, 10), (13, 11), (9, 12), (6, 12), (4, 11)],
            "flank": [(7, 10), (10, 9), (14, 9), (13, 11), (9, 13), (6, 12)],
            "mane": [(7, 8), (9, 5), (11, 5), (13, 6), (12, 7), (9, 7)],
            "head": [(13, 8), (16, 7), (17, 8), (16, 10), (13, 10)],
            "head_mid": [(13, 8), (15, 7), (16, 8), (15, 9), (13, 9)],
            "jaw": [(13, 9), (18, 8), (18, 10), (15, 12), (13, 11)],
            "front": [((11, 11), (14, 13)), ((14, 10), (16, 12))],
            "hind": [((7, 12), (6, 15)), ((9, 12), (11, 14))],
            "tail": [(4, 11), (2, 10), (1, 11)],
            "back": [(7, 8), (10, 7), (13, 7)],
            "spikes": [((9, 5), (8, 4)), ((11, 5), (11, 4))],
            "bone_marks": [((14, 9), (16, 10)), ((15, 8), (15, 8))],
            "shadow_points": [(15, 8)],
            "eyes": [(16, 8)],
            "hostile": False,
        },
    }
    _draw_prowler_pose_shape(draw, spec, pose_shapes.get(pose_key, pose_shapes["stalk"]))


def _draw_grave_hound_preview(draw: ImageDraw.ImageDraw, spec: ProwlerVariantSpec, hostile: bool) -> None:
    shoulder = [(5, 8), (7, 6), (11, 5), (13, 7), (13, 9), (10, 11), (6, 10)]
    rib = [(7, 9), (11, 8), (15, 9), (14, 11), (10, 12), (7, 11)]
    head = [(13, 8), (17, 7), (18, 8), (17, 10), (14, 10)]
    jaw = [(14, 9), (18, 9), (17, 11), (14, 11)]
    front_legs = [((11, 11), (12, 15)), ((13, 10), (15, 14))]
    hind_legs = [((7, 10), (6, 15)), ((9, 11), (10, 15))]
    tail = [(5, 9), (3, 8), (2, 9)]
    back_line = [(7, 6), (10, 5), (13, 7)]
    eye_positions = [(15, 8)]
    if hostile:
        shoulder = [(4, 9), (7, 7), (12, 6), (15, 8), (15, 10), (11, 11), (6, 11)]
        rib = [(7, 10), (12, 9), (16, 10), (15, 12), (10, 13), (6, 12)]
        head = [(15, 8), (18, 7), (19, 8), (18, 10), (15, 10)]
        jaw = [(16, 9), (19, 9), (18, 11), (15, 11)]
        front_legs = [((12, 11), (14, 15)), ((15, 10), (17, 13))]
        hind_legs = [((7, 11), (6, 15)), ((10, 11), (11, 15))]
        tail = [(4, 10), (2, 11), (1, 10)]
        back_line = [(7, 7), (12, 6), (15, 8)]
        eye_positions = [(16, 8)]
    _draw_prowler_pose_parts(draw, spec, shoulder, rib, head, jaw, front_legs, hind_legs, tail, hostile, eye_positions, back_line)


def _draw_marsh_hound_preview(draw: ImageDraw.ImageDraw, spec: ProwlerVariantSpec, hostile: bool) -> None:
    shoulder = [(4, 9), (7, 6), (12, 6), (15, 8), (15, 10), (12, 11), (7, 11), (4, 10)]
    rib = [(7, 10), (12, 10), (16, 11), (15, 13), (10, 13), (7, 12)]
    head = [(15, 10), (18, 9), (19, 10), (18, 11), (15, 11)]
    jaw = [(16, 11), (19, 10), (18, 12), (15, 12)]
    front_legs = [((11, 11), (12, 15)), ((13, 11), (14, 15))]
    hind_legs = [((7, 12), (6, 15)), ((9, 12), (9, 15))]
    tail = [(4, 10), (2, 9), (1, 10)]
    back_line = [(6, 7), (11, 6), (15, 8)]
    eye_positions = [(16, 10)]
    if hostile:
        shoulder = [(4, 9), (8, 6), (13, 6), (16, 8), (16, 10), (13, 11), (8, 11), (4, 10)]
        rib = [(8, 10), (13, 10), (17, 11), (16, 13), (11, 13), (8, 12)]
        head = [(16, 9), (19, 8), (19, 9), (19, 11), (16, 11)]
        jaw = [(16, 11), (19, 10), (18, 12), (15, 12)]
        front_legs = [((12, 11), (14, 15)), ((15, 10), (17, 14))]
        hind_legs = [((8, 12), (7, 15)), ((10, 12), (10, 15))]
        tail = [(4, 10), (2, 11), (1, 10)]
        back_line = [(7, 7), (12, 6), (16, 8)]
        eye_positions = [(17, 9)]
    _draw_prowler_pose_parts(draw, spec, shoulder, rib, head, jaw, front_legs, hind_legs, tail, hostile, eye_positions, back_line)


def _draw_crooked_prowler_preview(draw: ImageDraw.ImageDraw, spec: ProwlerVariantSpec, hostile: bool) -> None:
    shoulder = [(5, 9), (7, 6), (11, 6), (13, 7), (12, 9), (10, 11), (6, 11)]
    rib = [(7, 10), (11, 9), (14, 10), (13, 12), (9, 13), (6, 12)]
    head = [(13, 9), (16, 8), (17, 9), (16, 11), (13, 10)]
    jaw = [(14, 10), (17, 9), (16, 12), (13, 11)]
    front_legs = [((10, 11), (11, 15)), ((12, 10), (14, 14))]
    hind_legs = [((7, 12), (6, 15)), ((9, 12), (9, 15))]
    tail = [(5, 10), (3, 11), (2, 10)]
    back_line = [(6, 7), (8, 5), (12, 7)]
    eye_positions = [(15, 10)]
    if hostile:
        shoulder = [(5, 10), (8, 7), (12, 6), (14, 8), (13, 10), (11, 12), (7, 12)]
        rib = [(8, 11), (12, 10), (16, 11), (15, 13), (10, 14), (7, 13)]
        head = [(15, 9), (18, 8), (19, 9), (18, 11), (15, 11)]
        jaw = [(16, 10), (19, 9), (18, 12), (15, 12)]
        front_legs = [((11, 12), (12, 15)), ((14, 11), (16, 14))]
        hind_legs = [((8, 13), (7, 15)), ((10, 13), (10, 15))]
        tail = [(5, 11), (3, 12), (2, 11)]
        back_line = [(7, 8), (10, 6), (14, 8)]
        eye_positions = [(16, 9)]
    _draw_prowler_pose_parts(draw, spec, shoulder, rib, head, jaw, front_legs, hind_legs, tail, hostile, eye_positions, back_line)


def _draw_prowler_pose_parts(
    draw: ImageDraw.ImageDraw,
    spec: ProwlerVariantSpec,
    shoulder: list[tuple[int, int]],
    rib: list[tuple[int, int]],
    head: list[tuple[int, int]],
    jaw: list[tuple[int, int]],
    front_legs: list[tuple[tuple[int, int], tuple[int, int]]],
    hind_legs: list[tuple[tuple[int, int], tuple[int, int]]],
    tail: list[tuple[int, int]],
    hostile: bool,
    eye_positions: list[tuple[int, int]],
    back_line: list[tuple[int, int]],
) -> None:
    draw.line(tail, fill=spec.shadow_color, width=1)
    for leg in hind_legs:
        draw.line(leg, fill=spec.shadow_color, width=1)
    for leg in front_legs:
        draw.line(leg, fill=spec.shadow_color, width=1)
    draw.polygon(rib, fill=spec.midtone_color)
    draw.polygon(shoulder, fill=spec.body_color)
    draw.polygon(head, fill=spec.body_color)
    draw.polygon(jaw, fill=spec.bone_color)
    draw.line(back_line, fill=spec.shadow_color, width=1)
    eye_fill = spec.eye_color if hostile else spec.shadow_color
    for eye in eye_positions:
        draw.point(eye, fill=eye_fill)
    if hostile and len(eye_positions) == 1:
        draw.point((eye_positions[0][0] + 1, eye_positions[0][1]), fill=spec.eye_color)


def _draw_selected_marsh_hound_frame(
    draw: ImageDraw.ImageDraw,
    spec: ProwlerVariantSpec,
    sequence_key: str,
    frame_index: int,
) -> None:
    frame_map = {
        "stalk": [
            ("armed", (0, 0)),
            ("armed", (0, -1)),
            ("armed", (0, 0)),
            ("armed", (0, -1)),
        ],
        "defensive": [
            ("defensive_1", (0, 0)),
            ("defensive_2", (0, 1)),
            ("defensive_3", (1, 0)),
            ("defensive_4", (2, 0)),
        ],
        "alert": [
            ("alert_1", (0, 0)),
            ("alert_2", (0, -1)),
            ("alert_3", (0, -1)),
            ("alert_4", (0, -2)),
        ],
        "hunt": [
            ("hostile", (0, 0)),
            ("hostile", (-1, 0)),
            ("hostile", (0, 0)),
            ("hostile", (-1, 0)),
        ],
        "hunt_pounce": [
            ("hunt_pounce_1", (0, 1)),
            ("hunt_pounce_2", (0, 1)),
            ("hunt_pounce_3", (2, 0)),
            ("hunt_pounce_4", (1, 0)),
        ],
        "recovery": [
            ("recovery_1", (1, 1)),
            ("recovery_2", (0, 1)),
            ("recovery_3", (0, 1)),
            ("recovery_4", (0, 1)),
        ],
    }
    pose_key, offset = frame_map[sequence_key][frame_index]
    _draw_selected_marsh_hound_pose(draw, spec, pose_key, offset)


def _draw_selected_marsh_hound_pose(
    draw: ImageDraw.ImageDraw,
    spec: ProwlerVariantSpec,
    pose_key: str,
    offset: tuple[int, int],
) -> None:
    hostile = pose_key != "armed"
    ox, oy = offset

    pose_shapes = {
        "armed": {
            "shoulder": [(4 + ox, 9 + oy), (7 + ox, 6 + oy), (12 + ox, 6 + oy), (15 + ox, 8 + oy), (15 + ox, 10 + oy), (12 + ox, 11 + oy), (7 + ox, 11 + oy), (4 + ox, 10 + oy)],
            "rib": [(7 + ox, 10 + oy), (12 + ox, 10 + oy), (16 + ox, 11 + oy), (15 + ox, 13 + oy), (10 + ox, 13 + oy), (7 + ox, 12 + oy)],
            "head": [(15 + ox, 10 + oy), (18 + ox, 9 + oy), (19 + ox, 10 + oy), (18 + ox, 11 + oy), (15 + ox, 11 + oy)],
            "jaw": [(16 + ox, 11 + oy), (19 + ox, 10 + oy), (18 + ox, 12 + oy), (15 + ox, 12 + oy)],
            "front": [((11 + ox, 11 + oy), (12 + ox, 15 + oy)), ((13 + ox, 11 + oy), (14 + ox, 15 + oy))],
            "hind": [((7 + ox, 12 + oy), (6 + ox, 15 + oy)), ((9 + ox, 12 + oy), (9 + ox, 15 + oy))],
            "tail": [(4 + ox, 10 + oy), (2 + ox, 9 + oy), (1 + ox, 10 + oy)],
            "back": [(6 + ox, 7 + oy), (11 + ox, 6 + oy), (15 + ox, 8 + oy)],
            "eyes": [(16 + ox, 10 + oy)],
        },
        "hostile": {
            "shoulder": [(4 + ox, 9 + oy), (8 + ox, 6 + oy), (13 + ox, 6 + oy), (16 + ox, 8 + oy), (16 + ox, 10 + oy), (13 + ox, 11 + oy), (8 + ox, 11 + oy), (4 + ox, 10 + oy)],
            "rib": [(8 + ox, 10 + oy), (13 + ox, 10 + oy), (17 + ox, 11 + oy), (16 + ox, 13 + oy), (11 + ox, 13 + oy), (8 + ox, 12 + oy)],
            "head": [(16 + ox, 9 + oy), (19 + ox, 8 + oy), (19 + ox, 9 + oy), (19 + ox, 11 + oy), (16 + ox, 11 + oy)],
            "jaw": [(16 + ox, 11 + oy), (19 + ox, 10 + oy), (18 + ox, 12 + oy), (15 + ox, 12 + oy)],
            "front": [((12 + ox, 11 + oy), (14 + ox, 15 + oy)), ((15 + ox, 10 + oy), (17 + ox, 14 + oy))],
            "hind": [((8 + ox, 12 + oy), (7 + ox, 15 + oy)), ((10 + ox, 12 + oy), (10 + ox, 15 + oy))],
            "tail": [(4 + ox, 10 + oy), (2 + ox, 11 + oy), (1 + ox, 10 + oy)],
            "back": [(7 + ox, 7 + oy), (12 + ox, 6 + oy), (16 + ox, 8 + oy)],
            "eyes": [(17 + ox, 9 + oy)],
        },
        "defensive_1": {
            "shoulder": [(5 + ox, 10 + oy), (8 + ox, 7 + oy), (12 + ox, 7 + oy), (14 + ox, 8 + oy), (14 + ox, 10 + oy), (11 + ox, 11 + oy), (7 + ox, 11 + oy), (5 + ox, 11 + oy)],
            "rib": [(8 + ox, 11 + oy), (12 + ox, 11 + oy), (15 + ox, 11 + oy), (14 + ox, 13 + oy), (10 + ox, 13 + oy), (7 + ox, 12 + oy)],
            "head": [(13 + ox, 10 + oy), (16 + ox, 9 + oy), (17 + ox, 10 + oy), (16 + ox, 11 + oy), (13 + ox, 11 + oy)],
            "jaw": [(14 + ox, 11 + oy), (17 + ox, 10 + oy), (16 + ox, 12 + oy), (13 + ox, 12 + oy)],
            "front": [((11 + ox, 11 + oy), (12 + ox, 14 + oy)), ((13 + ox, 11 + oy), (14 + ox, 13 + oy))],
            "hind": [((8 + ox, 12 + oy), (7 + ox, 15 + oy)), ((10 + ox, 12 + oy), (10 + ox, 15 + oy))],
            "tail": [(5 + ox, 11 + oy), (3 + ox, 10 + oy), (2 + ox, 11 + oy)],
            "back": [(8 + ox, 8 + oy), (12 + ox, 7 + oy), (14 + ox, 8 + oy)],
            "eyes": [(15 + ox, 10 + oy)],
        },
        "defensive_2": {
            "shoulder": [(5 + ox, 11 + oy), (8 + ox, 8 + oy), (12 + ox, 8 + oy), (14 + ox, 9 + oy), (14 + ox, 11 + oy), (11 + ox, 12 + oy), (7 + ox, 12 + oy), (5 + ox, 12 + oy)],
            "rib": [(8 + ox, 12 + oy), (12 + ox, 12 + oy), (15 + ox, 12 + oy), (14 + ox, 14 + oy), (10 + ox, 14 + oy), (7 + ox, 13 + oy)],
            "head": [(12 + ox, 11 + oy), (15 + ox, 10 + oy), (16 + ox, 11 + oy), (15 + ox, 12 + oy), (12 + ox, 12 + oy)],
            "jaw": [(13 + ox, 12 + oy), (16 + ox, 11 + oy), (15 + ox, 13 + oy), (12 + ox, 13 + oy)],
            "front": [((10 + ox, 12 + oy), (11 + ox, 14 + oy)), ((12 + ox, 12 + oy), (13 + ox, 14 + oy))],
            "hind": [((8 + ox, 13 + oy), (7 + ox, 15 + oy)), ((10 + ox, 13 + oy), (10 + ox, 15 + oy))],
            "tail": [(5 + ox, 12 + oy), (3 + ox, 11 + oy), (2 + ox, 12 + oy)],
            "back": [(8 + ox, 9 + oy), (12 + ox, 8 + oy), (14 + ox, 9 + oy)],
            "eyes": [(14 + ox, 11 + oy)],
        },
        "defensive_3": {
            "shoulder": [(6 + ox, 10 + oy), (10 + ox, 7 + oy), (14 + ox, 7 + oy), (17 + ox, 8 + oy), (17 + ox, 9 + oy), (13 + ox, 10 + oy), (9 + ox, 10 + oy), (6 + ox, 11 + oy)],
            "rib": [(9 + ox, 11 + oy), (14 + ox, 10 + oy), (18 + ox, 10 + oy), (17 + ox, 12 + oy), (12 + ox, 12 + oy), (8 + ox, 12 + oy)],
            "head": [(16 + ox, 9 + oy), (19 + ox, 8 + oy), (19 + ox, 9 + oy), (19 + ox, 10 + oy), (16 + ox, 10 + oy)],
            "jaw": [(16 + ox, 10 + oy), (19 + ox, 9 + oy), (18 + ox, 11 + oy), (15 + ox, 11 + oy)],
            "front": [((13 + ox, 10 + oy), (16 + ox, 13 + oy)), ((15 + ox, 10 + oy), (18 + ox, 12 + oy))],
            "hind": [((9 + ox, 12 + oy), (8 + ox, 15 + oy)), ((11 + ox, 12 + oy), (12 + ox, 15 + oy))],
            "tail": [(6 + ox, 11 + oy), (4 + ox, 10 + oy), (3 + ox, 11 + oy)],
            "back": [(10 + ox, 8 + oy), (14 + ox, 7 + oy), (17 + ox, 8 + oy)],
            "eyes": [(17 + ox, 9 + oy)],
        },
        "defensive_4": {
            "shoulder": [(8 + ox, 10 + oy), (12 + ox, 7 + oy), (16 + ox, 7 + oy), (19 + ox, 8 + oy), (19 + ox, 9 + oy), (15 + ox, 10 + oy), (10 + ox, 10 + oy), (8 + ox, 11 + oy)],
            "rib": [(11 + ox, 11 + oy), (16 + ox, 10 + oy), (19 + ox, 10 + oy), (18 + ox, 12 + oy), (14 + ox, 12 + oy), (10 + ox, 12 + oy)],
            "head": [(18 + ox, 9 + oy), (19 + ox, 8 + oy), (19 + ox, 9 + oy), (19 + ox, 10 + oy), (18 + ox, 10 + oy)],
            "jaw": [(17 + ox, 10 + oy), (19 + ox, 9 + oy), (18 + ox, 11 + oy), (16 + ox, 11 + oy)],
            "front": [((15 + ox, 10 + oy), (18 + ox, 12 + oy)), ((17 + ox, 10 + oy), (19 + ox, 11 + oy))],
            "hind": [((11 + ox, 12 + oy), (10 + ox, 15 + oy)), ((13 + ox, 12 + oy), (14 + ox, 15 + oy))],
            "tail": [(8 + ox, 11 + oy), (6 + ox, 10 + oy), (5 + ox, 11 + oy)],
            "back": [(12 + ox, 8 + oy), (16 + ox, 7 + oy), (19 + ox, 8 + oy)],
            "eyes": [(18 + ox, 9 + oy)],
        },
        "alert_1": {
            "shoulder": [(4 + ox, 9 + oy), (7 + ox, 6 + oy), (12 + ox, 6 + oy), (15 + ox, 8 + oy), (15 + ox, 10 + oy), (12 + ox, 11 + oy), (7 + ox, 11 + oy), (4 + ox, 10 + oy)],
            "rib": [(7 + ox, 10 + oy), (12 + ox, 10 + oy), (16 + ox, 11 + oy), (15 + ox, 13 + oy), (10 + ox, 13 + oy), (7 + ox, 12 + oy)],
            "head": [(15 + ox, 10 + oy), (18 + ox, 9 + oy), (19 + ox, 10 + oy), (18 + ox, 11 + oy), (15 + ox, 11 + oy)],
            "jaw": [(16 + ox, 11 + oy), (19 + ox, 10 + oy), (18 + ox, 12 + oy), (15 + ox, 12 + oy)],
            "front": [((11 + ox, 11 + oy), (12 + ox, 15 + oy)), ((13 + ox, 11 + oy), (14 + ox, 15 + oy))],
            "hind": [((7 + ox, 12 + oy), (6 + ox, 15 + oy)), ((9 + ox, 12 + oy), (9 + ox, 15 + oy))],
            "tail": [(4 + ox, 10 + oy), (2 + ox, 9 + oy), (1 + ox, 10 + oy)],
            "back": [(6 + ox, 7 + oy), (11 + ox, 6 + oy), (15 + ox, 8 + oy)],
            "eyes": [(17 + ox, 10 + oy)],
        },
        "alert_2": {
            "shoulder": [(4 + ox, 8 + oy), (7 + ox, 5 + oy), (12 + ox, 5 + oy), (15 + ox, 7 + oy), (15 + ox, 9 + oy), (12 + ox, 10 + oy), (7 + ox, 10 + oy), (4 + ox, 9 + oy)],
            "rib": [(7 + ox, 9 + oy), (12 + ox, 9 + oy), (16 + ox, 10 + oy), (15 + ox, 12 + oy), (10 + ox, 12 + oy), (7 + ox, 11 + oy)],
            "head": [(15 + ox, 9 + oy), (18 + ox, 8 + oy), (19 + ox, 9 + oy), (18 + ox, 10 + oy), (15 + ox, 10 + oy)],
            "jaw": [(16 + ox, 10 + oy), (19 + ox, 9 + oy), (18 + ox, 11 + oy), (15 + ox, 11 + oy)],
            "front": [((11 + ox, 10 + oy), (12 + ox, 14 + oy)), ((13 + ox, 10 + oy), (14 + ox, 14 + oy))],
            "hind": [((7 + ox, 11 + oy), (6 + ox, 14 + oy)), ((9 + ox, 11 + oy), (9 + ox, 14 + oy))],
            "tail": [(4 + ox, 9 + oy), (2 + ox, 8 + oy), (1 + ox, 9 + oy)],
            "back": [(6 + ox, 6 + oy), (11 + ox, 5 + oy), (15 + ox, 7 + oy)],
            "eyes": [(17 + ox, 9 + oy)],
        },
        "alert_3": {
            "shoulder": [(4 + ox, 8 + oy), (8 + ox, 5 + oy), (13 + ox, 5 + oy), (16 + ox, 7 + oy), (16 + ox, 9 + oy), (13 + ox, 10 + oy), (8 + ox, 10 + oy), (4 + ox, 9 + oy)],
            "rib": [(8 + ox, 9 + oy), (13 + ox, 9 + oy), (17 + ox, 10 + oy), (16 + ox, 12 + oy), (11 + ox, 12 + oy), (8 + ox, 11 + oy)],
            "head": [(15 + ox, 8 + oy), (18 + ox, 7 + oy), (19 + ox, 8 + oy), (18 + ox, 10 + oy), (15 + ox, 10 + oy)],
            "jaw": [(16 + ox, 10 + oy), (19 + ox, 9 + oy), (18 + ox, 11 + oy), (15 + ox, 11 + oy)],
            "front": [((12 + ox, 10 + oy), (13 + ox, 14 + oy)), ((14 + ox, 10 + oy), (15 + ox, 13 + oy))],
            "hind": [((8 + ox, 11 + oy), (7 + ox, 14 + oy)), ((10 + ox, 11 + oy), (10 + ox, 14 + oy))],
            "tail": [(4 + ox, 9 + oy), (2 + ox, 8 + oy), (1 + ox, 8 + oy)],
            "back": [(7 + ox, 6 + oy), (12 + ox, 5 + oy), (16 + ox, 7 + oy)],
            "eyes": [(17 + ox, 8 + oy)],
        },
        "alert_4": {
            "shoulder": [(4 + ox, 7 + oy), (8 + ox, 4 + oy), (13 + ox, 4 + oy), (16 + ox, 6 + oy), (16 + ox, 9 + oy), (13 + ox, 10 + oy), (8 + ox, 10 + oy), (4 + ox, 8 + oy)],
            "rib": [(8 + ox, 8 + oy), (13 + ox, 8 + oy), (17 + ox, 9 + oy), (16 + ox, 12 + oy), (11 + ox, 12 + oy), (8 + ox, 11 + oy)],
            "head": [(15 + ox, 7 + oy), (18 + ox, 6 + oy), (19 + ox, 7 + oy), (18 + ox, 10 + oy), (15 + ox, 9 + oy)],
            "jaw": [(16 + ox, 9 + oy), (19 + ox, 8 + oy), (18 + ox, 11 + oy), (15 + ox, 10 + oy)],
            "front": [((12 + ox, 10 + oy), (13 + ox, 13 + oy)), ((14 + ox, 10 + oy), (15 + ox, 13 + oy))],
            "hind": [((8 + ox, 11 + oy), (7 + ox, 14 + oy)), ((10 + ox, 11 + oy), (10 + ox, 14 + oy))],
            "tail": [(4 + ox, 8 + oy), (2 + ox, 7 + oy), (1 + ox, 8 + oy)],
            "back": [(7 + ox, 5 + oy), (12 + ox, 4 + oy), (16 + ox, 6 + oy)],
            "eyes": [(17 + ox, 7 + oy)],
        },
        "hunt_pounce_1": {
            "shoulder": [(5 + ox, 10 + oy), (8 + ox, 7 + oy), (13 + ox, 7 + oy), (16 + ox, 8 + oy), (16 + ox, 10 + oy), (13 + ox, 11 + oy), (8 + ox, 11 + oy), (5 + ox, 11 + oy)],
            "rib": [(8 + ox, 11 + oy), (13 + ox, 11 + oy), (17 + ox, 11 + oy), (16 + ox, 13 + oy), (11 + ox, 13 + oy), (8 + ox, 12 + oy)],
            "head": [(15 + ox, 10 + oy), (18 + ox, 9 + oy), (19 + ox, 10 + oy), (18 + ox, 11 + oy), (15 + ox, 11 + oy)],
            "jaw": [(16 + ox, 11 + oy), (19 + ox, 10 + oy), (18 + ox, 12 + oy), (15 + ox, 12 + oy)],
            "front": [((12 + ox, 11 + oy), (14 + ox, 14 + oy)), ((15 + ox, 10 + oy), (17 + ox, 13 + oy))],
            "hind": [((8 + ox, 12 + oy), (7 + ox, 15 + oy)), ((10 + ox, 12 + oy), (10 + ox, 15 + oy))],
            "tail": [(5 + ox, 11 + oy), (3 + ox, 10 + oy), (2 + ox, 11 + oy)],
            "back": [(8 + ox, 8 + oy), (13 + ox, 7 + oy), (16 + ox, 8 + oy)],
            "eyes": [(17 + ox, 10 + oy)],
        },
        "hunt_pounce_2": {
            "shoulder": [(5 + ox, 11 + oy), (9 + ox, 8 + oy), (14 + ox, 8 + oy), (17 + ox, 9 + oy), (17 + ox, 10 + oy), (14 + ox, 11 + oy), (9 + ox, 11 + oy), (5 + ox, 12 + oy)],
            "rib": [(9 + ox, 12 + oy), (14 + ox, 11 + oy), (18 + ox, 11 + oy), (17 + ox, 13 + oy), (12 + ox, 13 + oy), (8 + ox, 13 + oy)],
            "head": [(16 + ox, 10 + oy), (19 + ox, 9 + oy), (19 + ox, 10 + oy), (19 + ox, 11 + oy), (16 + ox, 11 + oy)],
            "jaw": [(16 + ox, 11 + oy), (19 + ox, 10 + oy), (18 + ox, 12 + oy), (15 + ox, 12 + oy)],
            "front": [((13 + ox, 11 + oy), (15 + ox, 14 + oy)), ((16 + ox, 10 + oy), (18 + ox, 12 + oy))],
            "hind": [((9 + ox, 13 + oy), (8 + ox, 15 + oy)), ((11 + ox, 13 + oy), (12 + ox, 15 + oy))],
            "tail": [(5 + ox, 12 + oy), (3 + ox, 11 + oy), (2 + ox, 12 + oy)],
            "back": [(9 + ox, 9 + oy), (14 + ox, 8 + oy), (17 + ox, 9 + oy)],
            "eyes": [(17 + ox, 10 + oy)],
        },
        "hunt_pounce_3": {
            "shoulder": [(7 + ox, 10 + oy), (12 + ox, 7 + oy), (16 + ox, 7 + oy), (19 + ox, 8 + oy), (19 + ox, 9 + oy), (15 + ox, 10 + oy), (10 + ox, 10 + oy), (7 + ox, 11 + oy)],
            "rib": [(10 + ox, 11 + oy), (15 + ox, 10 + oy), (19 + ox, 10 + oy), (18 + ox, 12 + oy), (13 + ox, 12 + oy), (9 + ox, 12 + oy)],
            "head": [(18 + ox, 9 + oy), (19 + ox, 8 + oy), (19 + ox, 9 + oy), (19 + ox, 10 + oy), (18 + ox, 10 + oy)],
            "jaw": [(17 + ox, 10 + oy), (19 + ox, 9 + oy), (18 + ox, 11 + oy), (16 + ox, 11 + oy)],
            "front": [((14 + ox, 10 + oy), (17 + ox, 12 + oy)), ((17 + ox, 10 + oy), (19 + ox, 11 + oy))],
            "hind": [((10 + ox, 12 + oy), (9 + ox, 15 + oy)), ((12 + ox, 12 + oy), (13 + ox, 15 + oy))],
            "tail": [(7 + ox, 11 + oy), (5 + ox, 10 + oy), (4 + ox, 11 + oy)],
            "back": [(12 + ox, 8 + oy), (16 + ox, 7 + oy), (19 + ox, 8 + oy)],
            "eyes": [(18 + ox, 9 + oy)],
        },
        "hunt_pounce_4": {
            "shoulder": [(9 + ox, 10 + oy), (13 + ox, 7 + oy), (17 + ox, 7 + oy), (19 + ox, 8 + oy), (18 + ox, 10 + oy), (14 + ox, 11 + oy), (10 + ox, 11 + oy), (8 + ox, 11 + oy)],
            "rib": [(11 + ox, 11 + oy), (16 + ox, 10 + oy), (19 + ox, 10 + oy), (18 + ox, 12 + oy), (14 + ox, 12 + oy), (10 + ox, 12 + oy)],
            "head": [(16 + ox, 10 + oy), (19 + ox, 9 + oy), (18 + ox, 11 + oy), (16 + ox, 11 + oy)],
            "jaw": [(16 + ox, 11 + oy), (18 + ox, 10 + oy), (17 + ox, 12 + oy), (15 + ox, 12 + oy)],
            "front": [((11 + ox, 12 + oy), (10 + ox, 15 + oy)), ((14 + ox, 11 + oy), (15 + ox, 15 + oy))],
            "hind": [((11 + ox, 12 + oy), (12 + ox, 15 + oy)), ((13 + ox, 12 + oy), (15 + ox, 14 + oy))],
            "tail": [(8 + ox, 11 + oy), (10 + ox, 10 + oy), (12 + ox, 11 + oy)],
            "back": [(13 + ox, 8 + oy), (17 + ox, 7 + oy), (18 + ox, 8 + oy)],
            "eyes": [(17 + ox, 10 + oy)],
        },
        "recovery_1": {
            "shoulder": [(9 + ox, 10 + oy), (13 + ox, 8 + oy), (17 + ox, 8 + oy), (19 + ox, 9 + oy), (18 + ox, 11 + oy), (14 + ox, 12 + oy), (10 + ox, 12 + oy), (8 + ox, 11 + oy)],
            "rib": [(11 + ox, 11 + oy), (16 + ox, 10 + oy), (19 + ox, 10 + oy), (18 + ox, 12 + oy), (14 + ox, 13 + oy), (10 + ox, 13 + oy)],
            "head": [(17 + ox, 9 + oy), (19 + ox, 8 + oy), (19 + ox, 9 + oy), (19 + ox, 10 + oy), (17 + ox, 10 + oy)],
            "jaw": [(17 + ox, 10 + oy), (19 + ox, 9 + oy), (18 + ox, 11 + oy), (16 + ox, 11 + oy)],
            "front": [((12 + ox, 12 + oy), (11 + ox, 15 + oy)), ((15 + ox, 12 + oy), (16 + ox, 15 + oy))],
            "hind": [((10 + ox, 12 + oy), (9 + ox, 15 + oy)), ((13 + ox, 12 + oy), (14 + ox, 15 + oy))],
            "tail": [(9 + ox, 11 + oy), (7 + ox, 10 + oy), (5 + ox, 11 + oy)],
            "back": [(13 + ox, 9 + oy), (17 + ox, 8 + oy), (19 + ox, 9 + oy)],
            "eyes": [(17 + ox, 9 + oy)],
        },
        "recovery_2": {
            "shoulder": [(8 + ox, 10 + oy), (12 + ox, 8 + oy), (16 + ox, 8 + oy), (18 + ox, 9 + oy), (18 + ox, 11 + oy), (14 + ox, 12 + oy), (10 + ox, 12 + oy), (8 + ox, 11 + oy)],
            "rib": [(10 + ox, 11 + oy), (15 + ox, 10 + oy), (18 + ox, 10 + oy), (17 + ox, 12 + oy), (13 + ox, 13 + oy), (9 + ox, 13 + oy)],
            "head": [(16 + ox, 9 + oy), (18 + ox, 8 + oy), (19 + ox, 9 + oy), (18 + ox, 10 + oy), (16 + ox, 10 + oy)],
            "jaw": [(16 + ox, 10 + oy), (19 + ox, 9 + oy), (18 + ox, 11 + oy), (15 + ox, 11 + oy)],
            "front": [((11 + ox, 12 + oy), (10 + ox, 15 + oy)), ((14 + ox, 12 + oy), (15 + ox, 15 + oy))],
            "hind": [((9 + ox, 12 + oy), (8 + ox, 15 + oy)), ((12 + ox, 12 + oy), (13 + ox, 15 + oy))],
            "tail": [(8 + ox, 11 + oy), (6 + ox, 10 + oy), (4 + ox, 11 + oy)],
            "back": [(12 + ox, 9 + oy), (16 + ox, 8 + oy), (18 + ox, 9 + oy)],
            "eyes": [(16 + ox, 9 + oy)],
        },
        "recovery_3": {
            "shoulder": [(7 + ox, 11 + oy), (10 + ox, 9 + oy), (14 + ox, 9 + oy), (16 + ox, 10 + oy), (15 + ox, 12 + oy), (11 + ox, 13 + oy), (8 + ox, 13 + oy), (6 + ox, 12 + oy)],
            "rib": [(8 + ox, 12 + oy), (12 + ox, 11 + oy), (16 + ox, 11 + oy), (15 + ox, 13 + oy), (10 + ox, 14 + oy), (7 + ox, 14 + oy)],
            "head": [(14 + ox, 10 + oy), (17 + ox, 9 + oy), (18 + ox, 10 + oy), (17 + ox, 12 + oy), (14 + ox, 12 + oy)],
            "jaw": [(15 + ox, 11 + oy), (18 + ox, 10 + oy), (17 + ox, 12 + oy), (14 + ox, 12 + oy)],
            "front": [((9 + ox, 13 + oy), (8 + ox, 15 + oy)), ((12 + ox, 13 + oy), (13 + ox, 15 + oy))],
            "hind": [((7 + ox, 13 + oy), (6 + ox, 15 + oy)), ((9 + ox, 13 + oy), (10 + ox, 15 + oy))],
            "tail": [(6 + ox, 12 + oy), (4 + ox, 13 + oy), (3 + ox, 12 + oy)],
            "back": [(10 + ox, 10 + oy), (14 + ox, 9 + oy), (17 + ox, 10 + oy)],
            "eyes": [(16 + ox, 10 + oy)],
        },
        "recovery_4": {
            "shoulder": [(7 + ox, 11 + oy), (10 + ox, 9 + oy), (14 + ox, 9 + oy), (16 + ox, 10 + oy), (15 + ox, 12 + oy), (11 + ox, 13 + oy), (8 + ox, 13 + oy), (6 + ox, 12 + oy)],
            "rib": [(8 + ox, 12 + oy), (12 + ox, 11 + oy), (16 + ox, 11 + oy), (15 + ox, 13 + oy), (10 + ox, 14 + oy), (7 + ox, 14 + oy)],
            "head": [(13 + ox, 10 + oy), (16 + ox, 9 + oy), (17 + ox, 10 + oy), (16 + ox, 12 + oy), (13 + ox, 12 + oy)],
            "jaw": [(14 + ox, 11 + oy), (17 + ox, 10 + oy), (16 + ox, 12 + oy), (13 + ox, 12 + oy)],
            "front": [((9 + ox, 13 + oy), (8 + ox, 15 + oy)), ((12 + ox, 13 + oy), (13 + ox, 15 + oy))],
            "hind": [((7 + ox, 13 + oy), (6 + ox, 15 + oy)), ((9 + ox, 13 + oy), (10 + ox, 15 + oy))],
            "tail": [(6 + ox, 12 + oy), (4 + ox, 13 + oy), (3 + ox, 12 + oy)],
            "back": [(10 + ox, 10 + oy), (14 + ox, 9 + oy), (16 + ox, 10 + oy)],
            "eyes": [(15 + ox, 10 + oy)],
        },
    }
    shape = pose_shapes[pose_key]
    _draw_prowler_pose_parts(
        draw,
        spec,
        shape["shoulder"],
        shape["rib"],
        shape["head"],
        shape["jaw"],
        shape["front"],
        shape["hind"],
        shape["tail"],
        hostile,
        shape["eyes"],
        shape["back"],
    )


def draw_replacement_prowler_comparison(
    variant_specs: list[ProwlerVariantSpec],
    comparison_path: Path,
) -> None:
    background = _load_arena_background()
    draw = ImageDraw.Draw(background)
    font = ImageFont.load_default()

    _draw_label(draw, (8, 8), "Prowler Candidate Comparison", font)
    _draw_label(draw, (8, 20), "Stylized prowler variants at native gameplay scale on the live arena floor", font)

    benchmark_row = [
        ("Akedra", ROOT / "art" / "sprites" / "player_hunter.png", (32, 82)),
        ("Normal", ROOT / "art" / "sprites" / "enemy_creature.png", (78, 82)),
        ("Heart Runner", ROOT / "art" / "sprites" / "heart_runner.png", (126, 82)),
        ("Shooter", ROOT / "art" / "sprites" / "shooter_enemy.png", (176, 82)),
        ("Shielded", ROOT / "art" / "sprites" / "shielded_enemy.png", (228, 82)),
        ("Charger", ROOT / "art" / "sprites" / "charger_beast.png", (334, 82)),
    ]
    for label, sprite_path, feet_position in benchmark_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        _draw_label(draw, (feet_position[0] - 18, feet_position[1] + 4), label, font)

    column_centers = [82, 192, 302]
    row_positions = [
        ("stalk", "stalk", 110),
        ("alert", "alert", 136),
        ("hunt", "hunt", 162),
        ("def", "defensive", 188),
    ]
    for index, spec in enumerate(variant_specs):
        display_title = {
            "Bonejaw Prowler": "Bonejaw",
            "Bristlemane Prowler": "Bristlemane",
            "Hollow Hound": "Hollow",
        }.get(spec.title, spec.title.replace(" Prowler", ""))
        _draw_label(draw, (column_centers[index] - 28, 96), display_title, font)
        for row_label, pose_key, y in row_positions:
            preview = _render_prowler_candidate_pose(spec, pose_key)
            background.alpha_composite(preview, (column_centers[index] - preview.width // 2, y - preview.height))
            _draw_label(draw, (column_centers[index] - 18, y), row_label, font)

    comparison_path.parent.mkdir(parents=True, exist_ok=True)
    background.save(comparison_path)


def draw_replacement_prowler_behavior_board(board_path: Path) -> None:
    background = _load_arena_background()
    draw = ImageDraw.Draw(background)
    font = ImageFont.load_default()

    _draw_label(draw, (8, 8), "Prowler Behavior Board", font)
    _draw_label(draw, (8, 20), "Selected Bonejaw Prowler animation groups at native arena scale", font)

    benchmark_row = [
        ("Akedra", ROOT / "art" / "sprites" / "player_hunter.png", (34, 82)),
        ("Normal", ROOT / "art" / "sprites" / "enemy_creature.png", (86, 82)),
        ("Shielded", ROOT / "art" / "sprites" / "shielded_enemy.png", (138, 82)),
        ("Boomer", ROOT / "art" / "sprites" / "boomer_enemy.png", (190, 82)),
        ("Runner", ROOT / "art" / "sprites" / "heart_runner.png", (242, 82)),
        ("Charger", ROOT / "art" / "sprites" / "charger_beast.png", (332, 82)),
    ]
    for label, sprite_path, feet_position in benchmark_row:
        _paste_grounded_sprite(background, sprite_path, feet_position)
        _draw_label(draw, (feet_position[0] - 16, feet_position[1] + 4), label, font)

    sequence_specs = [
        ("Stalk", "stalk", 1, (8, 112)),
        ("Def Windup", "defensive", 0, (100, 112)),
        ("Def Pounce", "defensive", 3, (192, 112)),
        ("Alert", "alert", 3, (284, 112)),
        ("Hunt", "hunt", 1, (8, 166)),
        ("Hunt Leap", "hunt_pounce", 1, (100, 166)),
        ("Impact", "hunt_pounce", 2, (192, 166)),
        ("Miss/Stun", "recovery", 3, (284, 166)),
    ]
    for title, sequence_key, frame_index, position in sequence_specs:
        frame_image = _scale_image_nearest_integer(_render_selected_prowler_frame(sequence_key, frame_index), 2)
        background.alpha_composite(frame_image, position)
        _draw_label(draw, (position[0], position[1] - 10), title, font)

    board_path.parent.mkdir(parents=True, exist_ok=True)
    background.save(board_path)


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
    draw_prowler_enemy(SPRITE_DIR / "prowler_enemy.png")
    draw_prowler_animation_sheet(SPRITE_DIR / "prowler_enemy_sheet.png")
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
        "--generate-dev-prowler-concepts",
        action="store_true",
        help="Generate temporary Prowler candidate outputs and comparison board.",
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
        help="Generate live assets plus the temporary Shooter, Boomer, Prowler, Heart Runner concept, and Heart Runner animation outputs.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.all or (
        not args.generate_dev_shooter_concepts
        and not args.generate_dev_boomer_concepts
        and not args.generate_dev_prowler_concepts
        and not args.generate_dev_heart_runner_concepts
    ):
        draw_standard_assets()
    if args.all or args.generate_dev_shooter_concepts:
        generate_shooter_candidate_assets()
    if args.all or args.generate_dev_boomer_concepts:
        generate_boomer_candidate_assets()
    if args.all or args.generate_dev_prowler_concepts:
        generate_prowler_candidate_assets()
    if args.all or args.generate_dev_heart_runner_concepts:
        generate_heart_runner_candidate_assets()
    if args.all or args.generate_dev_heart_runner_animations:
        generate_heart_runner_animation_preview()


if __name__ == "__main__":
    main()
