import cv2
import numpy as np
import math

VIDEO_PATH = 'video.mp4'
TARGET_WIDTH = 512
TARGET_HEIGHT = 384
TARGET_FPS = 30

CHUNK_TYPES = {
	"P-FRAME": b'\x00',
	"I-FRAME": b'\x01'
}


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
	
	# nonzero gets the indices of non zero elements as ([x0, x1, ...], [y0, y1, ...])
	diff_flatCoords = np.nonzero(hasDiff.flatten())[0].astype(np.uint16)
	chunk_flatCoords = r_chunkArray.flatten()[diff_flatCoords]

	stacked_flatCoords = np.stack((diff_flatCoords, chunk_flatCoords), axis=1)

	return stacked_flatCoords



def formatFileChunk(cType: bytes, data: bytes)-> bytes:
	return cType + len(data).to_bytes(4, 'little') + data



videoCap = cv2.VideoCapture(VIDEO_PATH)

fps = videoCap.get(cv2.CAP_PROP_FPS)
frameCount = videoCap.get(cv2.CAP_PROP_FRAME_COUNT)
videoLength_ms = math.ceil(frameCount/fps*1000)

outputBuffer = bytearray()
last_frameChunks = None

_lastOutput = 0

playhead_ms = 0
while playhead_ms <= videoLength_ms and videoCap.isOpened():
	videoCap.set(cv2.CAP_PROP_POS_MSEC, playhead_ms)
	(frameRead, frame) = videoCap.read()

	playhead_ms += 1000/TARGET_FPS

	if not frameRead: break
	frame = cv2.resize(frame, (TARGET_WIDTH, TARGET_HEIGHT), interpolation=cv2.INTER_NEAREST)

	(_, binaryFrame) = cv2.threshold(cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), 127, 255, cv2.THRESH_BINARY)
	boolFrame = (binaryFrame > 0)

	frameBitMatrix = np.array(boolFrame, np.uint8)
	chunkArray = frameBitArray_to_chunkArray(frameBitMatrix)

	if last_frameChunks is None:
		outputBuffer += formatFileChunk(CHUNK_TYPES['I-FRAME'], chunkArray.tobytes())
	else:
		outputBuffer += formatFileChunk(CHUNK_TYPES['P-FRAME'], compare_chunkDiffFlatArray(last_frameChunks, chunkArray).tobytes())

	last_frameChunks = chunkArray
	
	if (playhead_ms - _lastOutput) > 1000:
		print(playhead_ms)
		_lastOutput = playhead_ms
	

with open('bad_apple.bac1', 'wb') as f:
    f.write(outputBuffer)