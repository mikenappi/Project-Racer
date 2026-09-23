--!strict

local VehicleConfig = {
	TemplateFolderName = "VehicleTemplates",
	TemplateName = "PlaceholderVehicle",
	ActiveFolderName = "Vehicles",
	TestSpawnName = "PlaceholderVehicleSpawn",
	GroundClearance = 0.25,
	GroundProbeDistance = 256,
}

return table.freeze(VehicleConfig)
