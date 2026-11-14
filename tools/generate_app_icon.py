#!/usr/bin/env python3
"""Генерирует заглушку иконки приложения (512x512).

Иконка временная: финальная войдёт в задачу про иллюстрации. Запуск:
    python3 tools/generate_app_icon.py
Результат: icon.png в корне проекта.
"""
import math
import os

from PIL import Image, ImageDraw

SIZE = 512
BG = (61, 139, 125, 255)
FG = (255, 255, 255, 255)
OUT = os.path.join(os.path.dirname(__file__), "..", "icon.png")


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([16, 16, SIZE - 16, SIZE - 16], radius=96, fill=BG)

    cx, cy = 180, SIZE // 2
    draw.ellipse([cx - 34, cy - 34, cx + 34, cy + 34], fill=FG)

    for i, radius in enumerate([70, 120, 170]):
        box = [cx - radius, cy - radius, cx + radius, cy + radius]
        draw.arc(box, start=-52, end=52, fill=FG, width=26)

    img.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
