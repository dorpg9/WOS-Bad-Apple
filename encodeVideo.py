import cv2
import numpy as np
from numba import jit
import math
import argparse

VIDEO_PATH = 'video.mp4'
OUTPUT_PATH = 'bad_apple.bac1'
TARGET_WIDTH = 512
TARGET_HEIGHT = 384
TARGET_FPS = 30


CHUNK_TYPES = {
	"P-FRAME": b'\1',
	"I-FRAME": b'\0'
}

def interleave_bytes(bytes: bytes, width: int) -> bytes:
	if width == 0: return bytes
	rotated = np.frombuffer(bytes, dtype=np.uint8).reshape(-1, width)
	return rotated.tobytes('F')

@jit
def frameBitArray_to_chunkArray(frameBitArray: np.ndarray) -> np.ndarray:
	height_p, width_p = frameBitArray.shape
	h_c, w_c = height_p // 4, width_p // 4

	groupedBitMatrixArray = frameBitArray.reshape(h_c, 4, w_c, 4).transpose(0, 2, 1, 3)
	chunkBitArray = groupedBitMatrixArray.flatten().reshape(-1, 16) 

	chunkN = chunkBitArray.shape[0]
	flattened_mergedByteArray = np.zeros(chunkN, dtype=np.uint16)

	for chunkI in range(chunkN):
		chunk = np.uint16(0)
		for i in range(16):
			chunk |= np.uint16(chunkBitArray[chunkI, i]) << i
		flattened_mergedByteArray[chunkI] = chunk

	return flattened_mergedByteArray.reshape(h_c, w_c)

@jit
def compare_chunkDiffFlatArray(l_chunkArray: np.ndarray, r_chunkArray: np.ndarray) -> np.ndarray:
	hasDiff = l_chunkArray != r_chunkArray

	mtxWidth: int = r_chunkArray.shape[1]
	
	# nonzero gets the indices of non zero elements as ([x0, x1, ...], [y0, y1, ...])
	diff_flatId = np.nonzero(hasDiff.flatten())[0].astype(np.uint32)
	chunk_flatCoords = r_chunkArray.flatten()[diff_flatId].astype(np.uint16)

	diff_flatCoords = (diff_flatId%mtxWidth + 1 + 256*(diff_flatId//mtxWidth + 1)).astype(np.uint16)

	stacked_flatCoords = np.stack((diff_flatCoords, chunk_flatCoords), axis=1).astype(np.uint16)

	return stacked_flatCoords

def getMetadata(vidcap: cv2.VideoCapture, w: int, h: int, fps: int) -> bytes:
	return (b'BAC\x01'
		+ (w//4).to_bytes(2, 'little')
		+ (h//4).to_bytes(2, 'little')
		+ fps.to_bytes(2, 'little')
		+ math.floor(vidcap.get(cv2.CAP_PROP_FRAME_COUNT) / vidcap.get(cv2.CAP_PROP_FPS) * fps).to_bytes(4, 'little')
		+ b'\0\0')

# [chunk_type: 1 byte][compression: 1 byte][length: 4 bytes][frame_id: 2 bytes][data: n bytes]

def makeFileChunk(cType: bytes, id: int, _data: bytes, doInterleave: bool)-> bytes:
	compression = b'\0'
	data = _data

	if doInterleave:
		compression = b'\x10'

		width = 2
		if cType == CHUNK_TYPES['P-FRAME']:
			width = 4

		data = interleave_bytes(_data, width)

	return (cType
		+ compression 
		+ len(data).to_bytes(4, 'little') 
		+ id.to_bytes(2, 'little') 
		+ data)

@jit
def dither(image):
    ret = (image > 127) * 255
    qError = image - ret
    height, width = ret.shape

    for y in range(0, height-1):
        for x in range(1, width-1):
            ret[y][x+1] = 	ret[y][x+1] + 	(qError[y][x+1] 	* 7/16)
            ret[y+1][x-1] = ret[y+1][x-1] + (qError[y+1][x-1] 	* 3/16)
            ret[y+1][x] = 	ret[y+1][x]+ 	(qError[y+1][x] 	* 5/16)
            ret[y+1][x+1] = ret[y+1][x+1] + (qError[y+1][x-1] 	* 1/16)

    return ret > 127

def encodeVideo(
		_video_path: str,
		_t_width: int,
		_t_height: int,
		_t_fps: int,
		_do_interleave: bool,
		_do_dither: bool) -> bytes:
	
	videoCap = cv2.VideoCapture(_video_path)

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

		playhead_ms += 1000/_t_fps

		if not frameRead: break
		frame = cv2.resize(frame, (_t_width, _t_height), interpolation=cv2.INTER_NEAREST)

		grayscaledFrame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
		boolFrame = dither(grayscaledFrame) if _do_dither else (grayscaledFrame > 127)

		frameBitMatrix = np.array(boolFrame, np.uint8)
		chunkArray = frameBitArray_to_chunkArray(frameBitMatrix)

		if last_frameChunks is None:
			outputBuffer += makeFileChunk(CHUNK_TYPES['I-FRAME'], last_frameId, chunkArray.tobytes(), _do_interleave)
		else:
			outputBuffer += makeFileChunk(CHUNK_TYPES['P-FRAME'], last_frameId,
				compare_chunkDiffFlatArray(last_frameChunks, chunkArray).tobytes(), _do_interleave)

		last_frameChunks = chunkArray
		last_frameId = last_frameId + 1
		
		if (playhead_ms - _lastOutput) > 1000:
			print(playhead_ms)
			_lastOutput = playhead_ms
	
	return getMetadata(videoCap, _t_width, _t_height, _t_fps) + outputBuffer + b'\x7f\0\0\0\0\0\0\0'

def main():
	argParser = argparse.ArgumentParser(description="""Bifurcated-Alias-Container-01 encoder""", epilog="(c) 2025 dorpg ♥")
	argParser.add_argument("input", help="Input file path", type=str)
	argParser.add_argument("-o", "--output", help="Output file path", default=OUTPUT_PATH, type=str)
	argParser.add_argument("-W", "--width", help="Target width", default=TARGET_WIDTH, type=int)
	argParser.add_argument("-H", "--height", help="Target height", default=TARGET_HEIGHT, type=int)
	argParser.add_argument("-F", "--fps", help="Target frames per second", default=TARGET_FPS, type=int)
	argParser.add_argument("-L", "--do_interleave", help="Whether to enable byte interleave", action='store_true')
	argParser.add_argument("-D", "--do_dithering", help="Whether or not to do dithering (kinda bad atm)", action="store_true")

	args = argParser.parse_args()

	encodedBytes = encodeVideo(
		args.input, args.width, args.height, args.fps, args.do_interleave, args.do_dithering)

	with open(args.output, 'wb') as f:
		f.write(encodedBytes)

if __name__ == "__main__":
    main()