import itertools
from PIL import Image
import numpy as np

variation44Imgs = [Image.fromarray(np.asarray([list(zip([255]*16, r)) for r in v], dtype=np.dtype('uint8'))) for v in list(itertools.product(list(itertools.product([0,255], repeat=4)), repeat=4))]

sheet = Image.new("LA", (1024,1024), (255,255))
for i,v in enumerate(variation44Imgs):
    sheet.paste(v, ((255-i%256)*4, (i//256)*4))
sheet.save("4x4PixelsInv.png")