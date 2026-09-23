--!strict

local VehicleConfig = {
	TemplateFolderName = "VehicleTemplates",
	TemplateName = "PlaceholderVehicle",
	ActiveFolderName = "Vehicles",
	TestSpawnName = "PlaceholderVehicleSpawn",
	GroundClearance = 0.25,
	GroundProbeDistance = 256,
	TestDriveEnabled = true,
	TestDriveSpeed = 12, -- Studs per second on unobstructed flat ground.
	TestDriveAcceleration = 160, -- Force per unit mass, including the seated character.
}

return table.freeze(VehicleConfig)
