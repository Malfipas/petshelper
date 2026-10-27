"""桌宠常驻态素材一次性生成脚本（用完即弃）。

输入：根目录 `桌宠收起态.jpg`（白底 JPG，无 alpha）
输出：`assets/桌宠/` 下三档透明 PNG、一张 2 倍图、一张三栏并排预览

做法：
1. 从四边向内做近白连通填充，只抠掉与边界连通的白，保住眼白与高光
2. 边缘按亮度估 alpha 并反预乘，去掉 JPG 混进去的白边
3. 定位竖直墙条的右边界并裁掉，让脸与手指贴住画布左缘
4. 按目标高度重采样，合成模拟桌面预览
"""

import os
from pathlib import Path
from typing import List, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "桌宠收起态.jpg"
OUT_DIR = ROOT / "assets" / "桌宠"
HEIGHTS = [240, 320, 400]
HIDPI_HEIGHT = 640
SIDE = os.environ.get("PET_SIDE", "left")  # left 贴屏幕左缘，right 贴屏幕右缘
PREFIX = "常驻" if SIDE == "left" else "常驻右"


def load_rgb(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGB"), dtype=np.float32)


def background_mask(rgb: np.ndarray, threshold: float = 240.0) -> np.ndarray:
    """只把与画布边界连通的近白区域判为背景。"""
    near_white = np.all(rgb >= threshold, axis=2)
    labels, _ = ndimage.label(near_white)
    border_labels = set()
    for edge in (labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]):
        border_labels.update(int(v) for v in np.unique(edge) if v != 0)
    if not border_labels:
        return np.zeros_like(near_white, dtype=bool)
    return np.isin(labels, list(border_labels))


def cut_out(rgb: np.ndarray, bg: np.ndarray) -> Image.Image:
    """生成 alpha 并去掉边缘白边。"""
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    alpha = np.where(bg, 0.0, 1.0).astype(np.float32)

    # 贴着背景的那一圈按亮度给半透明，越亮越透
    band = ndimage.binary_dilation(bg, iterations=2) & ~bg
    soft = np.clip((246.0 - lum) / 26.0, 0.0, 1.0)
    alpha[band] = np.minimum(alpha[band], soft[band])

    # 反预乘：把混进来的白减掉
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb_fixed = np.clip((rgb - (1.0 - safe) * 255.0) / safe, 0, 255)

    rgba = np.dstack([rgb_fixed, alpha * 255.0]).astype(np.uint8)
    img = Image.fromarray(rgba, mode="RGBA")

    # alpha 轻微收缩加羽化，边缘更干净
    a = img.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
    img.putalpha(a)
    return img


def detect_wall_right_edge(img: Image.Image) -> Tuple[int, bool]:
    """找竖直浅灰条的右边界，返回裁切起点与是否用了回退值。"""
    rgba = np.array(img)
    alpha = rgba[:, :, 3]
    content = alpha > 8
    ys, xs = np.where(content)
    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())

    lum = rgba[:, :, :3].astype(np.float32) @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    column_rows = content[y0 : y1 + 1, :]
    height = y1 - y0 + 1

    ratio = column_rows.sum(axis=0) / height
    mean_lum = np.where(column_rows, lum[y0 : y1 + 1, :], 0).sum(axis=0) / np.maximum(column_rows.sum(axis=0), 1)

    # 浅灰竖条：几乎整列都是内容，且亮度高而平
    cand = (ratio > 0.9) & (mean_lum > 195) & (mean_lum < 250)
    runs = []
    start = None
    for x in range(x0, x1 + 1):
        if cand[x]:
            start = x if start is None else start
        elif start is not None:
            runs.append((start, x - 1))
            start = None
    if start is not None:
        runs.append((start, x1))

    runs = [r for r in runs if r[1] - r[0] >= 8]
    if not runs:
        fallback = x0 + max(4, int((x1 - x0) * 0.32))
        return fallback, True

    # 墙条应该在内容左半侧，取最靠右的那一段
    left_half = [r for r in runs if r[1] <= x0 + (x1 - x0) * 0.6] or runs
    start, end = max(left_half, key=lambda r: r[1])
    return end + 1, False


def resize_to_height(img: Image.Image, height: int) -> Image.Image:
    w, h = img.size
    width = max(1, round(w * height / h))
    return img.resize((width, height), Image.LANCZOS)


def make_preview(assets: List[Tuple[int, Image.Image]], out_path: Path) -> None:
    panel_w, panel_h = 800, 1080
    gap = 6
    canvas = Image.new("RGB", (panel_w * len(assets) + gap * (len(assets) - 1), panel_h), (32, 34, 38))

    for idx, (height, pet) in enumerate(assets):
        panel = Image.new("RGB", (panel_w, panel_h))
        draw = ImageDraw.Draw(panel)

        # 壁纸：竖向渐变
        top, bottom = (222, 231, 243), (245, 248, 252)
        for y in range(panel_h):
            t = y / (panel_h - 1)
            draw.line(
                [(0, y), (panel_w, y)],
                fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
            )

        # 示例窗口：让出宠物那一侧
        win = (150, 150, 780, 900) if SIDE == "left" else (20, 150, 650, 900)
        shadow = Image.new("RGBA", panel.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            (win[0] + 6, win[1] + 10, win[2] + 6, win[3] + 10), radius=14, fill=(90, 105, 125, 70)
        )
        panel = Image.alpha_composite(panel.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(10))).convert("RGB")
        draw = ImageDraw.Draw(panel)
        draw.rounded_rectangle(win, radius=14, fill=(255, 255, 255), outline=(205, 214, 226), width=2)
        draw.rounded_rectangle((win[0], win[1], win[2], win[1] + 38), radius=14, fill=(238, 242, 247))
        draw.rectangle((win[0], win[1] + 20, win[2], win[1] + 38), fill=(238, 242, 247))
        for i, color in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
            draw.ellipse((win[0] + 18 + i * 22, win[1] + 14, win[0] + 28 + i * 22, win[1] + 24), fill=color)
        draw.text((win[0] + 100, win[1] + 13), "thesis.docx", fill=(70, 80, 95))
        for line in range(12):
            y = win[1] + 70 + line * 46
            draw.rounded_rectangle((win[0] + 26, y, win[2] - 40 - (line % 3) * 60, y + 12), radius=6, fill=(226, 232, 240))

        # 宠物贴边，垂直居中
        y = (panel_h - pet.height) // 2
        x = 0 if SIDE == "left" else panel_w - pet.width
        panel.paste(pet, (x, y), pet)

        # 标注
        edge_cn = "left" if SIDE == "left" else "right"
        draw.text((16, 24), f"height {height}px", fill=(40, 48, 60))
        draw.text((16, 46), f"pet at screen {edge_cn} edge", fill=(90, 100, 115))
        if SIDE == "left":
            draw.line([(0, y - 12), (140, y - 12)], fill=(120, 140, 165), width=1)
        else:
            draw.line([(panel_w - 140, y - 12), (panel_w, y - 12)], fill=(120, 140, 165), width=1)

        canvas.paste(panel, (idx * (panel_w + gap), 0))

    canvas.save(out_path)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    rgb = load_rgb(SRC)
    bg = background_mask(rgb)
    print(f"白底占比：{bg.mean():.3f}")

    cut = cut_out(rgb, bg)
    alpha = np.array(cut.getchannel("A"))
    print(f"抠图后透明占比：{(alpha == 0).mean():.3f}")

    # 原画是「在墙后往右探头」：贴左边缘要镜像，贴右边缘用原方向
    if SIDE == "left":
        cut = cut.transpose(Image.FLIP_LEFT_RIGHT)

    rgba = np.array(cut)
    content = rgba[:, :, 3] > 8
    ys, xs = np.where(content)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    cropped = cut.crop(box)
    print(f"裁切后尺寸：{cropped.size}")

    outputs = []
    for h in HEIGHTS:
        img = resize_to_height(cropped, h)
        path = OUT_DIR / f"{PREFIX}-{h}.png"
        img.save(path)
        outputs.append((h, img))
        print(f"输出 {path.name}：{img.size}")

    hidpi = resize_to_height(cropped, HIDPI_HEIGHT)
    hidpi_path = OUT_DIR / f"{PREFIX}-320@2x.png"
    hidpi.save(hidpi_path)
    print(f"输出 {hidpi_path.name}：{hidpi.size}")

    suffix = "" if SIDE == "left" else "-右"
    preview_path = OUT_DIR / f"常驻态-三档预览{suffix}.png"
    make_preview(outputs, preview_path)
    print(f"输出 {preview_path.name}")

    # 自检
    for h, img in outputs:
        a = np.array(img.getchannel("A"))
        assert a[0, 0] == 0 and a[0, -1] == 0 and a[-1, 0] == 0 and a[-1, -1] == 0, "四角不透明"
        assert img.height == h, f"高度不对：{img.height} != {h}"
        left_col = a[:, 0]
        assert (left_col > 0).any(), "左缘没有内容，贴边失败"
        print(f"自检通过 {h}px：四角透明、左缘有内容、高度准确")


if __name__ == "__main__":
    main()
