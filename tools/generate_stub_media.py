#!/usr/bin/env python3
"""Генератор заглушек медиа для пар слов.

Читает content/pairs/<contrast>.json и для каждой пары и каждой стороны
(a и b) создаёт заглушку картинки (PNG) и звука (WAV). Заглушки нужны, чтобы
интерфейс и тесты работали до появления настоящих иллюстраций и озвучки.

Запуск:
    python3 tools/generate_stub_media.py content/pairs/sh_s.json

Файлы пишутся по путям res://... из JSON, приведённым к путям репозитория.
Скрипт не перезаписывает существующие файлы без флага --force.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

IMAGE_SIZE = 256
AUDIO_RATE = 22050
AUDIO_SECONDS = 0.25
AUDIO_AMPLITUDE = 0.35


def res_to_path(res_path: str) -> Path:
    """res://content/... -> <repo>/content/..."""
    if not res_path.startswith("res://"):
        raise ValueError(f"ожидался путь res://, получено: {res_path}")
    return REPO_ROOT / res_path[len("res://"):]


def color_for(pair_id: str, side: str) -> tuple[int, int, int]:
    """Стабильный цвет заглушки: сторона a тёплая, сторона b холодная."""
    seed = sum(ord(ch) for ch in pair_id) % 64
    if side == "a":
        return (200 + seed % 40, 120 + seed, 90)
    return (90, 140 + seed, 200 + seed % 40)


def png_chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path: Path, rgb: tuple[int, int, int]) -> None:
    """Пишет простой PNG: сплошной цвет с рамкой по краю."""
    r, g, b = rgb
    border = (40, 40, 40)
    rows = bytearray()
    for y in range(IMAGE_SIZE):
        rows.append(0)  # фильтр строки: none
        edge_y = y < 4 or y >= IMAGE_SIZE - 4
        for x in range(IMAGE_SIZE):
            edge = edge_y or x < 4 or x >= IMAGE_SIZE - 4
            cr, cg, cb = border if edge else (r, g, b)
            rows.extend((cr, cg, cb, 255))
    ihdr = struct.pack(">IIBBBBB", IMAGE_SIZE, IMAGE_SIZE, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + png_chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def write_wav(path: Path, freq: float) -> None:
    """Пишет WAV: короткий тон с плавным затуханием, чтобы не было щелчка."""
    frames = int(AUDIO_RATE * AUDIO_SECONDS)
    samples = bytearray()
    for i in range(frames):
        t = i / AUDIO_RATE
        fade = 1.0 - (i / frames)
        value = math.sin(2.0 * math.pi * freq * t) * AUDIO_AMPLITUDE * fade
        samples.extend(struct.pack("<h", int(value * 32767)))
    data_size = len(samples)
    header = (
        b"RIFF"
        + struct.pack("<I", 36 + data_size)
        + b"WAVE"
        + b"fmt "
        + struct.pack("<IHHIIHH", 16, 1, 1, AUDIO_RATE, AUDIO_RATE * 2, 2, 16)
        + b"data"
        + struct.pack("<I", data_size)
    )
    path.write_bytes(header + bytes(samples))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pairs_file", help="путь к content/pairs/<contrast>.json")
    parser.add_argument("--force", action="store_true", help="перезаписать существующие файлы")
    args = parser.parse_args()

    pairs_path = Path(args.pairs_file)
    if not pairs_path.is_absolute():
        pairs_path = (Path.cwd() / pairs_path).resolve()
    payload = json.loads(pairs_path.read_text(encoding="utf-8"))
    pairs = payload.get("pairs", [])
    if not pairs:
        print("нет пар в файле", file=sys.stderr)
        return 1

    created = 0
    skipped = 0
    for pair in pairs:
        pair_id = str(pair["id"])
        for side in ("a", "b"):
            image_res = str(pair.get(f"image_{side}", ""))
            audio_res = str(pair.get(f"audio_{side}", ""))
            if image_res:
                image_path = res_to_path(image_res)
                image_path.parent.mkdir(parents=True, exist_ok=True)
                if image_path.exists() and not args.force:
                    skipped += 1
                else:
                    write_png(image_path, color_for(pair_id, side))
                    created += 1
            if audio_res:
                audio_path = res_to_path(audio_res)
                audio_path.parent.mkdir(parents=True, exist_ok=True)
                if audio_path.exists() and not args.force:
                    skipped += 1
                else:
                    freq = 330.0 if side == "a" else 440.0
                    write_wav(audio_path, freq)
                    created += 1
    print(f"создано: {created}, пропущено: {skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
