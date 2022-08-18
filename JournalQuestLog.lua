JournalQuestLog = {}

local INDEX_TYPE = 1
local QUEST_CAT_ZONE = 1
local QUEST_CAT_OTHER = 2
local QUEST_CAT_MISC = 3
local JQL_COMPLETION_STATE_COMPLETED = 1
local JQL_COMPLETION_STATE_NOT_COMPLETED = 0
local JQL_MISSABLE_STATE_NOT_MISSABLE = 0
local JQL_MISSABLE_STATE_MISSABLE = 1
local JQL_MISSABLE_STATE_MISSED = 2

-- Quest Category Overrides
ZO_IS_QUEST_TYPE_IN_OTHER_CATEGORY =
{
    [QUEST_TYPE_MAIN_STORY] = true,
    [QUEST_TYPE_GUILD] = true,
    [QUEST_TYPE_CRAFTING] = true,
    [QUEST_TYPE_HOLIDAY_EVENT] = true,
    [QUEST_TYPE_BATTLEGROUND] = true,
	[QUEST_TYPE_PROLOGUE] = true,
	[QUEST_TYPE_UNDAUNTED_PLEDGE] = true,
	
	[QUEST_TYPE_AVA] = true,
	[QUEST_TYPE_GROUP] = false,
	[QUEST_TYPE_DUNGEON] = true,
	[QUEST_TYPE_RAID] = true,
}

JournalQuestLog.name = "JournalQuestLog"
JournalQuestLog.version = "1.3.3"
local completedQuests = {}
local incompleteQuests = {}
local missedQuests = {}
local allQuests = {}

JournalQuestLog.varDefaults = {
	listGrouped = false,
	showMissed = true,
}

JournalQuestLog.dirty = false

local LAM = LibAddonMenu2

local disabledTextColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS,INTERFACE_TEXT_COLOR_DISABLED))
local failedTextColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS,INTERFACE_TEXT_COLOR_FAILED))
local hintTextColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS,INTERFACE_TEXT_COLOR_HINT))
local highlightTextColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS,INTERFACE_TEXT_COLOR_HIGHLIGHT))
local contrastTextColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS,INTERFACE_TEXT_COLOR_SECOND_CONTRAST))
local normalTextColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS,INTERFACE_TEXT_COLOR_NORMAL))
local succeededTextColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS,INTERFACE_TEXT_COLOR_SUCCEEDED))
local winnerTextColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS,INTERFACE_TEXT_COLOR_BATTLEGROUND_WINNER))
local subtleTextColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS,INTERFACE_TEXT_COLOR_SUBTLE))

local repeatIcon = "/esoui/art/journal/journal_quest_repeat.dds"
local warningIcon = "/esoui/art/miscellaneous/eso_icon_warning.dds"
local newIcon = "/esoui/art/miscellaneous/new_icon.dds"
local checkIcon = "/esoui/art/cadwell/check.dds"
local bulletIcon = "/esoui/art/journal/journal_quest_selected.dds"
local disabledIcon = "/esoui/art/miscellaneous/locked_disabled.dds"
local forbiddenIcon = "/esoui/art/quest/questjournal_tracker_notsharedstepicon.dds"
local groupIcon = "/esoui/art/journal/journal_quest_group_area.dds"

function JournalQuestLog.CreateConfigMenu()
    local panelData = {
        type                = "panel",
        name                = JournalQuestLog.name,
        displayName         = "Journal Quest Log",
        author              = "Enodoc",
        version             = JournalQuestLog.version,
        slashCommand        = nil,
        registerForRefresh  = true,
        registerForDefaults = true,
    }
	local ConfigPanel = LAM:RegisterAddonPanel(panelData.name.."Config", panelData)

	local ConfigData = {
		{
			type = "checkbox",
			name = GetString(SI_JOURNAL_QUEST_LOG_ORDER),
			tooltip = GetString(SI_JOURNAL_QUEST_LOG_ORDER_TOOLTIP),
			getFunc = function() return JournalQuestLog.vars.listGrouped end,
			setFunc = function(newValue) JournalQuestLog.vars.listGrouped = newValue end,
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_JOURNAL_QUEST_LOG_SHOW_MISSED),
			tooltip = GetString(SI_JOURNAL_QUEST_LOG_SHOW_MISSED_TOOLTIP),
			getFunc = function() return JournalQuestLog.vars.showMissed end,
			setFunc = function(newValue) JournalQuestLog.vars.showMissed = newValue end,
			requiresReload = true,
		},
		{
			type = "header",
			name = GetString(SI_JOURNAL_QUEST_LOG_KEY_HEADER),
		},
		{
			type = "description",
			text = zo_iconTextFormat(newIcon, 16, 16, winnerTextColor:Colorize(GetString(SI_JOURNAL_QUEST_LOG_KEY_MISSABLE))),
		},
		{
			type = "description",
			text = "     "..GetString(SI_JOURNAL_QUEST_LOG_KEY_NORMAL),
		},
		{
			type = "description",
			text = zo_iconTextFormat(disabledIcon, 16, 16, disabledTextColor:Colorize(GetString(SI_JOURNAL_QUEST_LOG_KEY_UNAVAILABLE))),
		},
		{
			type = "description",
			text = zo_iconTextFormat(forbiddenIcon, 16, 16, failedTextColor:Colorize(GetString(SI_JOURNAL_QUEST_LOG_KEY_MISSED))),
		},
		{
			type = "description",
			text = contrastTextColor:Colorize("     "..GetString(SI_JOURNAL_QUEST_LOG_KEY_REPEATABLE)),
		},
		{
			type = "description",
			text = zo_iconTextFormat(checkIcon, 16, 16, normalTextColor:Colorize(GetString(SI_JOURNAL_QUEST_LOG_KEY_COMPLETED))),
		},
		{
			type = "description",
			text = string.format("%s |t16:16:%s|t", GetString(SI_JOURNAL_QUEST_LOG_KEY_GROUP), groupIcon),
		},
	}
	LAM:RegisterOptionControls(panelData.name.."Config", ConfigData)	
end

function JournalQuestLog.OnAddOnLoaded(event, addonName)
	if addonName ~= JournalQuestLog.name then return end
	EVENT_MANAGER:UnregisterForEvent(JournalQuestLog.name, EVENT_ADD_ON_LOADED)
	JournalQuestLog.Initialize()
end

EVENT_MANAGER:RegisterForEvent(JournalQuestLog.name, EVENT_ADD_ON_LOADED, JournalQuestLog.OnAddOnLoaded)

function JournalQuestLog.Initialize()
	JournalQuestLog.control=GetControl("JQL_Window")
	control=JournalQuestLog.control
	local function InitializeRow(control, data)
		control:SetText(data.questName)--(zo_strformat(GetString(SI_JOURNAL_QUEST_LOG_ROW_ENTRY), data.questName))
	end

	JournalQuestLog.indexContainer = GetControl("JQL_WindowQuestIndex")
	JournalQuestLog.titleText = GetControl("JQL_WindowTitleText")
	ZO_ScrollList_AddDataType(JournalQuestLog.indexContainer, INDEX_TYPE, "JQL_QuestEntryTemplate", 24, InitializeRow)

	-- Votan's stuff
	local sceneName = "QuestLog"
	JQL_FRAGMENT = ZO_HUDFadeSceneFragment:New(JQL_Window)
	JQL_SCENE = ZO_Scene:New(sceneName, SCENE_MANAGER)
	JQL_SCENE:AddFragmentGroup(FRAGMENT_GROUP.PLAYER_PROGRESS_BAR_KEYBOARD_CURRENT)
	JQL_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)
	JQL_SCENE:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
	JQL_SCENE:AddFragment(FRAME_TARGET_BLUR_STANDARD_RIGHT_PANEL_FRAGMENT)
	JQL_SCENE:AddFragment(FRAME_EMOTE_FRAGMENT_JOURNAL)
	JQL_SCENE:AddFragment(RIGHT_BG_FRAGMENT)
	JQL_SCENE:AddFragment(TITLE_FRAGMENT)
	JQL_SCENE:AddFragment(JOURNAL_TITLE_FRAGMENT)
	JQL_SCENE:AddFragment(TREE_UNDERLAY_FRAGMENT)
	JQL_SCENE:AddFragment(CODEX_WINDOW_SOUNDS)
	JQL_SCENE:AddFragment(JQL_FRAGMENT)

	SYSTEMS:RegisterKeyboardRootScene(sceneName, JQL_SCENE)

	local sceneGroupInfo = MAIN_MENU_KEYBOARD.sceneGroupInfo["journalSceneGroup"]
	local iconData = sceneGroupInfo.menuBarIconData
	--Override Quests default
	iconData[1] = {
		categoryName = SI_JOURNAL_QUEST_LOG_MENU_QUESTS,
		descriptor = "questJournal",
		normal = "EsoUI/Art/Journal/journal_tabIcon_quest_up.dds",
		pressed = "EsoUI/Art/Journal/journal_tabIcon_quest_down.dds",
		highlight = "EsoUI/Art/Journal/journal_tabIcon_quest_over.dds",
	}
	--Add new Log window
	iconData[#iconData + 1] = {
		categoryName = SI_JOURNAL_QUEST_LOG_MENU_HEADER,
		descriptor = sceneName,
		normal = "/esoui/art/mainmenu/menubar_journal_up.dds",
		pressed = "/esoui/art/mainmenu/menubar_journal_down.dds",
		highlight = "/esoui/art/mainmenu/menubar_journal_over.dds",
	}
	local sceneGroupBarFragment = sceneGroupInfo.sceneGroupBarFragment
	JQL_SCENE:AddFragment(sceneGroupBarFragment)

	JournalQuestLog.InitializeCategoryList(control)
--	JournalQuestLog.RefreshQuestMasterList()
--	JournalQuestLog.RefreshQuestList()
	JournalQuestLog.CreateConfigMenu()
	JournalQuestLog.vars = ZO_SavedVars:NewAccountWide("JournalQuestLog_SavedVariables", 1, nil, JournalQuestLog.varDefaults)

	local scenegroup = SCENE_MANAGER:GetSceneGroup("journalSceneGroup")
	scenegroup:AddScene(sceneName)
	MAIN_MENU_KEYBOARD:AddRawScene(sceneName, MENU_CATEGORY_JOURNAL, MAIN_MENU_KEYBOARD.categoryInfo[MENU_CATEGORY_JOURNAL], "journalSceneGroup")

	JQL_SCENE:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWING and JournalQuestLog.dirty then
			JournalQuestLog.CleanCompletedQuests()
			JournalQuestLog.RefreshCompletedQuests()
			JournalQuestLog.dirty = false
--			d("JQL Show")
--		elseif newState == SCENE_HIDING then
--			JournalQuestLog.CleanCompletedQuests()
--			d("JQL Hide")
		end
	end )

	EVENT_MANAGER:RegisterForEvent("JournalQuestLog", EVENT_QUEST_COMPLETE, JournalQuestLog.OnCompleteQuest)
	
	JournalQuestLog.RefreshCompletedQuests()
--	d("JQL Initialized")

end

function JournalQuestLog.OnCompleteQuest(eventCode, _)
	JournalQuestLog.dirty = true
end

function JournalQuestLog.InitializeCategoryList(control)
	JournalQuestLog.navigationTree = ZO_Tree:New(control:GetNamedChild("NavigationContainerScrollChild"), 40, -10, 385)

    local function TreeHeaderSetup(node, control, completionState, open)
        control:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
        control:SetText(GetString("SI_JOURNAL_QUEST_LOG_NAVIGATION", completionState))
        
        ZO_LabelHeader_Setup(control, open)
    end

    local function TreeHeaderEquality(left, right)
        return left.completionState == right.completionState
    end
	
    JournalQuestLog.navigationTree:AddTemplate("ZO_LabelHeader", TreeHeaderSetup, nil, TreeHeaderEquality, nil, 0)

    local function TreeEntrySetup(node, control, data, open)
        control:SetText(zo_strformat("<<1>>", data.name))
        local counter = control:GetNamedChild("CounterText")
		counter:SetText(zo_strformat("<<2>>/<<1>>", #data.quests-data.missed, data.completed))
		GetControl(control, "CompletedIcon"):SetHidden(not data.allCompleted)
        control:SetSelected(false)
    end
    local function TreeEntryOnSelected(control, data, selected, reselectingDuringRebuild)
        control:SetSelected(selected)
        if selected and not reselectingDuringRebuild then
            JournalQuestLog.RefreshCategory()
        end
    end
    local function TreeEntryEquality(left, right)
        return left.name == right.name
    end
    JournalQuestLog.navigationTree:AddTemplate("JQL_NavigationEntry", TreeEntrySetup, TreeEntryOnSelected, TreeEntryEquality)

    JournalQuestLog.navigationTree:SetExclusive(true)
    JournalQuestLog.navigationTree:SetOpenAnimation("ZO_TreeOpenAnimation")
--	d("JQL Navigation Initialized")
end

function JournalQuestLog.RefreshCompletedQuests()

	local questId = 0
	local i = 0
	local j = 0
	local k = 0
	while questId < 10000 do
		questId = GetNextCompletedQuestId(questId)
		if questId == nil then break end
		i = i + 1
		local questName, questType = GetCompletedQuestInfo(questId)
		local zoneName, objectiveName, zoneIndex, poiIndex = GetCompletedQuestLocationInfo(questId)
		local categoryName, categoryType = QUEST_JOURNAL_MANAGER:GetQuestCategoryNameAndType(questType, zoneName)
		local completionState = JQL_COMPLETION_STATE_COMPLETED
		local isAvailable = 1
		local repeatType = LibUespQuestData:GetUespQuestRepeatType(questId)
		local isRepeatable
		local isMissable = 0
		
		if repeatType > 0 then
			isRepeatable = true
		else
			isRepeatable = false
		end
		
		if questName == "" then
			questName = zo_strformat(SI_JOURNAL_QUEST_LOG_UNKNOWN_QUEST_NAME, questId)
		end
		
		completedQuests[i] = {questId=questId, questName=questName, questType=questType, zoneName=zoneName, objectiveName=objectiveName, zoneIndex=zoneIndex, poiIndex=poiIndex, categoryName=categoryName, categoryType=categoryType, completionState=completionState, isAvailable=isAvailable, isRepeatable=isRepeatable, isMissable=isMissable}
	end
	
	for questId,questData in next, LibUespQuestData.quests do
--		local questId = tonumber(questIdString)
		if GetCompletedQuestInfo(questId) == "" then
			j = j + 1
			local questName, questType, zoneName, objectiveName = LibUespQuestData:GetUespQuestInfo(questId)
--			questType = tonumber(questType)
			local categoryName, categoryType = QUEST_JOURNAL_MANAGER:GetQuestCategoryNameAndType(questType, zoneName)
			local completionState = JQL_COMPLETION_STATE_NOT_COMPLETED
			local journalZone = zo_strformat(SI_QUEST_JOURNAL_ZONE_FORMAT, zoneName)
			local isAvailable
			local repeatType = LibUespQuestData:GetUespQuestRepeatType(questId)
			local isRepeatable
			local isMissable = JournalQuestLog.GetIsMissable(questId)
			local skipCyrodiil = JournalQuestLog.GetSkipCyrodiil(questId)
			local skipSpecial = JournalQuestLog.GetSkipSpecial(questId)
			
			if repeatType > 0 then
				isRepeatable = true
			else
				isRepeatable = false
			end

			if questName == "" then
				questName = zo_strformat(SI_JOURNAL_QUEST_LOG_UNKNOWN_QUEST_NAME, questId)
			end
			
			-- Collectible IDs indexed under 18173141; Zone IDs indexed under 162658389
			if (journalZone ==  GetZoneNameById(584) or objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_IMPERIAL1) or objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_IMPERIAL2)) and not IsCollectibleUnlocked(154) then isAvailable = false	--Imperial City
			elseif (journalZone == GetZoneNameById(684)) and not IsCollectibleUnlocked(215) then isAvailable = false											--Orsinium
			elseif (journalZone == GetZoneNameById(816) or journalZone == GetZoneNameById(767) or GetZoneNameById(771) or journalZone == GetZoneNameById(763) or journalZone == GetZoneNameById(770) or journalZone == GetZoneNameById(764) or journalZone == GetZoneNameById(725)) and not IsCollectibleUnlocked(254) then isAvailable = false	--Thieves Guild
			elseif (journalZone == GetZoneNameById(823) or journalZone == GetZoneNameById(769) or journalZone == GetZoneNameById(765) or journalZone == GetZoneNameById(766) or questName == string.match(questName,GetString(SI_JOURNAL_QUEST_LOG_QUEST_DARK_CONTRACT))) and not IsCollectibleUnlocked(306) then isAvailable = false	--Dark Brotherhood
			elseif (journalZone == GetZoneNameById(849) or journalZone == GetZoneNameById(975)) and not IsCollectibleUnlocked(593) then isAvailable = false		--Morrowind
			elseif (journalZone == GetZoneNameById(980) or journalZone == GetZoneNameById(1000)) and not IsCollectibleUnlocked(1240) then isAvailable = false	--Clockwork City
			elseif (journalZone == GetZoneNameById(1011) or journalZone == GetZoneNameById(1051)) and not IsCollectibleUnlocked(5107) then isAvailable = false	--Summerset
			elseif (journalZone == GetZoneNameById(726)) and not IsCollectibleUnlocked(5755) then isAvailable = false											--Murkmire
			elseif (journalZone == GetZoneNameById(1086) or journalZone == GetZoneNameById(1121)) and not IsCollectibleUnlocked(5843) then isAvailable = false	--Elsweyr
			elseif (journalZone == GetZoneNameById(1133)) and not IsCollectibleUnlocked(6920) then isAvailable = false											--Dragonhold
			elseif (journalZone == GetZoneNameById(1160) or journalZone == GetZoneNameById(1161) or journalZone == GetZoneNameById(1196)) and not IsCollectibleUnlocked(7466) then isAvailable = false	--Greymoor
			elseif (journalZone == GetZoneNameById(1207) or journalZone == GetZoneNameById(1208)) and not IsCollectibleUnlocked(8388) then isAvailable = false	--Markarth
			elseif (journalZone == GetZoneNameById(1261) or journalZone == GetZoneNameById(1263)) and not IsCollectibleUnlocked(8659) then isAvailable = false	--Blackwood
			elseif (journalZone == GetZoneNameById(1286) or journalZone == GetZoneNameById(1282)) and not IsCollectibleUnlocked(9365) then isAvailable = false	--Deadlands
			elseif (journalZone == GetZoneNameById(1318) or journalZone == GetZoneNameById(1344)) and not IsCollectibleUnlocked(10053) then isAvailable = false	--High Isle
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_SHADOWS1)) and not IsCollectibleUnlocked(375) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_SHADOWS2)) and not IsCollectibleUnlocked(491) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_HORNS1)) and not IsCollectibleUnlocked(1165) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_HORNS2)) and not IsCollectibleUnlocked(1355) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_BONES1)) and not IsCollectibleUnlocked(1331) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_BONES2)) and not IsCollectibleUnlocked(4703) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_WOLFHUNTER1)) and not IsCollectibleUnlocked(5009) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_WOLFHUNTER2)) and not IsCollectibleUnlocked(5008) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_WRATHSTONE1)) and not IsCollectibleUnlocked(5474) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_WRATHSTONE2)) and not IsCollectibleUnlocked(5473) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_SCALEBREAKER1)) and not IsCollectibleUnlocked(6040) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_SCALEBREAKER2)) and not IsCollectibleUnlocked(6041) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_HARROWSTORM1)) and not IsCollectibleUnlocked(6646) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_HARROWSTORM2)) and not IsCollectibleUnlocked(6647) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_STONETHORN1)) and not IsCollectibleUnlocked(7430) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_STONETHORN2)) and not IsCollectibleUnlocked(7431) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_FLAMES1)) and not IsCollectibleUnlocked(8216) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_FLAMES2)) and not IsCollectibleUnlocked(8217) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_WAKING1)) and not IsCollectibleUnlocked(9374) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_WAKING2)) and not IsCollectibleUnlocked(9375) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_ASCENDING1)) and not IsCollectibleUnlocked(9651) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_ASCENDING2)) and not IsCollectibleUnlocked(9652) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_DEPTHS1)) and not IsCollectibleUnlocked(10400) then isAvailable = false
			elseif (objectiveName == GetString(SI_JOURNAL_QUEST_LOG_DUNGEON_DEPTHS2)) and not IsCollectibleUnlocked(10401) then isAvailable = false
			else isAvailable = true
			end
			
			incompleteQuests[j] = {questId=questId, questName=questName, questType=questType, zoneName=zoneName, objectiveName=objectiveName, zoneIndex="", poiIndex="", categoryName=categoryName, categoryType=categoryType, completionState=completionState, isAvailable=isAvailable, isRepeatable=isRepeatable, isMissable = isMissable}
			
			if isMissable == JQL_MISSABLE_STATE_MISSED then
				k = k + 1
				missedQuests[k] = {questId=questId, questName=questName, questType=questType, zoneName=zoneName, objectiveName=objectiveName, zoneIndex="", poiIndex="", categoryName=categoryName, categoryType=categoryType, completionState=completionState, isAvailable=isAvailable, isRepeatable=isRepeatable, isMissable = isMissable}
			end
			
			if (not JournalQuestLog.vars.showMissed and isMissable == JQL_MISSABLE_STATE_MISSED) or (skipCyrodiil) or (skipSpecial) then
				incompleteQuests[j] = nil
				if isMissable == JQL_MISSABLE_STATE_MISSED then
					missedQuests[k] = nil
					k = k - 1
				end
				j = j - 1
			end
		end
	end
	
	local duplicateQuests = JournalQuestLog.DuplicateManager()
	
	for i = 1, #duplicateQuests do
		incompleteQuests[#incompleteQuests+1] = duplicateQuests[i]
	end
		

	local function QuestEntryComparator(leftScrollData, rightScrollData)
		local leftName = leftScrollData.questName
		local rightName = rightScrollData.questName
		
		return leftName < rightName
	end
	
	table.sort(completedQuests,QuestEntryComparator)
	table.sort(incompleteQuests,QuestEntryComparator)
	
	--make combined table
	for i = 1, #completedQuests do
		allQuests[i] = completedQuests[i]
	end
	for i = 1, #incompleteQuests do
		allQuests[i+#completedQuests] = incompleteQuests[i]
	end
	
	if not JournalQuestLog.vars.listGrouped then table.sort(allQuests,QuestEntryComparator) end

	for i = 1, #allQuests do
		if allQuests[i].questType == QUEST_TYPE_GROUP then allQuests[i].questName = string.format("%s |t16:16:%s|t", allQuests[i].questName, groupIcon) end
		if not allQuests[i].isAvailable then allQuests[i].questName = disabledTextColor:Colorize(allQuests[i].questName)
		elseif allQuests[i].isRepeatable then allQuests[i].questName = contrastTextColor:Colorize(allQuests[i].questName)
		elseif allQuests[i].completionState == JQL_COMPLETION_STATE_COMPLETED then allQuests[i].questName = normalTextColor:Colorize(allQuests[i].questName)
		elseif allQuests[i].isMissable == JQL_MISSABLE_STATE_MISSABLE then allQuests[i].questName = winnerTextColor:Colorize(allQuests[i].questName)
		elseif allQuests[i].isMissable == JQL_MISSABLE_STATE_MISSED then allQuests[i].questName = failedTextColor:Colorize(allQuests[i].questName)
		end
		
		if not allQuests[i].isAvailable then allQuests[i].questName = "zzw_"..zo_iconTextFormat(disabledIcon, 16, 16, allQuests[i].questName)
		elseif allQuests[i].completionState == JQL_COMPLETION_STATE_COMPLETED then allQuests[i].questName = "zzz_"..zo_iconTextFormat(checkIcon, 16, 16, allQuests[i].questName)
		elseif allQuests[i].isMissable == JQL_MISSABLE_STATE_MISSABLE then allQuests[i].questName = "aaa_"..zo_iconTextFormat(newIcon, 16, 16, allQuests[i].questName)
		elseif allQuests[i].isMissable == JQL_MISSABLE_STATE_MISSED then allQuests[i].questName = "zzx_"..zo_iconTextFormat(forbiddenIcon, 16, 16, allQuests[i].questName)
		else allQuests[i].questName = "aab_     "..allQuests[i].questName end
		--else allQuests[i].questName = zo_iconTextFormat(bulletIcon, 16, 16, allQuests[i].questName) end
		
		if allQuests[i].isRepeatable then allQuests[i].questName = "zzy_"..allQuests[i].questName end

	end
	
	if JournalQuestLog.vars.listGrouped then table.sort(allQuests,QuestEntryComparator) end
	
	for i = 1, #allQuests do
		allQuests[i].questName = string.gsub(allQuests[i].questName,"aaa_","")
		allQuests[i].questName = string.gsub(allQuests[i].questName,"aab_","")
		allQuests[i].questName = string.gsub(allQuests[i].questName,"zzw_","")
		allQuests[i].questName = string.gsub(allQuests[i].questName,"zzx_","")
		allQuests[i].questName = string.gsub(allQuests[i].questName,"zzy_","")
		allQuests[i].questName = string.gsub(allQuests[i].questName,"zzz_","")
	end

	-- the strings corresponding to the keys for data held in completedQuests[i]
	local questInfoFields = { "questId", "questName", "questType", "zoneName", "objectiveName", "zoneIndex", "poiIndex", "categoryName", "categoryType", "completionState", }
	local dataCatName = { }
	local data = { }

	--[[
			table structure is roughly: data = { [1] = { name = "category1 by name", quests = { [1] = quest1, [2] = quest2, ... } }, [2] = { name="category2 by name", quests = { [1] = quest3, [2] = quest4, ...} }, ...}
			where dataCatName = { ["category1 by name"] = data[1], ["category2 by name"] = data[2], ...}
	--]]
	for i = 1, #allQuests do
		local questInfo = { }
		-- fill out the current quest info into our data format
		for _, field in pairs(questInfoFields) do
			questInfo[tostring(field)] = allQuests[i][tostring(field)]
		end

		local pos = 1
		local categoryName = allQuests[i].categoryName
		-- if the category doesn't exist yet, create it
		if not dataCatName[categoryName] then
			-- save by name as the key, because I want to be able to find this using the category name to quickly associate quests with their category table
			dataCatName[categoryName] = { name = categoryName }
			-- but also create an iterative key version of the category names, using keys 1 to n, since it makes it easier to sort and use generically when we care less about the name
			if #data > 0 then
				for i = 1, #data do
					-- find the first spot where the new category is lower down the alphabet, and keep going until the end of the table or the first time its no longer lower
					-- more reliable in practice than table.sort, which wasn't providing the correct order
					if tostring(categoryName) > tostring(data[i].name)then pos = i+1 end
				end
			end
			-- insert into pos 1 if the table is empty or the category precedes all the others alphabetically, else place it (after the first miss) into the spot it belongs
			table.insert(data, pos, dataCatName[categoryName])
		end

		local dcn = dataCatName[categoryName]
		-- make sure this category has room to hold quests
		if not dcn.quests then dcn.quests = { } end
		if not dcn.completed then dcn.completed = 0 end
		if not dcn.missed then dcn.missed = 0 end
		local questName = allQuests[i].questName

		-- if this quest isn't in the category yet, add it
		--if not dcn.quests[questName] then dcn.quests[questName]  = { } end
		local k = #dcn.quests + 1
		dcn.quests[k] = { }
		if allQuests[i].completionState == JQL_COMPLETION_STATE_COMPLETED then dcn.completed = dcn.completed + 1 end
		if allQuests[i].isMissable == JQL_MISSABLE_STATE_MISSED then dcn.missed = dcn.missed + 1 end

		-- copy the quest info to the table
		for field, value in pairs(questInfo) do
			dcn.quests[k][tostring(field)] = value
		end
	end

--[[
--	local data2CatName = { }
--	local data2 = { }

	for i = 1, #incompleteQuests do
		local questInfo = { }
		-- fill out the current quest info into our data2 format
		for _, field in pairs(questInfoFields) do
			questInfo[tostring(field)] = incompleteQuests[i][tostring(field)]
		end

		local pos = 1
		local categoryName = incompleteQuests[i].categoryName
		-- if the category doesn't exist yet, create it
		if not dataCatName[categoryName] then
			-- save by name as the key, because I want to be able to find this using the category name to quickly associate quests with their category table
			dataCatName[categoryName] = { name = categoryName }
			-- but also create an iterative key version of the category names, using keys 1 to n, since it makes it easier to sort and use generically when we care less about the name
			if #data > 0 then
				for i = 1, #data do
					-- find the first spot where the new category is lower down the alphabet, and keep going until the end of the table or the first time its no longer lower
					-- more reliable in practice than table.sort, which wasn't providing the correct order
					if tostring(categoryName) > tostring(data[i].name)then pos = i+1 end
				end
			end
			-- insert into pos 1 if the table is empty or the category precedes all the others alphabetically, else place it (after the first miss) into the spot it belongs
			table.insert(data, pos, dataCatName[categoryName])
		end

		local dcn = dataCatName[categoryName]
		-- make sure this category has room to hold quests
		if not dcn.quests then dcn.quests = { } end
		if not dcn.completed then dcn.completed = 0 end
		local questName = incompleteQuests[i].questName

		-- if this quest isn't in the category yet, add it
		--if not dcn.quests[questName] then dcn.quests[questName]  = { } end
		local k = #dcn.quests + 1
		dcn.quests[k] = { }

		-- copy the quest info to the table
		for field, value in pairs(questInfo) do
			dcn.quests[k][tostring(field)] = value
		end
	end
--]]
	
	JournalQuestLog.navigationTree:Reset()
	
	local categories = {}
	
	local completionState = JQL_COMPLETION_STATE_COMPLETED
	
		local parent = JournalQuestLog.navigationTree:AddNode("ZO_LabelHeader", completionState, nil, SOUNDS.CADWELL_BLADE_SELECTED)

		for i = 1, #data do
			local category = data[i]
			local quests = {}
			for _, quest in pairs(category.quests) do
--				if quest.completionState == completionState then
					table.insert(quests, {name = quest.questName})
--				end
			end
			local allCompleted
			if #quests-category.missed == category.completed then
				allCompleted = true
			else
				allCompleted = false
			end
			table.insert(categories, {name = category.name, quests = quests, parent = parent, completed = category.completed, missed = category.missed, allCompleted = allCompleted})
		end
	
--[[
	local completionState2 = JQL_COMPLETION_STATE_NOT_COMPLETED
	
		local parent2 = JournalQuestLog.navigationTree:AddNode("ZO_LabelHeader", completionState2, nil, SOUNDS.CADWELL_BLADE_SELECTED)

		for i = 1, #data2 do
			local category = data2[i]
			local quests = {}
			for _, quest in pairs(category.quests) do
				if quest.completionState == completionState2 then
					table.insert(quests, {name = quest.questName})
				end
			end
			table.insert(categories, {name = category.name, quests = quests, parent = parent2})
		end
--]]
		
	for i = 1, #categories do
		local category = categories[i]
		local parent = category.parent
		JournalQuestLog.navigationTree:AddNode("JQL_NavigationEntry", category, parent, SOUNDS.CADWELL_ITEM_SELECTED)
	end

	JournalQuestLog.navigationTree:Commit()
	
	--[[
	
	-- color the zone names/categories
	local color = ZO_ColorDef:New()
	color:SetRGBA(0.5, 0.5, 0.5, 1)
	for i = 1, #data do
		local category = data[i]
		-- add the zone name/category with a blank line above it
		scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(INDEX_TYPE, {questName = ""})
		scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(INDEX_TYPE, {questName = color:Colorize(category.name)})
		for _, quest in pairs(category.quests) do
			-- add the quests to each category, in alphabetical order from before
			scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(INDEX_TYPE, {questName = quest.questName})
		end
	end

	ZO_ScrollList_Commit(JournalQuestLog.indexContainer)
	
	--]]

	local QuestCounter = GetControl("JQL_WindowQuestCount")
	QuestCounter:SetText(zo_strformat(GetString(SI_JOURNAL_QUEST_LOG_COMPLETED),#completedQuests,#completedQuests+#incompleteQuests-#missedQuests))
	
	JournalQuestLog.RefreshCategory()
--	d("JQL Refreshed")

end

function JournalQuestLog.RefreshCategory()
	local scrollData = ZO_ScrollList_GetDataList(JournalQuestLog.indexContainer)
	ZO_ScrollList_Clear(JournalQuestLog.indexContainer)

--	if JournalQuestLog.selectedNode then
--		JournalQuestLog.navigationTree:SelectNode(JournalQuestLog.selectedNode, true, true)
--		JournalQuestLog.selectedNode = nil
--	end

    local selectedData = JournalQuestLog.navigationTree:GetSelectedData()
	if type(selectedData) == "table" then
		if not selectedData or not selectedData.quests then
			JournalQuestLog.indexContainer:SetHidden(true)
			return
		else
			JournalQuestLog.indexContainer:SetHidden(false)
		end
	else
		JournalQuestLog.indexContainer:SetHidden(true)
		return
	end
	
	for i = 1, #selectedData.quests do
		local quests = selectedData.quests[i]
		scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(INDEX_TYPE, {questName = quests.name})
	end
	JournalQuestLog.titleText:SetText(zo_strformat(selectedData.name))
	ZO_ScrollList_Commit(JournalQuestLog.indexContainer)
--	d("JQL Quest List Updated")	
end

function JournalQuestLog.CleanCompletedQuests()

--	JournalQuestLog.selectedNode = JournalQuestLog.navigationTree:GetSelectedNode()
	local scrollData = ZO_ScrollList_GetDataList(JournalQuestLog.indexContainer)
	ZO_ScrollList_Clear(JournalQuestLog.indexContainer)
	JournalQuestLog.navigationTree:Reset()

	completedQuests = {}
	incompleteQuests = {}
	missedQuests = {}

--	d("JQL Cleaned")
end

-- // questJournal Manager overrides //
--[[ This was for the Active Quests override - it doesn't work right now

function JournalQuestLog.RefreshQuestMasterList()
    local quests, categories = QUEST_JOURNAL_MANAGER:GetQuestListData()
	local questJournalObject = SYSTEMS:GetObject("questJournal")
    questJournalObject.questMasterList = {
        quests = quests,
        categories = categories,
--      seenCategories = seenCategories,
    }
end

function JournalQuestLog:RefreshQuestList()
	local questJournalObject = SYSTEMS:GetObject("questJournal")
--  local quests = questJournalObject.questMasterList.quests
--  local categories = questJournalObject.questMasterList.categories

    questJournalObject.questIndexToTreeNode = {}

    ClearTooltip(InformationTooltip)

    -- Add items to the tree
    questJournalObject.navigationTree:Reset()

    local categoryNodes = {}
    local categories = QUEST_JOURNAL_MANAGER:GetQuestCategories()
    for i, categoryInfo in ipairs(categories) do
        categoryNodes[categoryInfo.name] = questJournalObject.navigationTree:AddNode("ZO_QuestJournalHeader", categoryInfo.name)
    end

    local firstNode
    local lastNode
    local assistedNode
    local questList = QUEST_JOURNAL_MANAGER:GetQuestList()
    for i, questInfo in ipairs(questList) do
        local parent = categoryNodes[questInfo.categoryName]
        local questNode = questJournalObject.navigationTree:AddNode("ZO_QuestJournalNavigationEntry", questInfo, parent)
        firstNode = firstNode or questNode
        questJournalObject.questIndexToTreeNode[questInfo.questIndex] = questNode

        if lastNode then
            lastNode.nextNode = questNode
        end

        if i == #questList then
            questNode.nextNode = firstNode
        end

        if assistedNode == nil and GetTrackedIsAssisted(TRACK_TYPE_QUEST, questInfo.questIndex) then
            assistedNode = questNode
        end

        lastNode = questNode
    end

    questJournalObject.navigationTree:Commit(assistedNode)

    questJournalObject:RefreshDetails()

    questJournalObject.listDirty = false
end
--]]