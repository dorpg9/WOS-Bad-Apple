--!strict

local BAC1_URL = "http://0x0.st/82Fq.zjson"
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
	o: Vector2,
	l: ImageLabel
}

type BAC1Metadata = {
	width_in_chunks: number;
	height_in_chunks: number;
	fps: number;
	frame_count: number;
}

local runWithWorkers: 
	(("readFrame", buffer, number, BAC1Metadata) -> (number, IFrame | PFrame))
	& (("renderFromInfo", {CellRenderingInfo}) -> ())
	& (("parent", Instance, Instance) -> ())
	& (("clone", Instance) -> (Instance))
	& (("buildCellInfo", BAC1Metadata, IFrame | PFrame, {{ImageLabel}}, number) -> ({{CellRenderingInfo}}))
local workerCount: number

do
	local workerMicros = GetPartsFromPort(65536, 'Microcontroller')
	for i, v in next, workerMicros do
		if v == Microcontroller then
			table.remove(workerMicros, i)
		end
	end

	workerCount = #workerMicros

	local freeWorkerI = 1
	function runWithWorkers(op, ...)
		workerMicros[freeWorkerI]:Send(op, ...)
		freeWorkerI += 1
		if freeWorkerI > #workerMicros then
			freeWorkerI = 1
		end

		return select(2, Microcontroller:Receive())
	end
end

local function get_BAC1(): (string)
	if IN_GAME then
		local modem = assert(GetPartFromPort(1, 'Modem'), 'missing modem on port 1')
		local s = modem:GetAsync(BAC1_URL, false)
		if s:match("^{") then return buffer.tostring((JSONDecode :: any)(s)) end
		return s
	else
		local HttpService = game:GetService("HttpService")
		local s = HttpService:GetAsync(BAC1_URL, false)
		if s:match("^{") then return buffer.tostring(HttpService:JSONDecode(s)) end
		return s
	end
end

local function get_canvas(): (Frame)
	if IN_GAME then
		local screen = assert(GetPartFromPort(1, 'Screen'), 'missing screen on port 1')
		screen:ClearElements()
		return screen:GetCanvas()
	else
		return (script :: any).Parent.SurfaceGui.Canvas
	end
end


-- [chunk_type: 1 byte][compression: 1 byte][length: 4 bytes][id: 2 bytes][data: n bytes]
--[[
local CHUNK_TYPES: {'I'|'P'} = {
	[0] = 'I';
	[1] = 'P';
}

local function readFrame(b: buffer, o: number, metadata: BAC1Metadata): (number, IFrame|PFrame)
	local frameType: 'I'|'P' = CHUNK_TYPES[buffer.readu8(b, o)]

	assert(frameType, ("unknown frameType %i at %i"):format(buffer.readu8(b, o), o))

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
--]]

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
		o, frame = runWithWorkers("readFrame", b, o, metadata)
		frames[frame.id] = frame
		if frame.id%10 == 0 then print(frame.id) end
	end

	table.sort(frames, function(l, r)
		return l.id < r.id
	end)

	return metadata, frames
end

local function initializeCells(metadata: BAC1Metadata, canvas: Frame): ({{ImageLabel}})
	local container = Instance.new('Frame')
	container.BorderSizePixel = 0
	container.BackgroundTransparency = 0
	container.BackgroundColor3 = Color3.new(0.04, 0.04, 0.06)
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
			local cell: ImageLabel = runWithWorkers('clone', cellTemplate) :: any
			cells[cY][cX] = cell

			cell.Position = UDim2.fromOffset((cX-1)*4, (cY-1)*4)
			runWithWorkers("parent", container, cell)
		end
	end

	return cells
end

local function play_frame(distributedInfos: {{CellRenderingInfo}}): ()

	for i, infoSet in next, distributedInfos do
		-- print("distributing instruction to micro #" .. i)
		runWithWorkers("renderFromInfo", infoSet)		
	end
end

local metadata, frames = readFile(get_BAC1())
local cells = initializeCells(metadata, get_canvas())

local syncEnd = os.clock() + 30

print(`deferring render with window {syncEnd - os.clock()}`)
for i, frame in next, frames do
	local timestamp = frame.id / metadata.fps

	local cellInfo = runWithWorkers("buildCellInfo", metadata, frame, cells, workerCount)
	task.delay(syncEnd - os.clock() + timestamp, play_frame, cellInfo)

	if i%10 == 0 then 
		print(("deferring render of frame %i"):format(frame.id))
	end
end

--[[
for i , cellInfo in ipairs(cellInfos) do
	deferRender(cellInfo, syncEnd)
	if i%5000 == 0 then 
		print(("%8.4f %6i"):format(syncEnd - os.clock(), i)) 
		task.wait()
	end
end
--]]