# -*- coding: utf-8 -*-
"""生成「易读」App 图标：靛蓝→紫渐变底 + 白色打开的书 + 文字线。
输出 iOS Asset Catalog 全部尺寸 + 安卓 mipmap 全部密度。"""
from PIL import Image, ImageDraw
import os

ROOT = r'F:/workbuyy GONGZUOKONGJIAN/禁漫改ios/origo-x'

# ---------- 画 1024 母版 ----------
S = 1024
img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# 1) 渐变底（对角：深靛蓝 → 紫），铺满整个方形（iOS 自行裁圆角）
c1 = (61, 78, 232)    # #3D4EE8 靛蓝
c2 = (140, 92, 246)   # #8C5CF6 紫
grad = Image.new('RGB', (S, S))
gd = ImageDraw.Draw(grad)
for y in range(S):
    for x0 in range(0, S, 64):
        t = (x0 + y) / (2 * S)
        r = int(c1[0] + (c2[0] - c1[0]) * t)
        g = int(c1[1] + (c2[1] - c1[1]) * t)
        b = int(c1[2] + (c2[2] - c1[2]) * t)
        gd.rectangle([x0, y, min(x0 + 64, S), y], fill=(r, g, b))
# 加速：用小图缩放代替逐像素
grad = grad.resize((S, S))
img.paste(grad, (0, 0))

# 叠加一点顶部高光，让渐变更有层次
hl = Image.new('RGBA', (S, S), (0, 0, 0, 0))
hd = ImageDraw.Draw(hl)
hd.ellipse([-S * 0.3, -S * 0.55, S * 1.3, S * 0.45], fill=(255, 255, 255, 26))
img = Image.alpha_composite(img, hl)

d = ImageDraw.Draw(img)

# 2) 打开的书：左右两页白色圆角矩形，中间留缝，底部对齐
page_w = 300
page_h = 380
gap = 26
cx = S // 2
top = 300
left_x = cx - gap // 2 - page_w
right_x = cx + gap // 2
r = 46

# 左页（轻微外旋用平行四边形模拟翻开的书）
d.rounded_rectangle([left_x, top, left_x + page_w, top + page_h], radius=r, fill=(255, 255, 255, 255))
# 右页
d.rounded_rectangle([right_x, top, right_x + page_w, top + page_h], radius=r, fill=(255, 255, 255, 255))
# 书脊中缝阴影
d.rectangle([cx - 4, top + 20, cx + 4, top + page_h - 20], fill=(210, 214, 240, 255))

# 3) 页面上的文字线（浅灰圆角条）
line_color = (198, 203, 232, 255)
for i in range(4):
    ly = top + 74 + i * 62
    lw = 190 if i < 3 else 130
    d.rounded_rectangle([left_x + 56, ly, left_x + 56 + lw, ly + 16], radius=8, fill=line_color)
    d.rounded_rectangle([right_x + 56, ly, right_x + 56 + lw, ly + 16], radius=8, fill=line_color)

# 4) 书下方一条「阅读进度」弧线，呼应产品是阅读器
arc_box = [cx - 150, top + page_h + 36, cx + 150, top + page_h + 236]
d.arc(arc_box, start=20, end=160, fill=(255, 255, 255, 235), width=26)

# 5) 顶部放一个小圆点（像灯泡/星星，易读的"易"）
d.ellipse([cx - 26, 190, cx + 26, 242], fill=(255, 214, 102, 255))

img.save(os.path.join(ROOT, 'icons_master_1024.png'))
print('母版生成: icons_master_1024.png')

# ---------- iOS 尺寸 ----------
ios_dir = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
ios_sizes = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}
for name, px in ios_sizes.items():
    img.resize((px, px), Image.LANCZOS).save(os.path.join(ios_dir, name))
print(f'iOS 图标 {len(ios_sizes)} 个已替换')

# ---------- 安卓 mipmap ----------
android_sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
for folder, px in android_sizes.items():
    dst = os.path.join(ROOT, 'android/app/src/main/res', folder)
    img.resize((px, px), Image.LANCZOS).save(os.path.join(dst, 'ic_launcher.png'))
# drawable-v21 遗留引用
img.resize((192, 192), Image.LANCZOS).save(
    os.path.join(ROOT, 'android/app/src/main/res/drawable-v21/ic_launcher.png'))
print(f'安卓图标 {len(android_sizes) + 1} 个已替换')
print('完成')
