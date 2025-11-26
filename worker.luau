--!strict
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
	chunks: {{p: number, s: number}}
}

type CellRenderingInfo = {
	o: Vector2,
	l: ImageLabel
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

local function readFrame(b: buffer, o: number, metadata: BAC1Metadata)
	local frameType: 'I'|'P' = CHUNK_TYPES[buffer.readu8(b, o)]

	assert(frameType, ("unknown frameType %i at %i"):format(buffer.readu8(b, o), o))

	local compression = buffer.readu8(b, o + 1)
	local dataLength = buffer.readu32(b, o + 2)
	local frameId = buffer.readu16(b, o + 6)
	local unresolvedData = buffer.readstring(b, o + 8, dataLength)
	local unresolvedBuffer = buffer.fromstring(unresolvedData)

	local sizeof_chunk = frameType == 'I' and 2 or 4
	local chunkCount = dataLength/sizeof_chunk

	local untangledData: buffer
	if compression == 0x10 then
		-- local deInterleaved = table.create(chunkCount, "")
		-- for cI = 0, chunkCount - 1 do
		-- 	for bI = 0, sizeof_chunk - 1 do
		-- 		local si = bI * chunkCount + cI + 1
		-- 		deInterleaved[cI + 1] ..= unresolvedData:sub(si, si)
		-- 	end
		-- end

		-- untangledData = buffer.fromstring(table.concat(deInterleaved))

		local deinterleaved = buffer.create(dataLength)
		local byteI = 0

		for bI = 0, sizeof_chunk - 1 do
			local base = bI * chunkCount
			for cI = 0, chunkCount - 1 do
				buffer.writeu8(
					deinterleaved, 
					byteI, 
					buffer.readu8(unresolvedBuffer, base + cI)
				)
				byteI += 1
			end
		end
	else
		untangledData = buffer.fromstring(unresolvedData)
	end

	if frameType == 'I' then
		local chunks: {{number}} = {}

		assert(metadata.height_in_chunks*metadata.width_in_chunks == chunkCount,
			("I-Frame chunk count mismatch, read %i"):format(chunkCount))


		
		for cY = 1, metadata.height_in_chunks do
			chunks[cY] = {}
			for cX = 1, metadata.width_in_chunks do
				local flatChunkI = (cY - 1) * metadata.width_in_chunks + cX
				chunks[cY][cX] = buffer.readu16(untangledData, (flatChunkI - 1)*2)
			end
		end

		return o + 8 + dataLength, {
			type = 'I', 
			id = frameId, 
			count = chunkCount,
			chunks = chunks
		}
	else
		local chunks: {{p: number, s: number}} = {}

		local rowLength = metadata.width_in_chunks
		for chunkI = 1, chunkCount do
			local cX: number, cY: number, chunk: number = 
				buffer.readu8(untangledData, (chunkI - 1)*4),
				buffer.readu8(untangledData, (chunkI - 1)*4 + 1),
				buffer.readu16(untangledData, (chunkI - 1)*4 + 2)
			
			chunks[#chunks + 1] = {p = (cY - 1)*rowLength + (cX - 1), s = chunk}
		end

		return o + 8 + dataLength, {
			type = 'P', 
			id = frameId, 
			count = chunkCount,
			chunks = chunks
		} :: any
	end
end

local function convert_frame_to_rSortedCellInfo(
	metadata: BAC1Metadata, 
	frame: IFrame|PFrame,
	cells: {ImageLabel},
	workerCount: number)

	local Vec2 = Vector2.new
	
	local cellInfos: {CellRenderingInfo} = {}
	local cellInfo_n = 0

	if frame.type == 'I' then
		local rowLength = metadata.width_in_chunks
		for cY, row in next, frame.chunks do
			for cX, cellState in next, row do
				cellInfo_n = cellInfo_n + 1
				cellInfos[cellInfo_n] = {
					o = Vector2.new(cellState%256 * 4, cellState//256 * 4),
					l = cells[(cY - 1)*rowLength + (cX - 1)]
				}
			end
		end
	elseif frame.type == 'P' then
		for _, chunk in next, frame.chunks do
			cellInfo_n = cellInfo_n + 1
			cellInfos[cellInfo_n] = {
				o = 4 * Vec2(chunk.s%256, chunk.s//256),
				l = cells[chunk.p]
			}
		end
	end

	local distrubutedCellInfo: {{CellRenderingInfo}} = {}
	for i = 1, workerCount do
		distrubutedCellInfo[i] = {}
	end

	for i, cellInfo in ipairs(cellInfos) do
		local distributeTo = distrubutedCellInfo[i%workerCount + 1]
		distributeTo[#distributeTo + 1] = cellInfo
	end

	return distrubutedCellInfo
end

local actions = {

	renderFromInfo = function(infos: {CellRenderingInfo})
		for _, info in next, infos do
			info.l.ImageRectOffset = info.o
		end
	end,
	readFrame = readFrame,
	parent = function(parent: Instance, child: Instance)
		child.Parent = parent
	end,
	clone = function(toClone: Instance)
		return toClone:Clone()
	end,
	buildCellInfo = convert_frame_to_rSortedCellInfo
}

local function onReceive(source: Microcontroller, op: string, ...)
	source:Send(actions[op](...))
end

while true do
	onReceive(Microcontroller:Receive())
end