--!strict

local BAC1_URL = "https://raw.githubusercontent.com/dorpg9/WOS-Bad-Apple/refs/heads/ver-2025-01/zout/native_bayer4.zjson"
local IN_GAME: boolean = (GetPartFromPort :: any) ~= nil

-- \):\s*[^\w_].*?\n
-- )\n

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

if IN_GAME then
	local disk = GetPartFromPort(80, "Disk")
	local loadUrl = disk and disk:Read("BAC1_active-url")
	if type(loadUrl) == "string" then
		BAC1_URL = loadUrl
	end

	local keyboard = GetPartFromPort(80, "Keyboard")
	if keyboard then keyboard.TextInputted:Connect(function(cmd, _)
		local url = cmd:match("seturl (%S+)")
		if disk and url then
			disk:Write("BAC1_active-url", url)
		end
	end) end
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

local function getProgressUpdater(canvas: Frame)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 0, 0, 0)
	bar.ZIndex = 100
	
	local bar1 = bar:Clone()
	local bar2 = bar:Clone()
	
	bar1.Parent = canvas
	bar2.Parent = canvas
	
	bar2.Position = UDim2.fromOffset(0, 8)

	return function(tag: string, progress: number)
		if tag == "done" then
			bar1:Destroy()
			bar2:Destroy()
			return
		end
		
		print(("%16s %6.4f"):format(tag, progress))
		if tag == "decode" then
			bar1.Size = UDim2.new(progress, 0, 0, 8)
		elseif tag == "deferRender" then
			bar2.Size = UDim2.new(progress, 0, 0, 8)
		end
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

local function readFile(file: string, progressHandler: (string, number)->()): (BAC1Metadata, {IFrame | PFrame})
	local b, o = buffer.fromstring(file), 0

	local metadata
	o, metadata = readMetadata(b, o)

	local frames: {IFrame | PFrame} = {}

	while buffer.readstring(b, o, 8) ~= "\x7f\0\0\0\0\0\0\0" do
		local frame	
		o, frame = runWithWorkers("readFrame", b, o, metadata)
		frames[frame.id] = frame
		if frame.id%10 == 0 then progressHandler("decode", frame.id/metadata.frame_count) end
	end

	table.sort(frames, function(l, r)
		return l.id < r.id
	end)

	return metadata, frames
end

local function initializeCells(metadata: BAC1Metadata, canvas: Frame): ({{ImageLabel}}, Frame)
	local container = Instance.new('Frame')
	container.BorderSizePixel = 0
	container.BackgroundTransparency = 0
	container.BackgroundColor3 = Color3.new(0.04, 0.04, 0.06)
	container.Size = UDim2.fromOffset(metadata.width_in_chunks*4, metadata.height_in_chunks*4)
	container.Position = UDim2.fromScale(0.5, 1e+6)
	container.AnchorPoint = Vector2.one * 0.5
	container.Parent = canvas

	local cellTemplate = Instance.new('ImageLabel')
	cellTemplate.BackgroundColor3 = Color3.new()
	cellTemplate.BorderSizePixel = 0
	cellTemplate.Image = "rbxassetid://140538709701134"
	cellTemplate.ImageRectSize = Vector2.new(4, 4)
	cellTemplate.ResampleMode = Enum.ResamplerMode.Pixelated
	-- cellTemplate.Rotation = 180 -- I have no idea lol
	cellTemplate.ScaleType = Enum.ScaleType.Crop
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

	return cells, container
end

local function play_frame(distributedInfos: {{CellRenderingInfo}}): ()

	for i, infoSet in next, distributedInfos do
		-- print("distributing instruction to micro #" .. i)
		runWithWorkers("renderFromInfo", infoSet)		
	end
end

local canvas = get_canvas()
local progressHandler = getProgressUpdater(canvas)

local metadata, frames = readFile(get_BAC1(), progressHandler)
local cells, container = initializeCells(metadata, get_canvas())

local toSchedule: {{t: number, c: {{CellRenderingInfo}}}} = {}

print(`baking render`)
for i, frame in next, frames do
	local timestamp = frame.id / metadata.fps

	local cellInfo = runWithWorkers("buildCellInfo", metadata, frame, cells, workerCount)
	toSchedule[#toSchedule + 1] = {t = timestamp, c = cellInfo}

	if i%10 == 0 then 
		progressHandler("deferRender", frame.id/metadata.frame_count)
	end
end

local syncT1 = os.clock() + 5
for _, bakedFrame in next, toSchedule do
	task.delay((syncT1 - os.clock()) + bakedFrame.t, play_frame, bakedFrame.c)
end
container.Position = UDim2.fromScale(0.5, 0.5)


--[[
for i , cellInfo in ipairs(cellInfos) do
	deferRender(cellInfo, syncEnd)
	if i%5000 == 0 then 
		print(("%8.4f %6i"):format(syncEnd - os.clock(), i)) 
		task.wait()
	end
end
--]]