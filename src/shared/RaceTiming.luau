--!strict

local Workspace = game:GetService("Workspace")
local RaceTiming = {}

export type Snapshot = {
	state: string, raceId: number, startedAt: number, endedAt: number,
	finishTimes: {[string]: number},
}

-- Use Workspace:GetServerTimeNow() on either side, never a client's local clock.
function RaceTiming.getElapsed(snapshot: Snapshot, serverNow: number, userId: number?): number
	if snapshot.state ~= "Racing" and snapshot.state ~= "Results" then return 0 end
	if snapshot.startedAt <= 0 then return 0 end
	local finishTime = if userId then snapshot.finishTimes[tostring(userId)] else nil
	if finishTime ~= nil then return finishTime end
	local stop = if snapshot.endedAt > 0 then snapshot.endedAt else serverNow
	return math.max(0, stop - snapshot.startedAt)
end

-- Durable presentation fallback for late subscribers; attributes are not atomic.
-- For coherent event updates, use getElapsed with the RaceUpdated snapshot.
function RaceTiming.getReplicatedElapsed(raceState: StringValue, player: Player?): number
	local raceId = raceState:GetAttribute("RaceId") :: number? or 0
	local finishTimes: {[string]: number} = {}
	if player and player:GetAttribute("RaceFinishId") == raceId then
		finishTimes[tostring(player.UserId)] = player:GetAttribute("RaceFinishTime") :: number?
	end
	return RaceTiming.getElapsed({
		state = raceState.Value, raceId = raceId,
		startedAt = raceState:GetAttribute("StartedAt") :: number? or 0,
		endedAt = raceState:GetAttribute("EndedAt") :: number? or 0,
		finishTimes = finishTimes,
	}, Workspace:GetServerTimeNow(), if player then player.UserId else nil)
end

return RaceTiming
