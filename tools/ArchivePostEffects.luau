-- Run in Studio Edit-mode Command Bar. Reversible removal of post-processing.
local storage = game:GetService("ServerStorage")
local backup = storage:FindFirstChild("PerformanceBackup_20261009")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "PerformanceBackup_20261009"
	backup.Parent = storage
end
local records = backup:FindFirstChild("PostEffects")
if not records then
	records = Instance.new("Folder")
	records.Name = "PostEffects"
	records.Parent = backup
end
local selected = {}
for _, root in {workspace, game:GetService("Lighting")} do
	for _, effect in root:GetDescendants() do
		if effect:IsA("PostEffect") then table.insert(selected, effect) end
	end
end
local offset = #records:GetChildren()
for index, effect in selected do
	local record = Instance.new("Folder")
	record.Name = string.format("%02d_%s", offset + index, effect.ClassName)
	record:SetAttribute("OriginalName", effect.Name)
	record:SetAttribute("OriginalEnabled", effect.Enabled)
	record.Parent = records
	local originalParent = Instance.new("ObjectValue")
	originalParent.Name = "OriginalParent"
	originalParent.Value = effect.Parent
	originalParent.Parent = record
	effect.Parent = record
end
print(string.format("Archived %d post-processing effects; no sky/material/shadow settings changed.", #selected))
