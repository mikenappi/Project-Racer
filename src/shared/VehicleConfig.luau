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

	-- Horizontal speed in studs/second; acceleration in studs/second squared.
	MaxForwardSpeed = 48,
	MaxReverseSpeed = 18,
	Acceleration = 45,
	Braking = 90,
	CoastDeceleration = 12,
	StopSpeed = 0.75, -- Brake to rest / permit direction changes below this speed.
	InputDeadzone = 0.05,

	-- Steering follows travel direction, including reversing.
	TurningStrength = 1.6, -- Maximum yaw rate in radians/second.
	SteeringFullSpeed = 12, -- Fade steering in from rest to avoid pivoting in place.
	HighSpeedSteeringScale = 0.55,
	SteeringResponse = 8, -- Higher values respond faster (per second).
	LateralGrip = 90, -- Maximum sideways correction acceleration.
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
