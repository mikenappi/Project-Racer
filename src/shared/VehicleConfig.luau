--!strict

local VehicleConfig = {
	TemplateFolderName = "VehicleTemplates",
	TemplateName = "PlaceholderVehicle",
	ActiveFolderName = "Vehicles",
	TestSpawnName = "PlaceholderVehicleSpawn",
	GroundClearance = 0.25,
	GroundProbeDistance = 256,
	TestWheelDiameter = 2.8,
	TestWheelWidth = 1.6,

	-- Issue 9: everyone is a racer until race/lobby participation is implemented.
	PlayerVehiclesEnabled = true,
	SpawnFolderName = "VehicleSpawns", -- Optional numbered markers: 1, 2, 3...
	SpawnColumns = 3, -- Fallback grid relative to PlaceholderVehicleSpawn.
	SpawnSpacing = Vector3.new(16, 0, 20),
	SpawnRetryInterval = 1, -- Retry blocked/missing spawns without making duplicates.
	VehicleRecoveryHeight = 50, -- Studs above Workspace.FallenPartsDestroyHeight.

	-- Horizontal speed in studs/second; acceleration in studs/second squared.
	MaxForwardSpeed = 1000,
	MaxReverseSpeed = 18,
	Acceleration = 100,
	Braking = 90,
	CoastDeceleration = 6,
	StopSpeed = 0.25, -- Brake to rest / permit direction changes below this speed.
	AccelerationResponse = 5, -- Build drive force gradually; higher responds faster.
	BrakingResponse = 8, -- Ease into driver braking; exit/timeout braking stays immediate.
	InputDeadzone = 0.05,

	-- Steering follows travel direction, including reversing.
	TurningStrength = 1.6, -- Maximum yaw rate in radians/second.
	SteeringFullSpeed = 12, -- Fade steering in from rest to avoid pivoting in place.
	SteeringFadeSpeed = 48, -- Full high-speed reduction, independent of speed-cap experiments.
	HighSpeedSteeringScale = 0.55,
	SteeringResponse = 4.5, -- Higher values respond faster (per second).
	LateralGrip = 90, -- Maximum sideways correction acceleration.
	LateralResponse = 4, -- Sideways momentum decays gradually instead of snapping to zero.
	StabilityStrength = 6, -- Ground-normal alignment response (per second).
	MaxTiltCorrection = 2, -- Maximum corrective pitch/roll rate (radians/second).
	AngularTorquePerMass = 600, -- Finite steering/stability torque per assembly mass.
	GroundContactTolerance = 0.5,
	MinGroundNormalY = 0.5, -- Ignore surfaces steeper than 60 degrees.
	MinUprightDot = 0.35, -- Disable assistance when severely tipped over.

	-- The client sends seat input only; physics stays on the server.
	InputRemoteName = "VehicleInput",
	InputSendInterval = 1 / 20,
	InputMinReceiveInterval = 1 / 60,
	InputTimeout = 0.5, -- Missing input applies the brake instead of keeping W held.
}

return table.freeze(VehicleConfig)
