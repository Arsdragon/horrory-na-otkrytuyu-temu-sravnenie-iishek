import sys, glob, os
from PIL import Image, ImageDraw
files = sys.argv[2:] or sorted(glob.glob("shots/*.png"))
out = sys.argv[1]
W = 640
ims = []
for f in files:
    im = Image.open(f).convert("RGB")
    im = im.resize((W, int(im.height * W / im.width)))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 200, 18), fill=(0, 0, 0))
    d.text((4, 3), os.path.basename(f), fill=(255, 255, 0))
    ims.append(im)
cols = 2
rows = (len(ims) + cols - 1) // cols
H = ims[0].height
sheet = Image.new("RGB", (W * cols, H * rows))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols) * W, (i // cols) * H))
sheet.save(out)
