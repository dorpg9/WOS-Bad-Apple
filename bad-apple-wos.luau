--!strict

local BAC1_URL = "http://0x0.st/82R4.bac1"
local IN_GAME: boolean = (GetPartFromPort :: any) ~= nil

type IFrame = {
	type: 'I', 
	id: number,
	count: number,
	chunks: {{number}}
}
type PFrame = {
	type: 'P', 
	id: number,
	count: number,
	chunks: {{p: Vector2, s: number}}
}

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


local function get_BAC1(): string
	if IN_GAME then
		local modem = assert(GetPartFromPort(1, 'Modem'), 'missing modem on port 1')
		return modem:GetAsync(BAC1_URL, true)
	else
		return game:GetService("HttpService"):GetAsync(BAC1_URL, true)
	end
end



-- [chunk_type: 1 byte][compression: 1 byte][length: 4 bytes][id: 2 bytes][data: n bytes]
local function readFrame(b: buffer, o: number, metadata: BAC1Metadata): (number, IFrame|PFrame)
	local frameType: 'I'|'P' = CHUNK_TYPES[buffer.readu8(b, o)]

	assert(frameType, ("unknown frameType %i"):format(buffer.readu8(b, o)))

	-- local compression = buffer.readu8(b, o + 1)
	local dataLength = buffer.readu32(b, o + 2)
	local frameId = buffer.readu16(b, o + 6)
	local interleavedData = buffer.readstring(b, o + 8, dataLength)

	local interleaveWidth = frameType == 'I' and 2 or 4
	local chunkCount = dataLength/interleaveWidth


	local untangledData = table.create(chunkCount, "")
	for cI = 0, chunkCount - 1 do
		for bI = 0, interleaveWidth - 1 do
			local si = bI * chunkCount + cI + 1
			untangledData[cI + 1] ..= interleavedData:sub(si, si)
		end
	end

	if frameType == 'I' then
		local chunks: {{number}} = {}

		assert(metadata.height_in_chunks*metadata.width_in_chunks == chunkCount,
			("I-Frame chunk count mismatch, read %i"):format(chunkCount))
		
		for cY = 1, metadata.height_in_chunks do
			chunks[cY] = {}
			for cX = 1, metadata.width_in_chunks do
				local flatChunkI = (cY - 1) * metadata.width_in_chunks + cX
				chunks[cY][cX] = ("<I2"):unpack(untangledData[flatChunkI])
			end
		end

		return o + 8 + dataLength, {
			type = 'I', 
			id = frameId, 
			count = chunkCount,
			chunks = chunks
		}
	else
		local chunks: {{p: Vector2, s: number}} = {}

		for _, chunkData in next, untangledData do
			local cX: number, cY: number, chunk: number = ("<I1I1I2"):unpack(chunkData)
			chunks[#chunks + 1] = {p = Vector2.new(cX, cY), s = chunk}
		end

		return o + 8 + dataLength, {
			type = 'P', 
			id = frameId, 
			count = chunkCount,
			chunks = chunks
		}
	end
end

local function readMetadata(b: buffer, o: number): (number, BAC1Metadata)
	assert(buffer.readstring(b, o, 4) == "BAC\1")

	return o + 16, {
		width_in_chunks = buffer.readu16(b, o + 4);
		height_in_chunks = buffer.readu16(b, o + 6);
		fps = buffer.readu16(b, o + 8);
		frame_count = buffer.readu32(b, o + 10);
	}
end

local function readFile(file: string): (BAC1Metadata, {IFrame | PFrame})
	local b, o = buffer.fromstring(file), 0

	local metadata
	o, metadata = readMetadata(b, o)

	local frames: {IFrame | PFrame} = {}

	while buffer.readstring(b, o, 8) ~= "\x7f\0\0\0\0\0\0\0" do
		local frame
		o, frame = readFrame(b, o, metadata)
		frames[frame.id] = frame
	end

	return metadata, frames
end

readFile(get_BAC1())