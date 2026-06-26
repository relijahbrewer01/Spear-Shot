from __future__ import annotations

from pathlib import Path
import sys

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
    else:
        print(f"FAIL: {message}")
        failures.append(message)


def audit_png(relative_path: str, failures: list[str]) -> None:
    path = ROOT / relative_path
    image = Image.open(path).convert("RGBA")
    alpha_histogram = image.getchannel("A").histogram()
    partial_alpha = sum(alpha_histogram[1:255])
    opaque_alpha = alpha_histogram[255]
    unique_alpha = [index for index, count in enumerate(alpha_histogram) if count > 0]

    print(
        f"INFO: {relative_path} size={image.width}x{image.height} "
        f"opaque_pixels={opaque_alpha} partial_alpha_pixels={partial_alpha} "
        f"unique_alpha_values={unique_alpha[:8]}"
    )
    require(partial_alpha == 0, f"{relative_path} has no partial-alpha smoothing pixels", failures)


def main() -> int:
    failures: list[str] = []

    project_text = read_text("project.godot")
    main_script = read_text("scripts/main.gd")
    player_script = read_text("scripts/player.gd")
    enemy_script = read_text("scripts/enemy.gd")
    spear_script = read_text("scripts/spear.gd")
    generator_script = read_text("tools/generate_phase1_assets.py")
    phase4_generator_script = read_text("tools/generate_phase4_assets.py")

    require('window/stretch/mode="viewport"' in project_text, "Project uses viewport stretch mode", failures)
    aspect_setting_is_keep = (
        'window/stretch/aspect="keep"' in project_text
        or "window/stretch/aspect=" not in project_text
    )
    require(aspect_setting_is_keep, "Project keeps 16:9 aspect", failures)
    require('window/stretch/scale_mode="integer"' in project_text, "Project uses integer scaling", failures)
    require(
        'textures/canvas_textures/default_texture_filter=0' in project_text,
        "Project default texture filter is nearest",
        failures,
    )
    require(
        "roundf(randf_range" in main_script,
        "Screen shake is quantized to whole internal pixels",
        failures,
    )
    require(
        "body_visual.top_level = true" in player_script
        and "body_visual.global_position" in player_script
        and "body_visual.scale = Vector2.ONE" in player_script
        and "body_sprite.scale = Vector2.ONE" in player_script,
        "Player visual uses snapped top-level rendering without fractional scale",
        failures,
    )
    require(
        "sprite.top_level = true" in enemy_script
        and "sprite.global_position" in enemy_script
        and "return Vector2.ONE" in enemy_script,
        "Enemy sprite uses snapped top-level rendering without fractional scale",
        failures,
    )
    require(
        "sprite.top_level = true" in spear_script
        and "sprite.global_position" in spear_script
        and "sprite.scale = Vector2.ONE" in spear_script,
        "Spear sprite uses snapped top-level rendering without fractional scale",
        failures,
    )
    require(
        ".resize(" not in generator_script and ".resize(" not in phase4_generator_script,
        "Asset generators do not resize images with filtered sampling",
        failures,
    )

    for import_path in [
        "art/arena/arena_floor.png.import",
        "art/sprites/player_hunter.png.import",
        "art/sprites/enemy_creature.png.import",
        "art/sprites/charger_beast.png.import",
        "art/sprites/shielded_enemy.png.import",
        "art/sprites/shooter_enemy.png.import",
        "art/sprites/prowler_enemy.png.import",
        "art/sprites/spear_hunter.png.import",
    ]:
        import_text = read_text(import_path)
        require("mipmaps/generate=false" in import_text, f"{import_path} disables mipmaps", failures)

    for png_path in [
        "art/arena/arena_floor.png",
        "art/sprites/player_hunter.png",
        "art/sprites/enemy_creature.png",
        "art/sprites/charger_beast.png",
        "art/sprites/shielded_enemy.png",
        "art/sprites/shooter_enemy.png",
        "art/sprites/prowler_enemy.png",
        "art/sprites/spear_hunter.png",
    ]:
        audit_png(png_path, failures)

    if failures:
        print(f"\nPixel render audit failed with {len(failures)} issue(s).")
        return 1

    print("\nPixel render audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
