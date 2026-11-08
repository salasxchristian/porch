"""Render the Porch app icon for Windows and macOS.

Mirrors assets/icon/porch.svg. Run from the repo root:

    uv run --with pillow tool/make_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

SAGE = "#3E5C4B"
CREAM = "#FFF4E4"
AMBER = "#FFB547"

ROOT = Path(__file__).resolve().parent.parent
SS = 4  # supersampling factor for smooth edges


def render(size: int, inset: float = 0.0) -> Image.Image:
    """Draw the icon at `size` px; `inset` is the transparent margin as a fraction of size."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    margin = big * inset
    scale = (big - 2 * margin) / 512

    def p(x: float, y: float) -> tuple[float, float]:
        return (margin + x * scale, margin + y * scale)

    d.rounded_rectangle([p(0, 0), p(512, 512)], radius=115 * scale, fill=SAGE)

    house = [p(156, 238), p(256, 154), p(356, 238), p(356, 358), p(156, 358), p(156, 238)]
    # Stroke with round joins: a quad per segment plus a disc at every vertex.
    r = 16 * scale
    for (x1, y1), (x2, y2) in zip(house, house[1:]):
        length = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
        nx, ny = -(y2 - y1) / length * r, (x2 - x1) / length * r
        d.polygon(
            [(x1 + nx, y1 + ny), (x2 + nx, y2 + ny), (x2 - nx, y2 - ny), (x1 - nx, y1 - ny)],
            fill=CREAM,
        )
    for x, y in house:
        d.ellipse([x - r, y - r, x + r, y + r], fill=CREAM)

    cx, cy = p(256, 286)
    dot = 34 * scale
    d.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill=AMBER)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    render(256).save(
        ROOT / "windows/runner/resources/app_icon.ico",
        sizes=[(s, s) for s in ico_sizes],
    )

    # macOS icons keep Apple's ~10% transparent margin around the shape.
    mac_dir = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for s in [16, 32, 64, 128, 256, 512, 1024]:
        render(s, inset=0.1).save(mac_dir / f"app_icon_{s}.png")

    render(1024).save(ROOT / "assets/icon/porch_1024.png")


if __name__ == "__main__":
    main()
