--!strict

local PlacementService = {}

export type ActiveRacer = {userId: number, completedLaps: number, checkpoint: number, distance: number?}

-- Inputs come from private server progress and RaceService's accepted finish order.
-- Retained finishers reserve their places even after disconnecting.
function PlacementService.getPositions(activeRacers: {ActiveRacer}, finishOrder: {number}): {[string]: number}
	local positions: {[string]: number} = {}
	for position, userId in finishOrder do
		positions[tostring(userId)] = position
	end
	local active = table.clone(activeRacers)
	table.sort(active, function(a, b)
		if a.completedLaps ~= b.completedLaps then return a.completedLaps > b.completedLaps end
		if a.checkpoint ~= b.checkpoint then return a.checkpoint > b.checkpoint end
		local aDistance, bDistance = a.distance or 0, b.distance or 0
		if aDistance ~= bDistance then return aDistance > bDistance end
		-- Stable across refreshes, table traversal order, resets, and reconnects.
		return a.userId < b.userId
	end)
	local nextPosition = #finishOrder
	for _, racer in active do
		local key = tostring(racer.userId)
		if positions[key] == nil then
			nextPosition += 1
			positions[key] = nextPosition
		end
	end
	return positions
end

return PlacementService
