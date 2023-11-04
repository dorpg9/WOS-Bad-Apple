from math import *
from json import dumps
import numpy as np
import time
import os
import inputimeout
import base64
import requests
import zlib
import re
import codecs

width = 480
height = 360
fps = 30
frameCount = 6573
tpc = time.perf_counter
byteorder='big'

overwrite = False

inputFilePath = "rawPixelsNative.txt" # black is 0, init state
uncompressedBufferFilePath = "uncompressedNative.bacf" # buffer file for uncompressed data
referenceFrameFilePath = "referenceFrames.bacr" # unused

outputFilePath = 'BadApple!.bacs' # thy end is now
allStringPath = 'allString.lua'

widthInChunks = ceil(width/4)
heightInChunks = ceil(height/4)

ESCAPE_SEQUENCE_RE = re.compile(r'''
    ( \\U........      # 8-digit hex escapes
    | \\u....          # 4-digit hex escapes
    | \\x..            # 2-digit hex escapes
    | \\[0-7]{1,3}     # Octal escapes
    | \\N\{[^}]+\}     # Unicode characters by name
    | \\[\\'"abfnrtv]  # Single-character escapes
    )''', re.UNICODE | re.VERBOSE)

def DecodeEscapes(s):
    def decode_match(match):
        return codecs.decode(match.group(0), 'unicode-escape')

    return ESCAPE_SEQUENCE_RE.sub(decode_match, s)

def PaethNDArray(a:np.ndarray,b:np.ndarray,c:np.ndarray):
  p=a+b-c
  pa=np.absolute(a-p)
  pb=np.absolute(b-p)
  pc=np.absolute(c-p)

  return np.where(np.logical_and(pa<=pb,pa<=pc), a, np.where(pb<=pc, b, c))

def filter(currentScanline:np.ndarray, previousScanline:np.ndarray=np.zeros((2,widthInChunks))):
  xArray=np.asarray(currentScanline, dtype=">u1")
  aArray=np.roll(xArray,1,0); aArray[0]=0
  bArray=np.asarray(previousScanline, dtype=">u1")

  filteredArray=np.asarray([
    xArray,
    (xArray-aArray)&255,
    (xArray-bArray)&255,
  ],dtype="u1")
  
  method = int(np.argmax(np.count_nonzero(np.logical_or(filteredArray[:,:,0],filteredArray[:,:,1]),1)))
  filteredChunks=filteredArray[method]
  isNotZ = np.logical_or(filteredChunks[:,0],filteredChunks[:,1])
  nonZIndices:np.ndarray = np.ndarray.astype(*np.nonzero(isNotZ),dtype=">u2")
  nonZeroChunks:np.ndarray = filteredChunks[isNotZ]
  nonZeroChunks2B = np.frombuffer(nonZeroChunks,dtype=">u2")
  cBytes = np.rot90(np.stack((nonZeroChunks2B,nonZIndices),dtype=">u2"),3).tobytes('C')
  slWithMD = method.to_bytes(1,'big')+len(cBytes).to_bytes(2,byteorder='big')+cBytes
  return method, slWithMD

def prepFrameForCompression(frameArray):
  frameArrayDown1 = np.roll(frameArray, shift=1, axis=0); frameArrayDown1[0,:,:]=0

  (methodsZ,resultFrameZ) = zip(*[filter(cSl,pSl) for (cSl,pSl) in zip(frameArray,frameArrayDown1)])
  methods = np.array(methodsZ,dtype=np.uint8)

  resultFrame = b''.join(resultFrameZ)
  if methods.min()==0 and len(resultFrame)==270:
    frameWithMD = b"\00\00"
  else:
    frameWithMD = bytearray(len(resultFrame).to_bytes(2,byteorder='big')+bytes(resultFrame))
  return frameWithMD

def getUncompressedData():
  if not os.path.isfile(uncompressedBufferFilePath) or overwrite:
    with open(inputFilePath, "r", encoding="utf-8") as inputFile:
      with open(uncompressedBufferFilePath, "wb") as outputFile: outputFile.close()

      readString = inputFile.read((width+1)*height)
      storedFrameBytes = np.zeros((90,120,2),'u1')
      frameI = 0

      while readString:
        sTime = time.perf_counter()

        pixels = np.asarray(list(readString.translate({10:None,102:None})),dtype='u1').reshape((heightInChunks,4,widthInChunks,4)).swapaxes(1,2)
        frameBytes=np.packbits(pixels.reshape((heightInChunks,widthInChunks,16)),axis=-1)
        
        filteredFrame = prepFrameForCompression(np.bitwise_xor(frameBytes,storedFrameBytes))
        storedFrameBytes=frameBytes

        with open(uncompressedBufferFilePath, "ab") as uncompressedBufferFile:
          uncompressedBufferFile.write(frameI.to_bytes(2,'big')+filteredFrame)
          uncompressedBufferFile.close()
        if frameI%15==0:
          print(f"> {str(frameI).rjust(4)} - {str(frameI//fps//60).rjust(2)}:{str(frameI//fps%60).rjust(2)} --- {str(len(filteredFrame))}")
          print(f"> Time taken for 1 frame: {str(time.perf_counter()-sTime)}")
        # sTime=time.perf_counter()
        # +' -- t: '+str(time.perf_counter())
        readString = inputFile.read((width+1)*height)
        frameI+=1
      inputFile.close()
  return

def bacfCompress(bacfPath:str, bacrPath:str):
  # outputFile.write(bytearray([width//256, width%256, height//256, height%256, frameCount//65536, (frameCount%65536)//256, frameCount%256, fps]))
  bacfFileSize = os.path.getsize(bacfPath)-1
  with open(bacfPath, "rb") as bacfFile:

    frameDatas=[]

    while bacfFile.tell()<bacfFileSize:
      frameI,frameLength= bacfFile.read(2),bacfFile.read(2)
      
      frameDatas.append(frameI+frameLength+bacfFile.read(int.from_bytes(frameLength,byteorder='big')))
    bacfFile.close()
  
  print(max([len(f) for f in frameDatas]))
  with open(outputFilePath, 'wb') as outputFile:
    outputFile.write(bytearray([width//256, width%256, height//256, height%256, frameCount//65536, (frameCount%65536)//256, frameCount%256, fps]))
    outputFile.close()

  for i in range(ceil(len(frameDatas)/100)):
    k = (i*100+100>frameCount) and frameCount or i*100+100
    compressed = zlib.compress(bytearray().join(frameDatas[i*100:k]),8)
    toWrite=bytearray(len(compressed).to_bytes(4, "big").ljust(4))+bytearray(compressed)
    with open(outputFilePath, 'ab') as outputFile:
      outputFile.write(toWrite)
      outputFile.close()
    if i%5==0: print(f"> Output Writing: {i!s}")
  return

getUncompressedData()

bHead = b'''local function fileStringGet(...)local payloadString = string.gsub(\"'''
bTail = b"\",'..',function (cc)return string.char(tonumber(cc, 16))end)return payloadString end"

insertFile =[ "BadApple!-WOS.lua"]
aSPath = "allString.lua"

with open(aSPath,"wb") as aSFile,open(outputFilePath,'rb') as bacsFile:
  aSFile.write(bHead)

  while True:
    toWrite = bacsFile.read(49600)
    if not toWrite: break
    aSFile.write(toWrite.hex().encode(encoding='utf-8'))
  aSFile.write(bTail)

  aSFile.close();bacsFile.close()

dataPath = aSPath

if insertFile:
  for fName in insertFile:
    toInsert = open(aSPath,"r").read()
    contents = open(fName, 'r+').readlines()

    contents[3] = toInsert + "\n"
    open('Packed-'+fName,'w').writelines(contents)
    dataPath = "Packed-"+fName

# shutil.copyfile(os.path.realpath(outputFilePath),os.path.abspath(allStringClonePath))
# response = requests.post('https://0x0.st', files={"file":open('allString.lua', 'rb')})