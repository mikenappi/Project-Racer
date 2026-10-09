--!strict
local RaceHUDFormat = {}

function RaceHUDFormat.time(seconds: number): string
	local milliseconds = math.floor(math.max(0, seconds) * 1000)
	return string.format("%02d:%02d.%03d", math.floor(milliseconds/60000), math.floor(milliseconds/1000)%60, milliseconds%1000)
end

function RaceHUDFormat.ordinal(position: number): string
	local lastTwo = position % 100
	if lastTwo >= 11 and lastTwo <= 13 then return "th" end
	return ({[1]="st", [2]="nd", [3]="rd"})[position % 10] or "th"
end

return RaceHUDFormat
