"""Render the Android Play promo from existing branding and real UI captures."""

from pathlib import Path
import subprocess

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/play_store_assets/video"
FRAMES = OUT / "storyboard"
FRAMES.mkdir(parents=True, exist_ok=True)
SIZE = (1920, 1080)
WHITE, MUTED, TEAL, GOLD = "#f5f8fb", "#bfcedc", "#50d5ca", "#efc478"
FONT = Path("C:/Windows/Fonts")


def font(size, bold=False):
    return ImageFont.truetype(str(FONT / ("segoeuib.ttf" if bold else "segoeui.ttf")), size)


def base(kicker, count):
    im = Image.new("RGB", SIZE)
    d = ImageDraw.Draw(im)
    for y in range(1080):
        t = y / 1079
        d.line((0, y, 1920, y), fill=(int(8 + 5 * t), int(21 + 12 * t), int(36 + 16 * t)))
    d.text((110, 64), "DALI CAM", font=font(30, True), fill=TEAL)
    d.text((110, 124), kicker.upper(), font=font(23), fill=MUTED)
    d.line((110, 194, 250, 194), fill=GOLD, width=4)
    d.text((110, 1016), "Live photo coaching  /  On-device photo processing", font=font(22), fill=MUTED)
    d.text((1730, 1016), f"0{count} / 06", font=font(22), fill=GOLD)
    return im


def lines(im, text, xy, size=82, fill=WHITE, gap=8):
    d = ImageDraw.Draw(im)
    x, y = xy
    for line in text.split("\n"):
        d.text((x, y), line, font=font(size, True), fill=fill)
        y += size + gap


def copy(im, text, xy, size=32, fill=MUTED, gap=15):
    d = ImageDraw.Draw(im)
    x, y = xy
    for line in text.split("\n"):
        d.text((x, y), line, font=font(size), fill=fill)
        y += size + gap


def card(im, path, box, crop=None, contain=False):
    pic = Image.open(path).convert("RGB")
    if crop:
        pic = pic.crop(crop)
    x, y, w, h = box
    pic = ImageOps.pad(pic, (w, h), color="#080d12", method=Image.Resampling.LANCZOS) if contain else ImageOps.fit(pic, (w, h), method=Image.Resampling.LANCZOS)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((x-3, y-3, x+w+3, y+h+3), radius=20, fill="#3b5267")
    im.paste(pic, (x, y))


def save(im, name):
    im.save(FRAMES / name)


sample = ROOT / "apps/dali_camera/assets/catalog/landscape-mountain-valley.jpg"
icon = ROOT / "apps/dali_camera/ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
header = ROOT / "docs/app_store_assets/header/dali-cam-coaching-filter-beautifier-3840x1646.png"
ui = ROOT / "docs/play_store_assets/source"

im = base("Your personal camera coach", 1)
card(im, header, (0, 245, 1920, 823))
card(im, icon, (110, 36, 116, 116), contain=True)
ImageDraw.Draw(im).rectangle((240, 35, 1775, 194), fill="#081524")
lines(im, "Dali Cam", (265, 43), 76)
copy(im, "Compose with confidence.", (1070, 91), 38, WHITE)
save(im, "01-intro.png")

im = base("Coaching before the shutter", 2)
lines(im, "Find your frame.\nSteady your shot.", (110, 280), 86)
copy(im, "Live guidance for framing,\nhorizon, light, and steadiness.", (116, 530), 35)
copy(im, "Portraits  /  Landscapes  /  Food", (116, 750), 31, TEAL)
card(im, sample, (1190, 86, 540, 810))
copy(im, "Example reference image", (1225, 925), 24)
save(im, "02-coaching.png")

im = base("Camera controls", 3)
lines(im, "Take control\nof the moment.", (110, 280), 86)
copy(im, "Focus. Depth. Exposure.\nShape the shot on supported devices.", (116, 535), 34)
copy(im, "Real Android controls", (116, 753), 30, TEAL)
card(im, sample, (1040, 150, 480, 720))
card(im, OUT / "source/android-manual-rail.png", (1590, 150, 174, 720), contain=True)
copy(im, "Reference image", (1160, 905), 23)
copy(im, "Android UI", (1610, 905), 23)
save(im, "03-controls.png")

im = base("Photo review and editing", 4)
lines(im, "Finish it\nyour way.", (110, 280), 92)
copy(im, "Auto Enhance. Filters. Beautifier.\nCrop, rotate, and straighten.", (116, 545), 35)
copy(im, "Real Android interface", (116, 760), 30, TEAL)
card(im, ui / "android-photo-tools.png", (1265, 65, 470, 890), crop=(0, 107, 1080, 2154), contain=True)
save(im, "04-photo-tools.png")

im = base("Your photo. Your style.", 5)
lines(im, "Choose your\nfinishing touch.", (110, 280), 85)
copy(im, "Explore Auto and Custom looks.\nReview the details before saving.", (116, 535), 35)
copy(im, "Real Android interface", (116, 760), 30, TEAL)
card(im, ui / "android-filter.png", (1265, 65, 470, 890), crop=(0, 107, 1080, 2154), contain=True)
save(im, "05-filter.png")

im = base("Let the photo speak", 6)
card(im, icon, (110, 250, 145, 145), contain=True)
lines(im, "Dali Cam", (110, 430), 96)
lines(im, "Shoot with confidence.", (116, 570), 58, GOLD)
copy(im, "Compose. Capture. Refine.", (116, 685), 36)
copy(im, "dalifin.com", (116, 810), 30, TEAL)
card(im, sample, (1190, 86, 540, 810))
copy(im, "Example image imported for editing", (1165, 925), 23)
save(im, "06-outro.png")

# The 0.4-second dissolves align the scene changes with the existing narration.
durations = [3.8, 4.7, 5.5, 4.4, 4.1, 9.5]
offsets = [3.4, 7.7, 12.8, 16.8, 20.5]
cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "warning", "-filter_complex_threads", "2"]
for image, duration in zip(sorted(FRAMES.glob("*.png")), durations):
    cmd += ["-loop", "1", "-framerate", "30", "-t", str(duration), "-i", str(image)]
audio = OUT / "dali-cam-audiolab-voiceover.wav"
cmd += ["-i", str(audio)]
filters = [f"[{i}:v]format=yuv420p,setsar=1,settb=AVTB[v{i}]" for i in range(6)]
previous = "v0"
for i, offset in enumerate(offsets, 1):
    output = f"x{i}"
    filters.append(f"[{previous}][v{i}]xfade=transition=fade:duration=0.4:offset={offset}[{output}]")
    previous = output
filters.append(f"[{previous}]fade=t=in:st=0:d=0.3,fade=t=out:st=29.3:d=0.7[video]")
filters.append("[6:a]loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000,apad,afade=t=out:st=29:d=1[audio]")
video = OUT / "dali-cam-google-play-promo-audiolab-30s.mp4"
cmd += ["-filter_complex", ";".join(filters), "-map", "[video]", "-map", "[audio]", "-t", "30", "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", "-r", "30", "-c:a", "aac", "-b:a", "192k", "-ac", "2", "-movflags", "+faststart", str(video)]
subprocess.run(cmd, check=True)
print(video)
