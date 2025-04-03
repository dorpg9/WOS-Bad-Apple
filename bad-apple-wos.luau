--!strict

local repr = require("repr")


type IFrame = {type: 'I', chunks: {{number}}}
type PFrame = {type: 'P', chunks: {{p: Vector2, s: number}}}

type BAC1Metadata = {
	width_in_chunks: number;
	height_in_chunks: number;
	fps: number;
	frame_count: number;
}

local CHUNK_TYPES: {'I'|'P'} = {
	[0] = 'I';
	[1] = 'P';
}

-- [chunk_type: 1 byte][compression: 1 byte][length: 4 bytes][padding: 2 bytes][data: n bytes]
local function readFrame(b: buffer, o: number, metadata: BAC1Metadata): (number, IFrame|PFrame)
	local frameType: 'I'|'P' = CHUNK_TYPES[buffer.readu8(b, o)]

	assert(frameType, ("unknown frameType %i"):format(buffer.readu8(b, o)))

	-- local compression = buffer.readu8(b, o + 1)
	local dataLength = buffer.readu32(b, o + 2)
	local interleavedData = buffer.readstring(b, o + 8, dataLength)

	local interleaveWidth = frameType == 'I' and 2 or 4
	local chunkCount = dataLength/interleaveWidth

	local untangledData = table.create(chunkCount, "")
	for i = 1, dataLength do
		local si = (i//interleaveWidth)*chunkCount + i%interleaveWidth
		untangledData[(i - 1)%interleaveWidth + 1] = interleavedData:sub(si, si)
	end

	if frameType == 'I' then
		local chunks: {{number}} = {}

		assert(metadata.height_in_chunks*metadata.width_in_chunks == chunkCount,
			("I-Frame chunk count mismatch, read %i"):format(chunkCount))
		
		for cY = 1, metadata.height_in_chunks do
			chunks[cY] = {}
			for cX = 1, metadata.width_in_chunks do
				local flatChunkI = (cY - 1) * metadata.height_in_chunks + cX
				chunks[cY][cX] = ("<I2"):unpack(untangledData[flatChunkI])
			end
		end

		return o + 8 + dataLength, {type = 'I', chunks = chunks}
	else
		local chunks: {{p: Vector2, s: number}} = {}

		for _, chunkData in next, untangledData do
			local cY: number, cX: number, chunk: number = ("<I1I1I2"):unpack(chunkData)
			chunks[#chunks + 1] = {p = Vector2.new(cX, cY), s = chunk}
		end

		return o + 8 + dataLength, {type = 'P', chunks = chunks}
	end
end