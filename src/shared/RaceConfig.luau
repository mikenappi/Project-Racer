--!strict

return table.freeze({
	MinimumPlayers = 1, -- Supports solo Studio checks; set to 2 for multiplayer-only races.
	LoadingTimeout = 30,
	LoadingRetryInterval = 1,
	CountdownDuration = 3,
	GoDisplayDuration = 1,
	RaceTimeout = 300,
	ResultsDuration = 5,
	CheckpointFolderName = "Checkpoints",
	FinishPartName = "FinishLine",
	TotalLaps = 3,
	ResetRemoteName = "ResetVehicle",
	ResetKey = Enum.KeyCode.R,
	ResetCooldown = 2,
})
