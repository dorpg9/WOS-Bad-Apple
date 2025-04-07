import cv2
import numpy as np
from numba import jit
import math

VIDEO_PATH = 'video.mp4'
TARGET_WIDTH = 512
TARGET_HEIGHT = 384
TARGET_FPS = 30

CHUNK_TYPES = {
	"P-FRAME": b'\1',
	"I-FRAME": b'\0'
}

def interleave_bytes(bytes: bytes, width: int) -> bytes:
	rotated = np.frombuffer(bytes, dtype=np.uint8).reshape(-1, width)
	return rotated.tobytes('F')

def frameBitArray_to_chunkArray(frameBitArray: np.ndarray) -> np.ndarray:
	height_p, width_p = frameBitArray.shape
	h_c, w_c = height_p // 4, width_p // 4

	groupedBitMatrixArray = frameBitArray.reshape(h_c, 4, w_c, 4).transpose(0, 2, 1, 3)
	flattened_bytePairArray = np.packbits(groupedBitMatrixArray.reshape(-1, 16), 1, 'little')

	flattened_mergedByteArray = (flattened_bytePairArray[:, 0].astype(np.uint16)
		| flattened_bytePairArray[:, 1].astype(np.uint16) << 8)

	return flattened_mergedByteArray.reshape(h_c, w_c)

def compare_chunkDiffFlatArray(l_chunkArray: np.ndarray, r_chunkArray: np.ndarray) -> np.ndarray:
	hasDiff = l_chunkArray != r_chunkArray

	mtxWidth: int = r_chunkArray.shape[1]
	
	# nonzero gets the indices of non zero elements as ([x0, x1, ...], [y0, y1, ...])
	diff_flatId = np.nonzero(hasDiff.flatten())[0].astype(np.uint32)
	chunk_flatCoords = r_chunkArray.flatten()[diff_flatId].astype(np.uint16)

	diff_flatCoords = (diff_flatId%mtxWidth + 1 + 256*(diff_flatId//mtxWidth + 1)).astype(np.uint16)

	stacked_flatCoords = np.stack((diff_flatCoords, chunk_flatCoords), axis=1).astype(np.uint16)

	return stacked_flatCoords

def getMetadata(vidcap: cv2.VideoCapture) -> bytes:
	return (b'BAC\x01'
		+ (TARGET_WIDTH//4).to_bytes(2, 'little')
		+ (TARGET_HEIGHT//4).to_bytes(2, 'little')
		+ TARGET_FPS.to_bytes(2, 'little')
		+ math.floor(vidcap.get(cv2.CAP_PROP_FRAME_COUNT) / vidcap.get(cv2.CAP_PROP_FPS) * TARGET_FPS).to_bytes(4, 'little')
		+ b'\0\0')

# [chunk_type: 1 byte][compression: 1 byte][length: 4 bytes][frame_id: 2 bytes][data: n bytes]

def makeFileChunk(cType: bytes, id: int, data: bytes)-> bytes:
	compression = b'\0'

	width = 2
	if cType == CHUNK_TYPES['P-FRAME']:
		width = 4

	interleaved = interleave_bytes(data, width)

	return (cType
		+ compression 
		+ len(interleaved).to_bytes(4, 'little') 
		+ id.to_bytes(2, 'little') 
		+ interleaved)

@jit
def dither(image):
    ret = (image > 127) * 255
    qError = image - ret
    height, width = ret.shape

    for y in range(0, height-1):
        for x in range(1, width-1):
            ret[y][x+1] = 	ret[y][x+1] + 	(qError[y][x] 		* 7/16)
            ret[y+1][x-1] = ret[y+1][x-1] + (qError[y+1][x-1] 	* 3/16)
            ret[y+1][x] = 	ret[y+1][x]+ 	(qError[y+1][x] 	* 5/16)
            ret[y+1][x+1] = ret[y+1][x+1] + (qError[y+1][x-1] 	* 1/16)

    return (ret > 127)


videoCap = cv2.VideoCapture(VIDEO_PATH)

fps = videoCap.get(cv2.CAP_PROP_FPS)
frameCount = videoCap.get(cv2.CAP_PROP_FRAME_COUNT)
videoLength_ms = math.ceil(frameCount/fps*1000)

outputBuffer = bytearray()
last_frameChunks = None
last_frameId = 1

_lastOutput = 0

playhead_ms = 0
while playhead_ms <= videoLength_ms and videoCap.isOpened():
	videoCap.set(cv2.CAP_PROP_POS_MSEC, playhead_ms)
	(frameRead, frame) = videoCap.read()

	playhead_ms += 1000/TARGET_FPS

	if not frameRead: break
	frame = cv2.resize(frame, (TARGET_WIDTH, TARGET_HEIGHT), interpolation=cv2.INTER_NEAREST)

	binaryFrame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
	boolFrame = dither(binaryFrame)

	frameBitMatrix = np.array(boolFrame, np.uint8)
	chunkArray = frameBitArray_to_chunkArray(frameBitMatrix)

	if last_frameChunks is None:
		outputBuffer += makeFileChunk(CHUNK_TYPES['I-FRAME'], last_frameId, chunkArray.tobytes())
	else:
		outputBuffer += makeFileChunk(CHUNK_TYPES['P-FRAME'], last_frameId,
			compare_chunkDiffFlatArray(last_frameChunks, chunkArray).tobytes())

	last_frameChunks = chunkArray
	last_frameId = last_frameId + 1
	
	if (playhead_ms - _lastOutput) > 1000:
		print(playhead_ms)
		_lastOutput = playhead_ms



with open('bad_apple.bac1', 'wb') as f:
    f.write(getMetadata(videoCap) + outputBuffer + b'\x7f\0\0\0\0\0\0\0')