#!/usr/bin/env python3
"""Генерирует иконки PWA из основной иконки icon.png.

Иконка временная: финальная войдёт в задачу про иллюстрации. Размеры взяты из
требований PWA-манифеста Godot: 144x144, 180x180, 512x512. Запуск:
    python3 tools/generate_pwa_icons.py
Результат: assets/icons/icon-144.png, icon-180.png, icon-512.png.
"""
import os

from PIL import Image

SIZES = (144, 180, 512)
ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "icon.png")
OUT_DIR = os.path.join(ROOT, "assets", "icons")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    with Image.open(SRC) as img:
        src = img.convert("RGBA")
        for size in SIZES:
            resized = src.resize((size, size), Image.LANCZOS)
            out = os.path.join(OUT_DIR, f"icon-{size}.png")
            resized.save(out)
            print("wrote", out)


if __name__ == "__main__":
    main()
