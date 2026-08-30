"""Genera el catálogo de iconos de iOS desde un PNG de 1024 opaco.

Los tamaños son los que ya lista `Contents.json` del proyecto; el script
solo reescribe los PNG, no toca el catálogo.
"""
import sys
from pathlib import Path

from PIL import Image

SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

DESTINO = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")


def main() -> None:
    origen = Path(sys.argv[1])
    # RGB, sin alfa: iOS rechaza los iconos con canal de transparencia.
    base = Image.open(origen).convert("RGB")
    for nombre, lado in SIZES.items():
        base.resize((lado, lado), Image.LANCZOS).save(
            DESTINO / nombre, "PNG", optimize=True
        )
    print(f"{len(SIZES)} iconos escritos en {DESTINO}")


if __name__ == "__main__":
    main()
