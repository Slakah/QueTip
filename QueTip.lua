local addon = CreateFrame("Frame", "QueTip")

local match, tonumber, wipe, floor = strmatch, tonumber, wipe, math.floor --apparently its good for you

local quests = {} --Tables to store info

local qobs = {}
local qobs_title = {}
local qobs_have = {}
local qobs_need = {}
local qobs_perc = setmetatable({}, {__index = function(t, i)
	local perc = qobs_have[i] / qobs_need[i]
	t[i] = perc
	return perc
end})

local items = {}
local items_have = {}
local items_need = {}
local items_title = {}




--taken from the wonderful LibQuixote by kemayo
local objects_pattern = "^"..QUEST_OBJECTS_FOUND:gsub("(%%.)", "(.+)").."$" --QUEST_OBJECTS_FOUND = "%s: %d/%d" 
local faction_pattern = "^"..QUEST_FACTION_NEEDED:gsub("(%%.)", "(.+)").."$" --QUEST_FACTION_NEEDED = "%s: %s / %s"
local players_pattern = "^"..QUEST_PLAYERS_KILLED:gsub("(%%.)", "(.+)").."$" --QUEST_PLAYERS_KILLED = "Players slain: %d/%d"
local monsters_pattern = "^"..QUEST_MONSTERS_KILLED:gsub("(%%.)", "(.+)").."$" --QUEST_MONSTERS_KILLED = "%s slain: %d/%d"

local factions = {
	[FACTION_STANDING_LABEL1] = 1, --"Hated"
	[FACTION_STANDING_LABEL1_FEMALE] = 1, --"Hated"
	[FACTION_STANDING_LABEL2] = 2, --"Hostile"
	[FACTION_STANDING_LABEL2_FEMALE] = 2, --"Hostile"
	[FACTION_STANDING_LABEL3] = 3, --"Unfriendly"
	[FACTION_STANDING_LABEL3_FEMALE] = 3, --"Unfriendly"
	[FACTION_STANDING_LABEL4] = 4, --"Neutral"
	[FACTION_STANDING_LABEL4_FEMALE] = 4, --"Neutral"
	[FACTION_STANDING_LABEL5] = 5, --"Friendly"
	[FACTION_STANDING_LABEL5_FEMALE] = 5, --"Friendly"
	[FACTION_STANDING_LABEL6] = 6, --"Honored"
	[FACTION_STANDING_LABEL6_FEMALE] = 6, --"Honored"
	[FACTION_STANDING_LABEL7] = 7, --"Revered"
	[FACTION_STANDING_LABEL7_FEMALE] = 7, --"Revered"
	[FACTION_STANDING_LABEL8] = 8, --"Exalted"
	[FACTION_STANDING_LABEL8_FEMALE] = 8 --"Exalted"
}

local function Colour(perc) -- for colouring in, 0 == red, 0.5 == yellow, 1 == green
	if perc <= 0.5 then
		return 1, perc*2, 0
	end
	return 2 - perc*2, 1, 0
end


local qtitle, header, need, have, perc, desc, qtype, name, iscomp, _

local function QuestUpdate()
	wipe(quests)
	wipe(qobs); wipe(qobs_title); wipe(qobs_have); wipe(qobs_need); wipe(qobs_perc)
	wipe(items); wipe(items_title); wipe(items_have); wipe(items_need)
	local itemsize = 0
	local qobsize = 0
	for questid = 1, GetNumQuestLogEntries() do
		qtitle, _, _, _, header, _, iscomp = GetQuestLogTitle(questid)
		if not header then
			quests[qtitle] = true
			for questobnum = 1, GetNumQuestLeaderBoards(questid) do
				desc, qtype = GetQuestLogLeaderBoard(questobnum, questid)
				
				qobsize = qobsize + 1
				
				--qtype is monster
				if qtype == "monster" then
					name, have, need = match(desc, monsters_pattern)
					if not have or not need then
						name, have, need = match(desc, objects_pattern)
					end
					have, need = tonumber(have), tonumber(need)

				--qtype is item/object
				elseif qtype == "item" or qtype == "object" then
					name, have, need = match(desc, objects_pattern)
					-- Add Quest Item to items, for item tooltips which blizzard doesn't handle.
					itemsize = itemsize + 1
					if items[name] then -- incase theres more than one quest wanting  the same thing
						items[name] = items[name]*1000 + itemsize
					else
						items[name] = itemsize
					end
					have, need = tonumber(have), tonumber(need)
					items_have[itemsize] = have
					items_need[itemsize] = need
					items_title[itemsize] = qtitle

				--qtype is rep
				elseif qtype == "reputation" then
					name, have, need = match(desc, faction_pattern)
					qobs_perc[qobsize] = factions[have] / factions[need] --weird case, this is why we need qobs_perc

				--qtype is kill players
				elseif qtype == "player" then
					name, have, need = match(desc, players_pattern)
					have, need = tonumber(have), tonumber(need)

				--dunno what it is possibly event shizzle.
				else
					have, need = iscomp and 1 or 0, 1
				end
				desc = " - "..desc
				if qobs[desc] then -- I thought all descriptions were unique looks like I was wrong.
					qobs[desc] = qobs[desc]*1000 + qobsize
				else
					qobs[desc] = qobsize
				end
				qobs_have[qobsize] = have
				qobs_need[qobsize] = need
				qobs_title[qobsize] = qtitle
			end
		end
	end
end


addon:RegisterEvent("QUEST_LOG_UPDATE")
addon:SetScript("OnEvent", QuestUpdate)
QuestUpdate()

-----------------
--Tooltip Hooks--
-----------------

--Add Item Progress to Item Tooltips
local function AddItemLine(tooltip, id)
	qtitle, have, need = items_title[id], items_have[id], items_need[id]
	tooltip:AddDoubleLine(qtitle..":", have.."/"..need, 1, 1, 1, Colour(have/need))
end

local function MultiItems(tooltip, id)
	if id > 1000 then --keep 1000 until it's possible to have more than 1000 quest objectives at one time.
		AddItemLine(tooltip, id % 1000)
		MultiItems(tooltip, floor(id/1000))
	else
		AddItemLine(tooltip, id)
	end
end

local function OnTooltipSetItem(tooltip, ...)
	local id = items[tooltip:GetItem()]
	if id then
		MultiItems(tooltip, id)
	end
end

--GameTooltip
GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
--ItemRefTooltip
ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
--ShoppingTooltip1
ShoppingTooltip1:HookScript("OnTooltipSetItem", OnTooltipSetItem)
--ShoppingTooltip2
ShoppingTooltip2:HookScript("OnTooltipSetItem", OnTooltipSetItem)



local leftlines = setmetatable({[1] = true}, {__index = function(t, i)
	local f = _G["GameTooltipTextLeft"..i]
	t[i] = f
	return f
end})
local rightlines = setmetatable({[1] = true}, {__index = function(t, i)
	local f = _G["GameTooltipTextRight"..i]
	t[i] = f
	return f
end})

--Modify Blizzards mangling of the Unit Tooltip, make em' pretty etc.

local function GetObjectiveID(id, quest) --We need this incase theres 2 quests with exactly the same objective.
	if id > 1000 then
		if quest == qobs_title[id % 1000] then
			return id % 1000
		else return GetObjectiveID(floor(id/1000), quest)
		end
	else
		return id
	end
end

local origshow, origsetunit
local left, right, left1, right1, left2, right2, r, g, b
local function ChangeQuestText(tooltip)
	local quest, text, id
	local numlines = tooltip:NumLines()
	local i = 1 --start at 2 because 1 can never be a quest objective
	while i < numlines do
		i = i + 1
		left = leftlines[i]
		text = left:GetText()
		
		if quests[text] then
			quest = text
			for j = i, numlines - 1 do
				left1, left2 = leftlines[j], leftlines[j+1]
				left1:SetText(left2:GetText())
				r, g, b = left2:GetTextColor()
				left1:SetTextColor(left2:GetTextColor())
				right2 = rightlines[j+1]
				if right2:IsShown() then
					right1 = rightlines[j]
					right1:SetText(right2:GetText())
					right1:SetTextColor(right2:GetTextColor())
					right1:Show()
				else
					rightlines[j]:Hide()
				end
			end
			leftlines[numlines]:Hide() --Hide and remove the last lines
			leftlines[numlines]:SetText()
			rightlines[numlines]:Hide()
			rightlines[numlines]:SetText()
			text = leftlines[i]:GetText()
			numlines = numlines - 1
		end
		if quest then
			id = qobs[text]
			if id then
				id = GetObjectiveID(id, quest)
				left:SetText(qobs_title[id]..":") --replace objective with quest title
				left:SetTextColor(1, 1, 1)
				right = rightlines[i]
				right:SetText(qobs_have[id].."/"..qobs_need[id]) --Progress through objectives
				right:SetTextColor(Colour(qobs_perc[id]))
				right:Show()
			elseif text and text:find("^ %- (.+)$") then
				left:SetText(text:match("^ %- (.+)$"))
			end
		end
	end
end

local function OnTooltipSetUnit(tooltip, ...) --it annoyed me that when I autolooted items while my mouse was over the quest mob that my tooltip would be made crap
	ChangeQuestText(tooltip)
	if origsetunit then
		return origsetunit(tooltip, ...)
	end
end

local function OnShow(tooltip, ...) --OnShow craziness to hopefully make things work
	if tooltip:GetItem() or tooltip:GetUnit() or tooltip:GetSpell() then return end
	ChangeQuestText(tooltip)
	tooltip:Show()
	if origshow then
		return origshow(tooltip, ...)
	end
end

origsetunit = GameTooltip:GetScript("OnTooltipSetUnit")
GameTooltip:SetScript("OnTooltipSetUnit", OnTooltipSetUnit) --Tooltip isn't always shown when changing unit
origshow = GameTooltip:GetScript("OnShow")
GameTooltip:SetScript("OnShow", OnShow)--only way to get the objects on the floor

if GameTooltip:IsShown() then --incase the tooltip is hovering over something on reload
	if GameTooltip:GetItem() then
		local id = items[GameTooltip:GetItem()]
		if id then
			MultiItems(GameTooltip, id)
		end
	else
		ChangeQuestText(GameTooltip)
	end
	GameTooltip:Show()
end
