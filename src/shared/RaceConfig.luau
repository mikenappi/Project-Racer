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
	PlacementInterval = 0.1, -- Continuous projection sampling, at most 10 Hz.
	ProgressFolderName = "RaceProgressPaths",
	ProgressCorridorRadius = 12, -- 3D chassis corridor; override per interval.
	ProgressEndpointTolerance = 4,
	ProgressMaxSpeed = 1200, -- Includes the current 1000 studs/s test tuning.
	ProgressMaxSampleGap = 0.5,
	ProgressEntryDistance = 24, -- Gate contact / starting-grid / recovery offset.
	ProgressSlack = 2,
	ProgressArcRatio = 1.5,
	HUD = table.freeze({Margin = 24, TopOffset = 12, ReferenceWidth = 1280, ReferenceHeight = 720, MinScale = 0.55, MaxScale = 1.2, ResetFeedbackDuration = 3}),
	ResetRemoteName = "ResetVehicle",
	ResetKey = Enum.KeyCode.R,
	ResetCooldown = 2,
})
