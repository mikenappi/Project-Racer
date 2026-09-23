--!strict

local VehicleConfig = {
	TemplateFolderName = "VehicleTemplates",
	TemplateName = "PlaceholderVehicle",
	ActiveFolderName = "Vehicles",
	TestSpawnName = "PlaceholderVehicleSpawn",
	GroundClearance = 0.25,
	GroundProbeDistance = 256,
	TestDriveEnabled = true,
	TestDriveSpeed = 48, -- Studs per second on unobstructed flat ground.
	TestDriveAcceleration = 160, -- Force per unit mass, including the seated character.
	TestWheelDiameter = 2.8,
	TestWheelWidth = 1.6,
}

return table.freeze(VehicleConfig)
