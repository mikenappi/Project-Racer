--!strict

local CameraConfig = {
	Distance = 24, -- Studs behind the car; measured from its chassis center.
	Height = 10,
	FocusHeight = 2,
	LookAhead = 5, -- Frame some road ahead while keeping the car in view.
	FieldOfView = 75,
	HeadingResponse = 3.5, -- Lower = more gradual swing behind the car in turns.
	PositionResponse = 16, -- Damp small chassis/replication movements.
	MaxHeadingLag = 65, -- Degrees; keep the camera on the rear side of the car.
	MaxPositionLag = 3, -- Studs; keep the car visible even at experimental speeds.
	TeleportDistance = 100, -- Re-center on a large single-frame relocation.
	CollisionRadius = 0.75,
	CollisionPadding = 0.3,
	CollisionReturnResponse = 5, -- Ease back out after an obstruction clears.
}

return table.freeze(CameraConfig)
