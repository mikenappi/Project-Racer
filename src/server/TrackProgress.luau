--!strict
-- Geometry only: never awards checkpoint, lap, or finish credit.
local TrackProgress = {}
export type Point = {X: number, Y: number, Z: number} | Vector3
export type Path = {points: {Point}, offsets: {number}, length: number, radius: number}
export type Sample = {position: Point, distance: number, time: number}
export type Options = {MaxSpeed: number, MaxSampleGap: number, EntryDistance: number, Slack: number, ArcRatio: number}

local function distance(a: Point, b: Point): number
	return math.sqrt((a.X-b.X)^2 + (a.Y-b.Y)^2 + (a.Z-b.Z)^2)
end
local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function TrackProgress.build(points: {Point}, radius: number): Path?
	if #points < 2 or not finite(radius) or radius <= 0 then return nil end
	local offsets, length = {0}, 0
	for i, point in points do
		if not finite(point.X) or not finite(point.Y) or not finite(point.Z) then return nil end
		if i > 1 then
			local span = distance(points[i-1], point)
			if span < 0.01 then return nil end
			length += span
			offsets[i] = length
		end
	end
	return {points=table.clone(points), offsets=offsets, length=length, radius=radius}
end

-- Only search the arc window reachable from the last trusted sample. This is
-- essential where a path crosses itself or runs beside another portion of track.
local function project(path: Path, position: Point, low: number, high: number): (number?, number)
	local best, errorDistance = nil, math.huge
	for i = 1, #path.points-1 do
		local start, stop = path.offsets[i], path.offsets[i+1]
		if stop < low or start > high then continue end
		local a, b = path.points[i], path.points[i+1]
		local x, y, z = b.X-a.X, b.Y-a.Y, b.Z-a.Z
		local alpha = math.clamp(((position.X-a.X)*x + (position.Y-a.Y)*y + (position.Z-a.Z)*z)/(stop-start)^2,
			math.max(0, (low-start)/(stop-start)), math.min(1, (high-start)/(stop-start)))
		local candidate = start + alpha*(stop-start)
		local offset = distance(position, {X=a.X+alpha*x,Y=a.Y+alpha*y,Z=a.Z+alpha*z})
		if offset < errorDistance then best, errorDistance = candidate, offset end
	end
	return best, errorDistance
end

-- Rejection retains a trusted anchor, but displays zero within-stage credit.
-- Updating its time prevents accumulating a teleport allowance while off track.
function TrackProgress.sample(path: Path, previous: Sample?, position: Point, now: number, options: Options): (Sample, number)
	local anchor: Sample = previous or {position=path.points[1], distance=0, time=now}
	local rejected: Sample = {position=anchor.position, distance=anchor.distance, time=now}
	if not finite(position.X) or not finite(position.Y) or not finite(position.Z) then return rejected, 0 end
	local dt = now-anchor.time
	local travel = distance(anchor.position, position)
	local allowance = if previous then options.MaxSpeed * math.max(0, dt) + options.Slack else options.EntryDistance
	if dt < 0 or dt > options.MaxSampleGap or travel > allowance then return rejected, 0 end
	local window = math.min(allowance, travel*options.ArcRatio + options.Slack)
	local low, high = math.max(0, anchor.distance-window), math.min(path.length, anchor.distance+window)
	local projected, offset = project(path, position, low, high)
	if not projected or offset > path.radius then return rejected, 0 end
	-- A movement chord must stay in the corridor as well as its endpoint. Curves
	-- need dense samples and a sampling rate appropriate to the vehicle speed.
	local checks = math.max(1, math.ceil(travel / (path.radius * 0.5)))
	if checks > 256 then return rejected, 0 end
	for step = 1, checks-1 do
		local t = step/checks
		local point = {X=anchor.position.X+(position.X-anchor.position.X)*t,
			Y=anchor.position.Y+(position.Y-anchor.position.Y)*t, Z=anchor.position.Z+(position.Z-anchor.position.Z)*t}
		local _, gap = project(path, point, low, high)
		if gap > path.radius then return rejected, 0 end
	end
	return {position=position, distance=projected, time=now}, projected
end

-- Authored non-code assets stay in Studio. Copy positions once per race so
-- editing markers during play cannot silently change the ranking geometry.
function TrackProgress.load(workspace: Workspace, config: any): ({[number]: Path}?, string)
	local folder = workspace:FindFirstChild(config.ProgressFolderName)
	if not folder or not folder:IsA("Folder") then return nil, "Missing " .. config.ProgressFolderName end
	local checkpoints = workspace:FindFirstChild(config.CheckpointFolderName)
	local finish = workspace:FindFirstChild(config.FinishPartName)
	if not checkpoints or not finish or not finish:IsA("BasePart") then return nil, "Missing race gates" end
	local count, paths = #checkpoints:GetChildren(), {}
	if #folder:GetChildren() ~= count+1 then return nil, "Expected progress intervals 0 through " .. count end
	local function atGate(point: Point, gate: BasePart): boolean
		local localPoint = gate.CFrame:PointToObjectSpace(Vector3.new(point.X, point.Y, point.Z))
		return math.abs(localPoint.Z) <= gate.Size.Z/2 + config.ProgressEndpointTolerance
			and math.abs(localPoint.X) <= gate.Size.X/2 and math.abs(localPoint.Y) <= gate.Size.Y/2
	end
	for stage = 0, count do
		local interval = folder:FindFirstChild(tostring(stage))
		if not interval or not interval:IsA("Folder") then return nil, "Missing interval " .. stage end
		local points = {}
		for index = 1, #interval:GetChildren() do
			local marker = interval:FindFirstChild(tostring(index))
			if not marker or not marker:IsA("BasePart") or not marker.Anchored
				or marker.CanCollide or marker.CanTouch or marker.CanQuery then
				return nil, "Invalid progress marker in interval " .. stage
			end
			table.insert(points, marker.Position)
		end
		local radius = interval:GetAttribute("CorridorRadius") or config.ProgressCorridorRadius
		if typeof(radius) ~= "number" then return nil, "Invalid CorridorRadius in interval " .. stage end
		local path = TrackProgress.build(points, radius)
		if not path then return nil, "Invalid path in interval " .. stage end
		local from = if stage == 0 then finish else checkpoints:FindFirstChild(tostring(stage))
		local to = if stage == count then finish else checkpoints:FindFirstChild(tostring(stage+1))
		if not from or not to or not from:IsA("BasePart") or not to:IsA("BasePart")
			or not atGate(points[1], from) or not atGate(points[#points], to) then
			return nil, "Path endpoints must lie inside their gates: interval " .. stage
		end
		paths[stage] = path
	end
	return paths, "Continuous"
end

return TrackProgress
