--!strict

local BAC1_URL = "http://0x0.st/82R7.bac1"
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

type CellRenderingInfo = {
	t: number,
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


local function get_BAC1(): string
	if IN_GAME then
		local modem = assert(GetPartFromPort(1, 'Modem'), 'missing modem on port 1')
		local s = modem:GetAsync(BAC1_URL, true)
		if s:match("^{") then return buffer.tostring((JSONDecode :: any)(s)) end
		return s
	else
		local HttpService = game:GetService("HttpService")
		local s = HttpService:GetAsync(BAC1_URL, true)
		if s:match("^{") then return buffer.tostring(HttpService:JSONDecode(s)) end
		return s
	end
end

local function get_canvas(): Frame
	if IN_GAME then
		local screen = assert(GetPartFromPort(1, 'Screen'), 'missing screen on port 1')
		screen:ClearElements()
		return screen:GetCanvas()
	else
		return (script :: any).Parent.SurfaceGui.Canvas
	end
end


local function cellState_to_offset(s: number): (Vector2)
	return Vector2.new(s%256 * 4, s//256 * 4)
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

	table.sort(frames, function(l, r)
		return l.id < r.id
	end)

	return metadata, frames
end

local function initializeCells(metadata: BAC1Metadata, canvas: Frame): {{ImageLabel}}
	local container = Instance.new('Frame')
	container.BorderSizePixel = 0
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromOffset(metadata.width_in_chunks*4, metadata.height_in_chunks*4)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.AnchorPoint = Vector2.one * 0.5
	container.Parent = canvas

	local cellTemplate = Instance.new('ImageLabel')
	cellTemplate.BackgroundColor3 = Color3.new()
	cellTemplate.BorderSizePixel = 0
	cellTemplate.Image = "rbxassetid://14750789446"
	cellTemplate.ImageRectSize = Vector2.new(4, 4)
	cellTemplate.ResampleMode = Enum.ResamplerMode.Pixelated
	cellTemplate.Rotation = 180 -- I have no idea lol
	cellTemplate.ScaleType = Enum.ScaleType.Stretch
	cellTemplate.Size = UDim2.fromOffset(4, 4)

	local cells: {{ImageLabel}} = {}
	for cY = 1, metadata.height_in_chunks do
		cells[cY] = {}
		for cX = 1, metadata.width_in_chunks do
			local cell = cellTemplate:Clone()
			cells[cY][cX] = cell

			cell.Position = UDim2.fromOffset((cX-1)*4, (cY-1)*4)
			cell.Parent = container
		end
	end

	return cells
end

local function convert_frames_to_rSortedCellInfo(
	metadata: BAC1Metadata, 
	frames: {IFrame|PFrame},
	cells: {{ImageLabel}}): {CellRenderingInfo}

	local cellInfos: {CellRenderingInfo} = {}
	local cellInfo_n = 0

	for _, frame in ipairs(frames) do
		local playhead = frame.id/metadata.fps

		if frame.type == 'I' then
			for cY, row in next, frame.chunks do
				for cX, cellState in next, row do
					cellInfo_n = cellInfo_n + 1
					cellInfos[cellInfo_n] = {
						t = playhead,
						o = cellState_to_offset(cellState),
						l = cells[cY][cX]
					}
				end
			end
		elseif frame.type == 'P' then
			for _, chunk in next, frame.chunks do
				cellInfo_n = cellInfo_n + 1
				cellInfos[cellInfo_n] = {
					t = playhead,
					o = cellState_to_offset(chunk.s),
					l = cells[chunk.p.Y][chunk.p.X]
				}
			end
		end
	end

	table.sort(cellInfos, function(l, r)
		return l.t > l.t
	end)

	return cellInfos
end

local function render(info: CellRenderingInfo, t1: number)
	task.wait(t1 - os.clock() + info.t)
	info.l.ImageRectOffset = info.o
end

local function deferRender(info: CellRenderingInfo, t1: number) task.spawn(render, info, t1) end

local metadata, frames = readFile(get_BAC1())
local cells = initializeCells(metadata, get_canvas())
local cellInfos = convert_frames_to_rSortedCellInfo(metadata, frames, cells)

local syncEnd = os.clock() + 15
print("synchronizing, window " .. syncEnd - os.clock())

for i , cellInfo in ipairs(cellInfos) do
	deferRender(cellInfo, syncEnd)
	if i%5000 == 0 then 
		print(("%8.4f %6i"):format(syncEnd - os.clock(), i)) 
		task.wait()
	end
end

print("synchronize end")
