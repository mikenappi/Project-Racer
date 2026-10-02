--!strict

-- Camera math is separate from Roblox lifecycle/occlusion so it can be tested
-- across frame rates without a running place.
local CameraRig = {}

export type State = {
	anchor: Vector3,
	lastPosition: Vector3,
	yaw: number,
}

export type Settings = {
	HeadingResponse: number,
	PositionResponse: number,
	MaxHeadingLag: number,
	MaxPositionLag: number,
	TeleportDistance: number,
	Distance: number,
	Height: number,
	FocusHeight: number,
	LookAhead: number,
}

function CameraRig.alpha(response: number, dt: number): number
	return 1 - math.exp(-response * math.max(0, dt))
end

local function wrapAngle(angle: number): number
	return math.atan2(math.sin(angle), math.cos(angle))
end

local function getYaw(forward: Vector3, fallback: number): number
	-- Ignore chassis pitch/roll, and retain heading if its nose points vertically.
	if forward.X * forward.X + forward.Z * forward.Z < 0.001 then return fallback end
	return math.atan2(-forward.X, -forward.Z)
end

function CameraRig.create(position: Vector3, forward: Vector3): State
	return {anchor = position, lastPosition = position, yaw = getYaw(forward, 0)}
end

function CameraRig.step(state: State, position: Vector3, forward: Vector3, dt: number, config: Settings): boolean
	local targetYaw = getYaw(forward, state.yaw)
	local teleported = (position - state.lastPosition).Magnitude > config.TeleportDistance
	state.lastPosition = position
	if teleported then
		-- A reset is a new view; never fly the camera across the entire map.
		state.anchor = position
		state.yaw = targetYaw
	else
		local delta = wrapAngle(targetYaw - state.yaw)
		local remaining = delta * (1 - CameraRig.alpha(config.HeadingResponse, dt))
		local limit = math.rad(config.MaxHeadingLag)
		state.yaw = wrapAngle(targetYaw - math.clamp(remaining, -limit, limit))
		state.anchor = state.anchor:Lerp(position, CameraRig.alpha(config.PositionResponse, dt))
		local lag = state.anchor - position
		if lag.Magnitude > config.MaxPositionLag then
			state.anchor = position + lag.Unit * config.MaxPositionLag
		end
	end
	return teleported
end

function CameraRig.getView(state: State, config: Settings): (Vector3, Vector3)
	local forward = Vector3.new(-math.sin(state.yaw), 0, -math.cos(state.yaw))
	local position = state.anchor - forward * config.Distance + Vector3.yAxis * config.Height
	local target = state.anchor + Vector3.yAxis * config.FocusHeight + forward * config.LookAhead
	return position, target
end

return CameraRig
