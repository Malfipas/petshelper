"""桌宠展开态素材与尺寸对比图（用完即弃）。

复用 pet_asset_build 里的抠图与重采样，产出：
- assets/桌宠/展开-360.png / -480 / -560 / -640（透明，贴右缘）
- assets/桌宠/展开尺寸对比.png（收起 240 与四档展开同一基线并排）
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from pet_asset_build import background_mask, cut_out, load_rgb, resize_to_height

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "桌宠展开态.jpg"
OUT_DIR = ROOT / "assets" / "桌宠"
EXPAND_HEIGHTS = [360, 480, 560, 640]
COLLAPSED = OUT_DIR / "常驻右-240.png"


def build_expanded() -> list:
    rgb = load_rgb(SRC)
    bg = background_mask(rgb)
    print(f"展开态白底占比：{bg.mean():.3f}")

    cut = cut_out(rgb, bg)
    rgba = np.array(cut)
    content = rgba[:, :, 3] > 8
    ys, xs = np.where(content)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    cropped = cut.crop(box)
    print(f"展开态裁切后尺寸：{cropped.size}")

    results = []
    for h in EXPAND_HEIGHTS:
        img = resize_to_height(cropped, h)
        path = OUT_DIR / f"展开-{h}.png"
        img.save(path)
        print(f"输出 {path.name}：{img.size}")
        results.append((h, img))

    for h, img in results:
        a = np.array(img.getchannel("A"))
        assert a[0, 0] == 0 and a[-1, -1] == 0, "四角不透明"
        assert img.height == h, "高度不对"
        assert (a[:, -1] > 0).any(), "右缘没有内容"
    print("展开态自检通过：四角透明、右缘有内容、高度准确")
    return results


def compare(expanded: list) -> None:
    collapsed = Image.open(COLLAPSED).convert("RGBA")
    items = [("collapsed 240", collapsed)] + [(f"expanded {h}", img) for h, img in expanded]

    pad, gap, label_h = 40, 30, 46
    width = pad * 2 + sum(img.width for _, img in items) + gap * (len(items) - 1)
    height = 800
    canvas = Image.new("RGB", (width, height), (243, 246, 250))
    draw = ImageDraw.Draw(canvas)

    baseline = height - label_h - 20
    x = pad
    for label, img in items:
        canvas.paste(img, (x, baseline - img.height), img)
        draw.line([(x, baseline + 6), (x + img.width, baseline + 6)], fill=(203, 212, 224), width=1)
        draw.text((x, baseline + 14), label, fill=(60, 70, 85))
        draw.text((x, baseline + 30), f"{img.width}x{img.height}", fill=(120, 130, 145))
        x += img.width + gap

    out = OUT_DIR / "展开尺寸对比.png"
    canvas.save(out)
    print(f"输出 {out.name}：{canvas.size}")


if __name__ == "__main__":
    compare(build_expanded())
