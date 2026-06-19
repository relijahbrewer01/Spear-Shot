from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEV_DIR = ROOT / "art" / "dev" / "shooter_candidates"
ACTIVE_SPRITE_PATH = ROOT / "art" / "sprites" / "shooter_enemy.png"

EXPECTED_CANDIDATES = {
    "1": {
        "file_name": "shooter_palette_variant_1.png",
        "title": "Olive Hood",
    },
    "2": {
        "file_name": "shooter_palette_variant_2.png",
        "title": "Moss Hood",
    },
    "3": {
        "file_name": "shooter_palette_variant_3.png",
        "title": "Peat Hood",
    },
}


def require(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        print(f"PASS: {message}")
        return
    print(f"FAIL: {message}")
    failures.append(message)


def main() -> int:
    failures: list[str] = []
    manifest_path = DEV_DIR / "shooter_palette_manifest.json"
    comparison_path = DEV_DIR / "shooter_palette_comparison.png"

    require(DEV_DIR.exists(), "Shooter candidate dev directory exists", failures)
    require(manifest_path.exists(), "Shooter palette manifest exists", failures)
    require(comparison_path.exists(), "Shooter palette comparison image exists", failures)
    if failures:
        print(f"\nShooter visual concept audit failed with {len(failures)} issue(s).")
        return 1

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    candidates = manifest.get("candidates", [])
    require(len(candidates) == 3, "Exactly three Shooter palette variants are listed in the manifest", failures)
    require(
        manifest.get("comparison_path") == str(comparison_path),
        "Manifest points to the generated palette comparison image",
        failures,
    )
    require(
        manifest.get("active_reference_path") == str(ACTIVE_SPRITE_PATH),
        "Manifest points to the active Shooter reference sprite",
        failures,
    )

    recorded_sizes: set[tuple[int, int]] = set()
    for candidate in candidates:
        key = candidate.get("key")
        expected = EXPECTED_CANDIDATES.get(key)
        require(expected is not None, f"Variant {key} is expected", failures)
        if expected is None:
            continue

        candidate_path = Path(candidate["path"])
        require(candidate_path.exists(), f"Variant {key} image exists", failures)
        if candidate_path.exists():
            image = Image.open(candidate_path)
            require(image.size == (16, 18), f"Variant {key} uses the approved 16x18 live canvas", failures)

        require(candidate["file_name"] == expected["file_name"], f"Variant {key} file name is stable", failures)
        require(candidate["title"] == expected["title"], f"Variant {key} title is stable", failures)
        require(candidate["blowgun_length"] == 14, f"Variant {key} uses the proposed 14px blowgun length", failures)
        require(candidate["blowgun_width"] == 1, f"Variant {key} uses the lighter 1px blowgun width", failures)
        require(bool(candidate.get("palette_summary")), f"Variant {key} includes a palette summary", failures)
        require(bool(candidate.get("contrast_summary")), f"Variant {key} includes value/contrast reasoning", failures)
        require(
            candidate.get("silhouette_summary") == "Approved A/B hybrid silhouette on the live 16x18 canvas.",
            f"Variant {key} records the approved silhouette gate",
            failures,
        )
        apparent_size = (
            int(candidate["apparent_body_width"]),
            int(candidate["apparent_body_height"]),
        )
        recorded_sizes.add(apparent_size)
        require(apparent_size[0] > 0 and apparent_size[1] > 0, f"Variant {key} records a measurable apparent body size", failures)

    require(len(recorded_sizes) == 1, "All three palette variants preserve the exact same apparent body size", failures)

    comparison_image = Image.open(comparison_path)
    require(
        comparison_image.size == (384, 216),
        "Shooter palette comparison image is a single native-resolution arena board",
        failures,
    )

    if failures:
        print(f"\nShooter visual concept audit failed with {len(failures)} issue(s).")
        return 1

    print("\nShooter visual concept audit passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
