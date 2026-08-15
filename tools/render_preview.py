#!/usr/bin/env python3
"""개발용: Godot이 뽑아준 그리기 명령(JSON)을 PNG로 그려본다.
   화면 없는 서버에서 방 배치를 눈으로 확인하려고 만든 도구.
   사용법:  godot --headless -- --dump  &&  python3 tools/render_preview.py
"""
import json, math, os, sys, glob
from PIL import Image, ImageChops, ImageDraw

S = 2  # 2배로 그린 뒤 줄여서 계단현상 완화
W, H = 1280 * S, 720 * S


_IMG_CACHE = {}


def _load_dino(name):
    if name not in _IMG_CACHE:
        p = os.path.join("assets", "dinos", name)
        _IMG_CACHE[name] = Image.open(p).convert("RGBA") if os.path.exists(p) else None
    return _IMG_CACHE[name]


def _paste_img(base, c, pts, col):
    """공룡 그림 붙이기. 좌우가 뒤집힌 경우(x0 > x1)도 처리."""
    src = _load_dino(c.get("src", ""))
    if src is None:
        return
    (x0, y0), (x1, y1) = pts
    flip = x0 > x1
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    w, h = max(1, int(round(x1 - x0))), max(1, int(round(y1 - y0)))
    im = src.resize((w, h), Image.LANCZOS)
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if col != (255, 255, 255, 255):
        # Godot 의 modulate 와 같게: 채널별 곱하기 (알파도 함께)
        im = ImageChops.multiply(im, Image.new("RGBA", im.size, tuple(col)))
    base.alpha_composite(im, (int(round(x0)), int(round(y0))))


def blend(base, cmds):
    bw, bh = base.size
    for c in cmds:
        col = tuple(c["c"])
        pts = [(x * S, y * S) for x, y in c["p"]]
        if len(pts) < 2:
            continue
        if c["t"] == "img":
            _paste_img(base, c, pts, col)
            continue
        if col[3] >= 255:
            d = ImageDraw.Draw(base)
            _paint(d, c, pts, col)
        else:
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            pad = int(c.get("w", 2) * S) + 4
            box = (max(0, int(min(xs)) - pad), max(0, int(min(ys)) - pad),
                   min(bw, int(max(xs)) + pad), min(bh, int(max(ys)) + pad))
            if box[2] <= box[0] or box[3] <= box[1]:
                continue
            layer = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
            d = ImageDraw.Draw(layer)
            off = [(x - box[0], y - box[1]) for x, y in pts]
            _paint(d, c, off, col)
            base.alpha_composite(layer, (box[0], box[1]))


def _paint(d, c, pts, col):
    if c["t"] == "poly":
        d.polygon(pts, fill=col)
    else:
        w = max(1, int(round(c.get("w", 1) * S)))
        d.line(pts, fill=col, width=w, joint="curve")
        r = w / 2.0
        if r > 1.5:
            for x, y in (pts[0], pts[-1]):
                d.ellipse([x - r, y - r, x + r, y + r], fill=col)


BG = (255, 209, 102, 255)  # ffd166


ICON_DINO = "trex.png"  # 런처 아이콘에 쓸 공룡


def make_icons():
    """안드로이드 런처 아이콘 (-> android_icons/*.png)

    assets/dinos/ 에 생성된 그림이 있으면 그걸 쓰고,
    없으면 preview/icon.json (손그림) 으로 만든다."""
    os.makedirs("android_icons", exist_ok=True)
    art = _load_dino(ICON_DINO)
    if art is not None:
        fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
        k = min(300 / art.size[0], 300 / art.size[1])
        im = art.resize((max(1, int(art.size[0] * k)), max(1, int(art.size[1] * k))), Image.LANCZOS)
        fg.alpha_composite(im, ((432 - im.size[0]) // 2, (432 - im.size[1]) // 2))
    else:
        src = "preview/icon.json"
        if not os.path.exists(src):
            return
        cmds = json.load(open(src, encoding="utf-8"))
        fg = Image.new("RGBA", (432 * S, 432 * S), (0, 0, 0, 0))
        blend(fg, cmds)
        fg = fg.resize((432, 432), Image.LANCZOS)
    fg.save("android_icons/adaptive_fore_432.png")
    Image.new("RGBA", (432, 432), BG).save("android_icons/adaptive_back_432.png")

    # 구형 런처용: 둥근 사각 배경 + 공룡
    legacy = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    ImageDraw.Draw(legacy).rounded_rectangle([12, 12, 419, 419], radius=86, fill=BG)
    legacy.alpha_composite(fg)
    legacy.resize((192, 192), Image.LANCZOS).save("android_icons/launcher_main_192.png")
    print("android_icons/ 아이콘 3개 생성")


def main():
    make_icons()
    files = sorted(f for f in glob.glob("preview/*.json") if not f.endswith("icon.json"))
    if not files:
        print("preview/*.json 이 없습니다. 먼저: godot --headless -- --dump")
        return 1
    for f in files:
        cmds = json.load(open(f, encoding="utf-8"))
        img = Image.new("RGBA", (W, H), (255, 255, 255, 255))
        blend(img, cmds)
        out = f.replace(".json", ".png")
        img.resize((1280, 720), Image.LANCZOS).convert("RGB").save(out)
        print(out, len(cmds), "commands")
    return 0


if __name__ == "__main__":
    sys.exit(main())
