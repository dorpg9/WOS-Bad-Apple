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


@jit(nopython=True)
def dither_floyd(_image: np.ndarray) -> np.ndarray:
	image = _image.astype(np.float32)
	h, w = image.shape

	for y in range(h-1):
		for x in range(1, w-1):
			old = image[y, x]
			new = 255.0 if old > 127.0 else 0.0
			image[y, x] = new
			error = old - new

			image[  y, x+1] += error * 0.4375
			image[y+1, x-1] += error * 0.1875
			image[y+1,   x] += error * 0.3125
			image[y+1, x+1] += error * 0.0625

	return (image > 127.0).astype(np.uint8)

def dither_bayer4(image: np.ndarray) -> np.ndarray:
	bayer4 = np.array([
		[ 0,  8,  2, 10],
		[12,  4, 14,  6],
		[ 3, 11,  1,  9],
		[15,  7, 13,  5]
	], dtype=np.uint8)

	h, w = image.shape
	t_map = np.tile(bayer4, (h//4+1, w//4+1))[:h, :w]

	return image > t_map*16

@jit(nopython=True)
def dither_atkinson(_image: np.ndarray) -> np.ndarray:
	image = _image.astype(np.float32)
	h, w = image.shape

	for y in range(h-2):
		for x in range(1, w-2):
			old = image[y, x]
			new = 255.0 if old > 127.0 else 0.0
			image[y, x] = new
			error = (old - new)/8.0

			image[  y, x+1] += error
			image[  y, x+2] += error
			image[y+1, x-1] += error
			image[y+1,   x] += error
			image[y+1, x+1] += error
			image[y+2,   x] += error

	return (image > 127.0).astype(np.uint8)

def encodeVideo(
		_video_path: str,
		_t_width: int,
		_t_height: int,
		_t_fps: int,
		_do_interleave: bool,
		_do_dither: str) -> bytes:
	
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
		boolFrame = grayscaledFrame > 127

		if _do_dither == "atkinson":
			boolFrame = dither_atkinson(grayscaledFrame)
		elif _do_dither == "bayer4":
			boolFrame = dither_bayer4(grayscaledFrame)
		elif _do_dither == "floyd":
			boolFrame = dither_floyd(grayscaledFrame)
		
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
	argParser.add_argument("-D", "--dithering", help="Whether or not to do dithering (kinda bad atm)", choices=["none", "bayer4", "floyd", "atkinson"], default="none", type=str, required=False)

	args = argParser.parse_args()

	encodedBytes = encodeVideo(
		args.input, args.width, args.height, args.fps, args.do_interleave, args.dithering)

	with open(args.output, 'wb') as f:
		f.write(encodedBytes)

if __name__ == "__main__":
    main()