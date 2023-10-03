from PIL import Image
import cv2
import math

outputWidth = 480
outputHeight = 360
fps = 30


outputFilePath = 'rawPixelsNative.txt'

# shamelessly ripped from https://github.com/Chion82/ASCII_bad_apple/blob/master/generate_ascii_art.py
def toChars(imagePath):

    with Image.open(imagePath) as image:
        # image_ascii = convert_image_to_ascii(image)
        convertedImage = image.resize((outputWidth, outputHeight)).convert('L')

        asChars = "".join([str(pixelValue//128) for pixelValue in list(convertedImage.getdata())])
        return "\n".join([asChars[pI: pI + outputWidth] for pI in range(0, len(asChars), outputWidth)])


vidcap = cv2.VideoCapture('video.mp4')
currentTime = 0

frameCount = int(vidcap.get(7))
videoLength = math.ceil(frameCount*1000/int(vidcap.get(5)))

with open(outputFilePath, 'w', encoding="utf-8") as outputFile:
    while currentTime <= videoLength:
        if currentTime!=0:outputFile.write('f')
        print('Generating ASCII frame at ' + str(currentTime))

        vidcap.set(0, currentTime)
        success, image = vidcap.read()
        if success:cv2.imwrite('output.jpg', image)

        outputFile.write(toChars('output.jpg'))
        currentTime = currentTime + 1000/fps
    outputFile.close()

print(frameCount) # 6572