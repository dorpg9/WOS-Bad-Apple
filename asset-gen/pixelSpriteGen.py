from PIL import Image

sheet = Image.new("RGBA", (1024,1024), (255, 255, 255, 0))
for chunk in range(65536):
    imageRectOffset_x = chunk%256*4
    imageRectOffset_y = chunk//256*4

    for bI in range(16):
        cX, cY = bI%4, bI//4
        sheet.putpixel((imageRectOffset_x + cX, imageRectOffset_y + cY), (255, 255, 255, ((chunk >> bI) & 1)* 255))

sheet.save("4x4PixelsLittle.png", format="PNG")