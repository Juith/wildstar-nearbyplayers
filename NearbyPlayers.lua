---------------------------------------------------------------------------------------------------
-- NearbyPlayers:
--
-- Simple and lightweight[or is it any more?] nearby players tracker.
--
-- NearbyPlayers aims to restore the tracker removed by Carbine in Patch 1.5.1 #13373. In addition, 
-- it will also mark nearby Friends, Guild-mates, PvPers and Role-players, and a minimap on demand.
--
-- Credits:
--
--   * QuestLog and Who: Widlstar built-in add-ons by Carbine, copyrighted to NCSoft.
--   * LFRP: Widlstar add-on by baslack
--   * Guard Mini Map: Wildstar add-on by jjflanigan
---------------------------------------------------------------------------------------------------

require "Window"
require "Unit" 
require "GameLib"
require "Tooltip"

-----------------------------------------------------------------------------------------------
-- NearbyPlayers Module Definition
-----------------------------------------------------------------------------------------------

local NearbyPlayers = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

local ktClassToIconPanel =
{
	[GameLib.CodeEnumClass.Warrior]      = "IconSprites:Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer]     = "IconSprites:Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Esper]        = "IconSprites:Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Medic]        = "IconSprites:Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Stalker]      = "IconSprites:Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Spellslinger] = "IconSprites:Icon_Windows_UI_CRB_Spellslinger",
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------

function NearbyPlayers:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self 

	o.nTimestamp = 0
	o.tTracked = {}
	o.tRPTracked = {} 
	o.tPrvTracked = {} 

	o.bShowTracker = true
	o.bShowRadar = false
	o.bTrackPvPers = true
	o.bTrackRPers = true
	o.bTrackGuildies = true
	o.bTrackPlayerDistance = true
	o.bTrackPlayerLevel = true
	o.bTrackPlayerClass = true
	o.bTrackPlayerHealth = false
	o.bTrackPlayerTarget = false
	o.strRPChatChannels = nil
	o.bDisplayHostileNPCOnRadar = true
	o.bHideMiniMap = false

	--//-- My pinkies
		o.tPrvChannelNames = { "" }

	return o
end

function NearbyPlayers:Initialize()
	Apollo.RegisterAddon(self, true, "Nearby Players Tracker", {})
end

-----------------------------------------------------------------------------------------------
-- NearbyPlayers OnLoad
-----------------------------------------------------------------------------------------------

function NearbyPlayers:OnLoad() 
	self.xmlDoc = XmlDoc.CreateFromFile("NearbyPlayers.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)

	Apollo.RegisterEventHandler("UnitCreated"  , "OnUnitCreated"  , self)
	Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self) 
	Apollo.RegisterEventHandler("ChangeWorld"  , "OnChangeWorld"  , self)
end

function NearbyPlayers:OnDocLoaded()
	if self.xmlDoc == nil then 
		return
	end

	Apollo.LoadSprites("Sprites.xml")
	Apollo.LoadSprites("SquareMapTextures_NoCompass.xml")

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "NearbyPlayersForm", nil, self)

	if self.wndMain == nil then 
		return
	end

	self.wndMain:Show(false, true)

	self.wndConfigure = Apollo.LoadForm(self.xmlDoc, "ConfigureForm", nil, self)

	self.wndPreviewCharacter = Apollo.LoadForm(self.xmlDoc, "PreviewCharacterForm", nil, self)

	self.wndPreviewCharacter:Show(false, true)

	Apollo.RegisterSlashCommand("nearby", "ShowNearbyPlayers", self) 

	self.wndPlayersList = self.wndMain:FindChild("PlayersList")

	self.wndConfigure:FindChild("TrackPvPers"):SetCheck(self.bTrackPvPers or false)
	self.wndConfigure:FindChild("TrackPvPers"):SetData("TrackPvPers")

	self.wndConfigure:FindChild("TrackRPers"):SetCheck(self.bTrackRPers or false)
	self.wndConfigure:FindChild("TrackRPers"):SetData("TrackRPers")

	self.wndConfigure:FindChild("TrackGuildies"):SetCheck(self.bTrackGuildies or false)
	self.wndConfigure:FindChild("TrackGuildies"):SetData("TrackGuildies")

	self.wndConfigure:FindChild("TrackPlayerDistance"):SetCheck(self.bTrackPlayerDistance or false)
	self.wndConfigure:FindChild("TrackPlayerDistance"):SetData("TrackPlayerDistance")

	self.wndConfigure:FindChild("TrackPlayerLevel"):SetCheck(self.bTrackPlayerLevel or false)
	self.wndConfigure:FindChild("TrackPlayerLevel"):SetData("TrackPlayerLevel")

	self.wndConfigure:FindChild("TrackPlayerClass"):SetCheck(self.bTrackPlayerClass or false)
	self.wndConfigure:FindChild("TrackPlayerClass"):SetData("TrackPlayerClass")

	self.wndConfigure:FindChild("TrackPlayerHealth"):SetCheck(self.bTrackPlayerHealth or false)
	self.wndConfigure:FindChild("TrackPlayerHealth"):SetData("TrackPlayerHealth")

	self.wndConfigure:FindChild("TrackPlayerTarget"):SetCheck(self.bTrackPlayerTarget or false)
	self.wndConfigure:FindChild("TrackPlayerTarget"):SetData("TrackPlayerTarget")

	self.wndConfigure:FindChild("DisplayHostileNPCOnRadar"):SetCheck(self.bDisplayHostileNPCOnRadar or false)
	self.wndConfigure:FindChild("DisplayHostileNPCOnRadar"):SetData("DisplayHostileNPCOnRadar")

	self.wndConfigure:FindChild("HideMiniMap"):SetCheck(self.bHideMiniMap or false)
	self.wndConfigure:FindChild("HideMiniMap"):SetData("HideMiniMap")

	self.wndMain:FindChild("ButtonContainer"):FindChild("Art"):SetBGOpacity(0.33, 5) 

	self.wndMain:FindChild("AlliesNormiesBtn"):SetData("AlliesNormies")
	self.wndMain:FindChild("FreindsBtn"):SetData("Freinds")
	self.wndMain:FindChild("AlliesPvPersBtn"):SetData("AlliesPvPers")
	self.wndMain:FindChild("EnemiesPvPersBtn"):SetData("EnemiesPvPers")
	self.wndMain:FindChild("GuildmatesBtn"):SetData("Guildmates")
	self.wndMain:FindChild("AlliesRPersBtn"):SetData("AlliesRPers")

	self.ShowOnlyAlliesNormies = false
	self.ShowOnlyFreinds	   = false
	self.ShowOnlyAlliesPvPers  = false
	self.ShowOnlyEnemiesPvPers = false
	self.ShowOnlyGuildmates	   = false
	self.ShowOnlyAlliesRPers   = false 

	-- Copypasta from LFRP, yo.
	local inpRPChatChannels = self.wndConfigure:FindChild("RPChatChannels")

	if self.strRPChatChannels then
		inpRPChatChannels:SetText(self.strRPChatChannels)
	end

	self.tRPChannelNames = self:SplitString(inpRPChatChannels:GetText()) 

	--
	
	self.PixieID = 1
	self.PixieInfo = self.wndMain:GetPixieInfo(self.PixieID)
	self.wndMain:DestroyPixie(self.PixieID)
 
	self.RadarWindow    = nil
	self.wndMiniMap     = nil
	self.wndMiniMapRing = nil
	
	local nLeft, nTop, nRight, nBottom = self.wndPlayersList:GetAnchorOffsets()
	self.wndPlayersList:SetAnchorOffsets(nLeft, 29, nRight, nBottom)
	
	--

	self.UpdateTimer = ApolloTimer.Create(1, true, "OnUpdateTimer" , self)

	--

	if self.tLoc ~= nil then
		self.wndMain:MoveToLocation(WindowLocation.new(self.tLoc))
	end

	if self.bShowRadar == true then
		self:OnRadarBtnCheck() 

		self.wndMain:FindChild("RadarBtn"):SetCheck(true)
	end

	self:ChatLog_SuppressListing()

	self:ShowNearbyPlayers()

	if self.bHideMiniMap == true then
		self.MiniMapTimer = ApolloTimer.Create(0.1, true, "OnHideMiniMapTimer" , self)
	end
end

function NearbyPlayers:OnHideMiniMapTimer()
	local minimap = Apollo.GetAddon("MiniMap")

	if minimap and minimap.wndMain then
		minimap.wndMain:Show(false)

		if self.MiniMapTimer then
			self.MiniMapTimer:Stop()
			self.MiniMapTimer = nil
		end
	end
end

function NearbyPlayers:OnShowMiniMapTimer()
	local minimap = Apollo.GetAddon("MiniMap")

	if minimap and minimap.wndMain then
		minimap.wndMain:Show(true)

		if self.MiniMapTimer then
			self.MiniMapTimer:Stop()
			self.MiniMapTimer = nil
		end
	end
end

-----------------------------------------------------------------------------------------------
-- NearbyPlayers Saved Settings
-----------------------------------------------------------------------------------------------

function NearbyPlayers:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local tSave = {}

	tSave['tLoc'] = self.wndMain:GetLocation():ToTable()
	tSave['tLocPortrait'] = self.wndPreviewCharacter:GetLocation():ToTable()
	tSave['bShowRadar'] = self.bShowRadar
	tSave['bTrackPvPers'] = self.bTrackPvPers
	tSave['bTrackRPers'] = self.bTrackRPers
	tSave['bTrackGuildies'] = self.bTrackGuildies
	tSave['bTrackPlayerDistance'] = self.bTrackPlayerDistance
	tSave['bTrackPlayerLevel'] = self.bTrackPlayerLevel
	tSave['bTrackPlayerClass'] = self.bTrackPlayerClass
	tSave['bTrackPlayerHealth'] = self.bTrackPlayerHealth
	tSave['bTrackPlayerTarget'] = self.bTrackPlayerTarget
	tSave['strRPChatChannels'] = self.strRPChatChannels
	tSave['bDisplayHostileNPCOnRadar'] = self.bDisplayHostileNPCOnRadar
	tSave['bHideMiniMap'] = self.bHideMiniMap

	return tSave
end

function NearbyPlayers:OnRestore(eLevel, tData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	if tData ~= nil then
		self.tLoc = tData['tLoc']
		self.tLocPortrait = tData['tLocPortrait']
		self.bShowRadar = tData['bShowRadar']
		self.bTrackPvPers = tData['bTrackPvPers']
		self.bTrackRPers = tData['bTrackRPers']
		self.bTrackGuildies = tData['bTrackGuildies']
		self.bTrackPlayerDistance = tData['bTrackPlayerDistance']
		self.bTrackPlayerLevel = tData['bTrackPlayerLevel']
		self.bTrackPlayerClass = tData['bTrackPlayerClass']
		self.bTrackPlayerHealth = tData['bTrackPlayerHealth']
		self.bTrackPlayerTarget = tData['bTrackPlayerTarget']
		self.strRPChatChannels = tData['strRPChatChannels']
		self.bDisplayHostileNPCOnRadar = tData['bDisplayHostileNPCOnRadar']
		self.bHideMiniMap = tData['bHideMiniMap']
	end
end

-----------------------------------------------------------------------------------------------
-- Registered Events Handlers
-----------------------------------------------------------------------------------------------

function NearbyPlayers:OnUnitCreated(unitCreated)
	if unitCreated:GetType() == "Player" then
		self.tTracked[unitCreated:GetName()] = unitCreated

		return
	end

	local unitPlayer = GameLib.GetPlayerUnit()

	if self.bDisplayHostileNPCOnRadar
	and self.wndMiniMap
	and unitCreated:GetType() == "NonPlayer" 
	and unitCreated:GetRank() >= Unit.CodeEnumRank.Superior
	and (unitPlayer and unitCreated:GetDispositionTo(unitPlayer) == Unit.CodeEnumDisposition.Hostile)
	then
		local tInfo = {}

		tInfo.crObject      = ApolloColor.new("ffff0000")
		tInfo.strIcon       = "sprMap_NPC"
		tInfo.crEdge        = CColor.new(1,1,1,1)
		tInfo.bAboveOverlay = false

		self.wndMiniMap:AddUnit(unitCreated, nil, tInfo, true)
	end
end

function NearbyPlayers:OnUnitDestroyed(unitDestroyed)
	if self.wndMiniMap then
		self.wndMiniMap:RemoveUnit(unitDestroyed)
	end
	
	if unitDestroyed:GetType() == "Player" then
		for name, unit in pairs(self.tTracked) do
			if unitDestroyed:GetName() == name then
				self.tTracked[name] = nil
			end
		end
	end
end

function NearbyPlayers:OnChangeWorld()
	self.tTracked = {}
end

-----------------------------------------------------------------------------------------------
-- RPers Detection -- Borrowed of LFRP
-----------------------------------------------------------------------------------------------

function NearbyPlayers:ChatLog_SuppressListing()
	if self.bTrackRPers == false then
		return
	end

	local ChatLog = Apollo.GetAddon("ChatLog")

	if ChatLog then
		-- ikr? I'll fix it, prolly.
		function ChatLog:OnChatList(channelSource)
			return nil
		end
	end
end

function NearbyPlayers:PollRPChannels()
	if self.bTrackRPers == false then
		return
	end

	local channels = ChatSystemLib.GetChannels()

	self.tRPTracked = {}
	self.tPrvTracked = {}

	for i,this_chan in ipairs(channels) do
		for j, rp_chan in ipairs(self.tRPChannelNames) do
			if string.lower(this_chan:GetName()) == rp_chan then
				this_chan:RequestMembers()
				local members = this_chan:GetMembers()

				for k, this_member in ipairs(members) do
					local strName = this_member['strMemberName']

					self.tRPTracked[strName] = true
				end
			end
		end

		--//--
			for j, rp_chan in ipairs(self.tPrvChannelNames) do
				if string.lower(this_chan:GetName()) == rp_chan then
					this_chan:RequestMembers()
					local members = this_chan:GetMembers()

					for k, this_member in ipairs(members) do
						local strName = this_member['strMemberName']

						self.tRPTracked[strName] = true
						self.tPrvTracked[strName] = true
					end
				end
			end
		--//--
	end 
end 

-----------------------------------------------------------------------------------------------
-- Main Functions
-----------------------------------------------------------------------------------------------

function NearbyPlayers:OnUpdateTimer()
	if not self.bShowTracker then 
		return
	end

	self.nTimestamp = os.time()

	-- Poll rp channels once per 100 secs
	if self.nTimestamp % 100 == 0 then
		self:PollRPChannels()
	end

	-- local x = os.clock()
	self:PopulateNearbyPlayersList(false)
	-- Print(string.format("PopulateNearbyPlayersList took: %.3fms\n", os.clock() - x))

	if false and self.nTimestamp % 2 == 0 then
		local info = Apollo.GetAddonInfo("NearbyPlayers")

		if info ~= nil then
			Print(info.strName .. " | Debug mode - Mem: " .. string.format("%.2fKb", info.nMemoryUsage / 1024) .. ". Calls: " .. info.nTotalCalls .. ". Cycles: " .. string.format("%.3fms", info.fCallTimePerFrame * 1000.0) .. ". Longest: " .. string.format("%.3fs", info.fLongestCall))
		end
	end
end

function NearbyPlayers:ShowNearbyPlayers()
	self:PopulateNearbyPlayersList(true)
	self.bShowTracker = true
	self.UpdateTimer:Start()
	self.wndMain:Show(self.bShowTracker)
	self.wndConfigure:Show(false)
end
 
-----------------------------------------------------------------------------------------------
-- Form Generic Events
-----------------------------------------------------------------------------------------------

function NearbyPlayers:OnClose(wndHandler, wndControl, eMouseButton)
	self.wndMain:Close()
	self.bShowTracker = false
	self.UpdateTimer:Stop()
end

function NearbyPlayers:OnPlayersListMouseEnter(wndHandler, wndControl, x, y)
	if wndControl == wndHandler then
		self.UpdateTimer:Stop()
	end
end

function NearbyPlayers:OnPlayersListMouseExit(wndHandler, wndControl, x, y)
	if wndControl == wndHandler then
		self.UpdateTimer:Start()
	end
end

function NearbyPlayers:OnHoverWindowMouseEnter(wndHandler, wndControl, x, y)
	self.wndMain:FindChild("CloseButton"):Show(true)
	self.wndMain:FindChild("ButtonContainer"):Show(true)
	self.wndMain:SetSprite("CRB_UIKitSprites:spr_scrollHologramBack")  
end

function NearbyPlayers:OnHoverWindowMouseExit(wndHandler, wndControl, x, y)
	self.wndMain:FindChild("CloseButton"):Show(false)
	self.wndMain:FindChild("ButtonContainer"):Show(false)
	self.wndMain:SetSprite(nil)  
end

function NearbyPlayers:OnGenerateTooltip(wndHandler, wndControl, eType, nX, nY)
	local xml = nil
	local crWhite = CColor.new(1, 1, 1, 1)
	if eType ~= Tooltip.TooltipGenerateType_Map then
		wndControl:SetTooltipDoc(nil)
		return
	end
	
	local nCount = 0
	local bNeedToAddLine = true
	local tClosestObject = nil
	local nShortestDist = 0
	
	local tMapObjects = self.wndMiniMap:GetObjectsAtPoint(nX, nY)
	if not tMapObjects or #tMapObjects == 0 then
		wndControl:SetTooltipDoc(nil)
		return
	end
	
	for key, tObject in pairs(tMapObjects) do
		if tObject.unit then
			local nDistSq = (nX - tObject.ptMap.x) * (nX - tObject.ptMap.x) + (nY - tObject.ptMap.y) * (nY - tObject.ptMap.y)
			if tClosestObject == nil or nDistSq < nShortestDist then
				tClosestObject = tObject
				nShortestDist = nDistSq
			end
			nCount = nCount + 1
		end
	end
	
	if not xml then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		bNeedToAddLine = false
	end
	
	-- Iterate map objects
	local nObjectCount = 0
	local tStringsAdded = {}
	for key, tObject in pairs(tMapObjects) do
		if nObjectCount == 5 then
			nObjectCount = nObjectCount + 1
	
			local tInfo =
			{
				["name"] = Apollo.GetString("CRB_Unit"),
				["count"] = nCount
			}
			xml:AddLine(String_GetWeaselString(Apollo.GetString("MiniMap_OtherUnits"), tInfo), crWhite, "CRB_InterfaceMedium")
		elseif nObjectCount > 5 then
			local donothing
		elseif tObject.strName == "" then
			local donothing
		elseif tObject.strName and not tObject.bMarked then
			if bNeedToAddLine then
				xml:AddLine(" ")
			end

			bNeedToAddLine = false
	
			if not tStringsAdded[tObject.strName] then
				nObjectCount = nObjectCount + 1
				xml:AddLine(tObject.strName, crWhite, "CRB_InterfaceMedium")
				tStringsAdded[tObject.strName] = true
			end
		end
	end
	
	if nObjectCount > 0 then
		wndControl:SetTooltipDoc(xml)
	else
		wndControl:SetTooltipDoc(nil)
	end
end

-----------------------------------------------------------------------------------------------
-- PlayersList Functions and Events
-----------------------------------------------------------------------------------------------

function NearbyPlayers:PopulateNearbyPlayersList(force)
	local ntTracked = self:tablelength(self.tTracked)

	-- reduce the refresh rate depending on players numbers
	-- derp'in kind of trick, but it works.. kinda.
	
	local nRefreshRate = 1

	if self.bNearbyPlayers_hostiles == false and self.bTrackPlayerHealth == false then
		if force == false then
			if ntTracked >= 32 and self.nTimestamp % 8 ~= 0 then
				nRefreshRate = 8
				
				return
			end

			if ntTracked >= 16 and self.nTimestamp % 4 ~= 0 then
				nRefreshRate = 4
				
				return
			end

			if ntTracked >= 8 and self.nTimestamp % 2 ~= 0 then
				nRefreshRate = 2
				
				return
			end
		end
	end

	local unitPlayer = GameLib.GetPlayerUnit()

	-- game lib, why you do this
	if unitPlayer == nil then
		return
	end
	
	self.tTracked[unitPlayer:GetName()] = nil 

	local tNearbyPlayers = {}

	for strName, unitTracked in pairs(self.tTracked) do
		if unitTracked then
			table.insert(tNearbyPlayers, unitTracked)
		end
	end

	table.sort(tNearbyPlayers, function(a,b) return self:DistanceToUnit(a)<self:DistanceToUnit(b) end)

	local nPlayersTotalCount = #tNearbyPlayers

	self.DrawnPlayerLines = 0
	
	local nAlliesNormies = 0
	local nAlliesPvPersCount = 0
	local nEnemiesCount = 0
	local nEnemiesPvPersCount = 0
	local nGuildmatesCount = 0
	local nAlliesRPersCount = 0
	local nFreindsCount = 0
	
	self.bNearbyPlayers_hostiles = false

	-- clear list
	self.wndPlayersList:DestroyChildren()

	-- draw new ui
	for i, unitNearby in ipairs(tNearbyPlayers) do 
		if unitNearby and unitPlayer then
			local unitNearbyInfo = {}
			
			unitNearbyInfo.isAlly	     = false
			unitNearbyInfo.isAllyPvPer   = false
			unitNearbyInfo.isEnemyPvPer  = false
			unitNearbyInfo.isGuildmate   = false
			unitNearbyInfo.isAllyRPer    = false
			unitNearbyInfo.isAllyPrvRPer = false
			unitNearbyInfo.isFriend	     = false
			unitNearbyInfo.strColor	     = "ffffffff" 
			
			-- get info

			local sPlayerGuildName = unitPlayer:GetGuildName()

			if sPlayerGuildName ~= nil then 
				local sTargetGuildName = unitNearby:GetGuildName()

				if sPlayerGuildName == sTargetGuildName then 
					unitNearbyInfo.isGuildmate = true
				end
			end

			if NearbyPlayers:IsHostileUnit(unitPlayer, unitNearby) == true then
				if unitNearby:IsPvpFlagged() then 
					unitNearbyInfo.isEnemyPvPer = true 
				end
			else
				unitNearbyInfo.isAlly = true

				if unitNearby:IsPvpFlagged() then 
					unitNearbyInfo.isAllyPvPer = true
				end
			end

			if self.tRPTracked[unitNearby:GetName()] ~= nil then 
				unitNearbyInfo.isAllyRPer = true
			end

			if self.tPrvTracked[unitNearby:GetName()] ~= nil then
				unitNearbyInfo.isAllyPrvRPer = true
			end

			if unitNearby:IsFriend() or unitNearby:IsAccountFriend() then
				unitNearbyInfo.isFriend = true
			end
			
			-- color

			if self.bTrackGuildies == true then
				if unitNearbyInfo.isGuildmate == true then 
					unitNearbyInfo.strColor = "xkcdWaterBlue"
				end
			end

			if unitNearbyInfo.isFriend == true then
				unitNearbyInfo.strColor = "xkcdVibrantPurple"
			end

			if self.bTrackPvPers == true then 
				if unitNearbyInfo.isAlly == true then
					if unitNearbyInfo.isAllyPvPer then
						unitNearbyInfo.strColor = "xkcdBrightYellow"
					end 
				else
					unitNearbyInfo.strColor = "xkcdBrightOrange"

					if unitNearbyInfo.isEnemyPvPer then
						unitNearbyInfo.strColor = "xkcdBrightRed"

						self.bNearbyPlayers_hostiles = true
					end
				end
			else 
				if unitNearbyInfo.isAlly == false then
					unitNearbyInfo.strColor = "xkcdBrightRed"
				end
			end

			if self.bTrackRPers == true then
				if unitNearbyInfo.isAllyRPer == true then
					unitNearbyInfo.strColor = "xkcdAcidGreen"
				end

				if unitNearbyInfo.isAllyPrvRPer == true then
					unitNearbyInfo.strColor = "xkcdBarbiePink"
				end
			end

			-- counts
			
			if not unitNearbyInfo.isAlly then
				nEnemiesCount = nEnemiesCount + 1
			end

			if unitNearbyInfo.isEnemyPvPer then
				nEnemiesPvPersCount = nEnemiesPvPersCount + 1
			end

			if unitNearbyInfo.isAllyPvPer then
				nAlliesPvPersCount = nAlliesPvPersCount + 1
			end

			if unitNearbyInfo.isGuildmate then
				nGuildmatesCount = nGuildmatesCount + 1
			end

			if unitNearbyInfo.isAllyRPer or unitNearbyInfo.isAllyPrvRPer then
				nAlliesRPersCount = nAlliesRPersCount + 1
			end
			
			if unitNearbyInfo.isFriend then
				nFreindsCount = nFreindsCount + 1
			end

			-- dump to list
			
			self:AddPlayerToList(unitPlayer, unitNearby, unitNearbyInfo) 
		end
	end
	
	nAlliesNormies = nPlayersTotalCount - nEnemiesCount - nAlliesPvPersCount - nGuildmatesCount - nAlliesRPersCount - nFreindsCount

	self.wndPlayersList:ArrangeChildrenVert()

	if self.bTrackPvPers == true then 
		if nEnemiesPvPersCount > 0 then
			self.wndMain:FindChild("WindowTitle"):SetTextColor("xkcdBrightRed")
			self.wndMain:FindChild("WindowMiniTitle"):SetTextColor("xkcdBrightRed")
		else
			if nEnemiesCount > 0 then
				self.wndMain:FindChild("WindowTitle"):SetTextColor("xkcdBrightOrange")
				self.wndMain:FindChild("WindowMiniTitle"):SetTextColor("xkcdBrightOrange")
			else
				self.wndMain:FindChild("WindowTitle"):SetTextColor("UI_TextHoloTitle")
				self.wndMain:FindChild("WindowMiniTitle"):SetTextColor("UI_TextHoloTitle")
			end
		end
	else
		self.wndMain:FindChild("WindowTitle"):SetTextColor("UI_TextHoloTitle")
		self.wndMain:FindChild("WindowMiniTitle"):SetTextColor("UI_TextHoloTitle")
	end

	-- update Btns counts
	self.wndMain:FindChild("AlliesNormiesBtn"):FindChild("Number"):SetText(nAlliesNormies)
	self.wndMain:FindChild("FreindsBtn"):FindChild("Number"):SetText(nFreindsCount)
	self.wndMain:FindChild("AlliesPvPersBtn"):FindChild("Number"):SetText(nAlliesPvPersCount)
	self.wndMain:FindChild("EnemiesPvPersBtn"):FindChild("Number"):SetText(nEnemiesPvPersCount)
	self.wndMain:FindChild("GuildmatesBtn"):FindChild("Number"):SetText(nGuildmatesCount)
	self.wndMain:FindChild("AlliesRPersBtn"):FindChild("Number"):SetText(nAlliesRPersCount)

	-- update Window title
	self.wndMain:FindChild("WindowTitle"):SetText("Nearby Players (" .. nPlayersTotalCount .. ")")
	self.wndMain:FindChild("WindowMiniTitle"):SetText(nPlayersTotalCount)
end

function NearbyPlayers:AddPlayerToList(unitPlayer, unitNearby, unitNearbyInfo)
	if not unitNearby then return end
	if not unitPlayer then return end

	local isAlly	   = false
	local isAllyPvPer  = false
	local isEnemyPvPer = false
	local isGuildmate  = false
	local isAllyRPer   = false
	local isFriend	   = false

	if self.wndMiniMap then
		self.wndMiniMap:RemoveUnit(unitNearby)
	end

	--

	if self.ShowOnlyFreinds and not unitNearbyInfo.isFriend then
		return
	end

	if self.ShowOnlyAlliesPvPers and not unitNearbyInfo.isAllyPvPer then
		return
	end

	if self.ShowOnlyEnemiesPvPers and not unitNearbyInfo.isEnemyPvPer then
		return
	end

	if self.ShowOnlyGuildmates and not unitNearbyInfo.isGuildmate then
		return
	end

	if self.ShowOnlyAlliesRPers and not unitNearbyInfo.isAllyRPer then
		return
	end

	--

	if self.wndMiniMap then
		local tInfo = {}

		tInfo.crObject      = ApolloColor.new(unitNearbyInfo.strColor)
		tInfo.crEdge        = CColor.new(0,0,0,0)
		tInfo.bAboveOverlay = false

		self.wndMiniMap:AddUnit(unitNearby, nil, tInfo, true)
	end

	--

	self:DrawPlayerLine(unitPlayer, unitNearby, unitNearbyInfo)

	self.DrawnPlayerLines = self.DrawnPlayerLines + 1
end
	--
function NearbyPlayers:DrawPlayerLine(unitPlayer, unitNearby, unitNearbyInfo)
	local btnPlayer = Apollo.LoadForm(self.xmlDoc, 'PlayerLine', self.wndPlayersList, self)
	btnPlayer:SetData(unitNearby)

	local wndName	  = btnPlayer:FindChild('ListItemPlayerName')
	local wndDistance = btnPlayer:FindChild('ListItemDistance')
	local wndLevel	  = btnPlayer:FindChild('ListItemLevel')
	local wndClass	  = btnPlayer:FindChild('ListItemClassIcon')
	local wndHealth   = btnPlayer:FindChild('ListItemHealth')

	wndName:SetTextColor(unitNearbyInfo.strColor)

	local unitNearbyTarget = unitNearby:GetTarget()

	wndName:SetText(unitNearby:GetName()) 

	if self.bTrackPlayerTarget == true then
		if unitNearbyTarget then
			wndName:SetText(unitNearby:GetName() .. " > " ..unitNearbyTarget:GetName()) 

			if unitPlayer:GetName() == unitNearbyTarget:GetName() then
				wndName:SetTextColor("BrightSkyBlue")
			end
		end
	end

	if self.bTrackPlayerDistance == true then
		local distance = self:DistanceToUnit(unitNearby)

		if distance >= 999 then
			wndDistance:SetText('-')
		else
			wndDistance:SetText(string.format('%dm', distance)) 
		end

		wndDistance:SetTextColor(unitNearbyInfo.strColor)
	else
		wndDistance:Show(false)
	end

	if self.bTrackPlayerLevel == true then
		wndLevel:SetText(string.format('%s', (unitNearby:GetLevel() or 0)))
		wndLevel:SetTextColor(unitNearbyInfo.strColor)
	else
		wndLevel:Show(false)
	end

	if self.bTrackPlayerClass == true then
		local strClassIconSprite = ktClassToIconPanel[unitNearby:GetClassId()] or ""
		wndClass:SetSprite(strClassIconSprite)
	else
		wndClass:Show(false)
	end

	if self.bTrackPlayerHealth == true then
  		wndHealth:SetMax(unitNearby:GetMaxHealth())
  		wndHealth:SetFloor(0)
  		wndHealth:SetProgress(unitNearby:GetHealth())
		wndHealth:Show(true)
	else
		wndHealth:Show(false)
	end
end

function NearbyPlayers:OnPlayerButton(wndHandler, wndControl, eMouseButton)
	local bLeft = eMouseButton == GameLib.CodeEnumInputMouse.Left
	local bMiddle = eMouseButton == GameLib.CodeEnumInputMouse.Middle
	local unit = wndControl:GetData()

	if bLeft then
		GameLib.SetTargetUnit(unit) 
		
		unit:ShowHintArrow()
	else
		if bMiddle then
			pcall(NearbyPlayers.TriggerWhisper, unit:GetName())
		else
			self.wndPreviewCharacter:SetData(unit)
			self:ShowPlayerModelPreview(unit)
		end
	end
end

function NearbyPlayers.TriggerWhisper(characterName)
	local ChatLog = Apollo.GetAddon("ChatLog")

	if ChatLog then
		for i, wnd in ipairs(ChatLog.tChatWindows) do
			if wnd:IsVisible() then
				local input = wnd:FindChild('Input')

				input:SetText(string.format('/w %s ', characterName))
				ChatLog:OnInputChanged(input, input, input:GetText())

				input:ClearFocus()
				input:SetFocus()
			end
		end
	end

	local Jita = Apollo.GetAddon("Jita")

	if Jita and Jita.Client then
		Jita.Client:OnEngageWhisper(characterName)
	end 
end

function NearbyPlayers:OnListBtnCheck(wndHandler, wndControl, eMouseButton) 
	local data = wndControl:GetData()

	if not data then
		return
	end

	self.ShowOnlyAlliesNormies = false
	self.ShowOnlyFreinds	   = false
	self.ShowOnlyAlliesPvPers  = false
	self.ShowOnlyEnemiesPvPers = false
	self.ShowOnlyGuildmates	   = false
	self.ShowOnlyAlliesRPers   = false

	self.wndMain:FindChild("AlliesNormiesBtn"):SetCheck(false)
	self.wndMain:FindChild("FreindsBtn"):SetCheck(false)
	self.wndMain:FindChild("AlliesPvPersBtn"):SetCheck(false)
	self.wndMain:FindChild("EnemiesPvPersBtn"):SetCheck(false)
	self.wndMain:FindChild("GuildmatesBtn"):SetCheck(false)
	self.wndMain:FindChild("AlliesRPersBtn"):SetCheck(false)
	self.wndMain:FindChild(data .. "Btn"):SetCheck(true)

	if data == "AlliesNormies" then
		self.ShowOnlyAlliesNormies = true
	end

	if data == "Freinds" then
		self.ShowOnlyFreinds = true
	end

	if data == "AlliesPvPers" then
		self.ShowOnlyAlliesPvPers = true
	end

	if data == "EnemiesPvPers" then
		self.ShowOnlyEnemiesPvPers = true
	end

	if data == "Guildmates" then
		self.ShowOnlyGuildmates = true
	end

	if data == "AlliesRPers" then
		self.ShowOnlyAlliesRPers = true
	end

	self:PopulateNearbyPlayersList(true) 
end

function NearbyPlayers:OnListBtnUncheck(wndHandler, wndControl, eMouseButton) 
	local data = wndControl:GetData()

	if not data then
		return
	end

	self.ShowOnlyAlliesNormies = false
	self.ShowOnlyFreinds	   = false
	self.ShowOnlyAlliesPvPers  = false
	self.ShowOnlyEnemiesPvPers = false
	self.ShowOnlyGuildmates    = false
	self.ShowOnlyAlliesRPers   = false

	self.wndMain:FindChild("AlliesNormiesBtn"):SetCheck(false)
	self.wndMain:FindChild("FreindsBtn"):SetCheck(false)
	self.wndMain:FindChild("AlliesPvPersBtn"):SetCheck(false)
	self.wndMain:FindChild("EnemiesPvPersBtn"):SetCheck(false)
	self.wndMain:FindChild("GuildmatesBtn"):SetCheck(false)
	self.wndMain:FindChild("AlliesRPersBtn"):SetCheck(false)

	self:PopulateNearbyPlayersList(true) 
end

function NearbyPlayers:OnRadarBtnCheck(wndHandler, wndControl, eMouseButton)
	local nLeft, nTop, nRight, nBottom = self.wndPlayersList:GetAnchorOffsets()
	self.wndPlayersList:SetAnchorOffsets(nLeft, 253, nRight, nBottom)

	self.PixieID = self.wndMain:AddPixie(self.PixieInfo)
	
	self.RadarWindow = Apollo.LoadForm(self.xmlDoc, "RadarWindow", self.wndMain, self)
	self.RadarWindow = Apollo.LoadForm(self.xmlDoc, "RadarWindow", self.wndMain, self)

	self.wndMiniMap     = self.RadarWindow:FindChild("MiniMap")
	self.wndMiniMapRing = self.RadarWindow:FindChild("MiniMapRing")

	self.wndMiniMap:SetMapOrientation(0)
	self.wndMiniMap:SetZoomLevel(2) 

	self.RadarWindow:Show(true) 

	self.wndMain:FindChild("WindowTitle"):Show(false)
	self.wndMain:FindChild("WindowMiniTitle"):Show(true)

	self.bShowRadar = true
end

function NearbyPlayers:OnRadarBtnUncheck(wndHandler, wndControl, eMouseButton)
	self.RadarWindow:Show(false) 

	self.RadarWindow:Destroy()

	self.RadarWindow    = nil
	self.wndMiniMap     = nil
	self.wndMiniMapRing = nil
	
	self.wndMain:DestroyPixie(self.PixieID)

	local nLeft, nTop, nRight, nBottom = self.wndPlayersList:GetAnchorOffsets()
	self.wndPlayersList:SetAnchorOffsets(nLeft, 29, nRight, nBottom)

	self.wndMain:FindChild("WindowTitle"):Show(true)
	self.wndMain:FindChild("WindowMiniTitle"):Show()

	self.bShowRadar = false
end

-----------------------------------------------------------------------------------------------
-- Preview Player Model
-----------------------------------------------------------------------------------------------

function NearbyPlayers:ShowPlayerModelPreview(unit)
	local unitTarget = unit:GetTarget() 
	
	if not unitTarget then
		self.wndPreviewCharacter:FindChild('TargetTargetPortrait'):Show(false) 
	else
		self.wndPreviewCharacter:FindChild('TargetTargetPortrait'):SetCostume(unitTarget) 
		self.wndPreviewCharacter:FindChild('TargetTargetPortrait'):Show(true) 
	end

	self.wndPreviewCharacter:FindChild('PlayerName'):SetText(unit:GetName()) 
	
	local unitInfos = ""
	local unitGuild = unit:GetGuildName()

	if unitGuild then 
		unitInfos = "Tag: " .. unitGuild .. "\n"
	end

	if unit:GetFaction() == Unit.CodeEnumFaction.DominionPlayer then
		unitInfos = unitInfos .. "Faction: Dominion\n"
	elseif unit:GetFaction() == Unit.CodeEnumFaction.ExilesPlayer then
		unitInfos = unitInfos .. "Faction: Exile\n" -- scum
	end

	if  unitTarget then
		unitInfos = unitInfos .. "Target: " .. unitTarget:GetName() .. "\n"
	end

	if  unit:IsFriend() or unit:IsAccountFriend() then
		unitInfos = unitInfos .. "Friend\n"
	end

	if unit:IsPvpFlagged() then
		unitInfos = unitInfos .. "PvPer\n"
	end

	if self.tRPTracked[unit:GetName()] ~= nil then
		unitInfos = unitInfos .. "RPer\n"
	end

	self.wndPreviewCharacter:FindChild('PlayerInfos'):SetText(unitInfos) 

	self.wndPreviewCharacter:FindChild('TargetPortrait'):SetCostume(unit)
	self.wndPreviewCharacter:FindChild('TargetPortrait'):SetCamera("Paperdoll")
	self.wndPreviewCharacter:FindChild('TargetPortrait'):SetSpin(0)
	self.wndPreviewCharacter:FindChild('TargetPortrait'):SetSheathed(true)

	-- Default_Dominion_StartScreen_Loop_01 = 7723 ,
	-- Default_Exile_StartScreen_Loop_01 = 7724 ,
	if unit:GetFaction() == Unit.CodeEnumFaction.DominionPlayer then
		self.wndPreviewCharacter:FindChild("TargetPortrait"):SetModelSequence(7723)
	elseif unit:GetFaction() == Unit.CodeEnumFaction.ExilesPlayer then
		self.wndPreviewCharacter:FindChild("TargetPortrait"):SetModelSequence(7724)
	end

	self.wndPreviewCharacter:Show(true)

	unit:ShowHintArrow()
end

function NearbyPlayers:OnActionsBtnClick()
	local unit = self.wndPreviewCharacter:GetData()

	if unit ~= nil then
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", nil, unit:GetName(), unit)
	end
end

function NearbyPlayers:CloseBtnClick()
	self.wndPreviewCharacter:Close() -- hide the window
end

-----------------------------------------------------------------------------------------------
-- Configure Form
-----------------------------------------------------------------------------------------------

function NearbyPlayers:OnConfigure() 
	self.wndConfigure:Show(true)
end

function NearbyPlayers:OnCloseConfigure(wndHandler, wndControl, eMouseButton) 
	self.wndConfigure:Show(false)
end

function NearbyPlayers:OnCheckbox(wndHandler, wndControl)
	local setting = wndControl:GetData()
	local value = wndHandler:IsChecked()

	if setting == "TrackPvPers" then
		self.bTrackPvPers = value
	end

	if setting == "TrackRPers" then
		self.bTrackRPers = value

		if self.bTrackRPers == true then
			self:PollRPChannels()
		end
	end

	if setting == "TrackGuildies" then
		self.bTrackGuildies = value
	end

	if setting == "TrackPlayerDistance" then
		self.bTrackPlayerDistance = value
	end

	if setting == "TrackPlayerLevel" then
		self.bTrackPlayerLevel = value
	end

	if setting == "TrackPlayerClass" then
		self.bTrackPlayerClass = value
	end

	if setting == "TrackPlayerHealth" then
		self.bTrackPlayerHealth = value
	end

	if setting == "TrackPlayerTarget" then
		self.bTrackPlayerTarget = value
	end

	if setting == "DisplayHostileNPCOnRadar" then
		self.bDisplayHostileNPCOnRadar = value
	end

	if setting == "HideMiniMap" then
		self.bHideMiniMap = value
	end

	if self.bHideMiniMap == true then
		self.MiniMapTimer = ApolloTimer.Create(0.1, true, "OnHideMiniMapTimer" , self)
	else
		self.MiniMapTimer = ApolloTimer.Create(0.1, true, "OnShowMiniMapTimer" , self)
	end

	self:PopulateNearbyPlayersList(true)
end

function NearbyPlayers:OnRPChannelListChanged(wndHandler, wndControl, strText)
	self.strRPChatChannels = wndHandler:GetText()
	
	self.tRPChannelNames = self:SplitString(self.strRPChatChannels)
end

-----------------------------------------------------------------------------------------------
-- Utilities & stuff
-----------------------------------------------------------------------------------------------

function NearbyPlayers:DistanceToUnit(unitTarget)
	local unitPlayer = GameLib.GetPlayerUnit()

	if not unitPlayer then return 0 end
	if not unitTarget then return 0 end

	local loc1 = unitPlayer:GetPosition()
	local loc2 = unitTarget:GetPosition()

	if not loc1 then return 0 end
	if not loc2 then return 0 end

	local tVec = {}

	for axis, value in pairs(loc1) do
		tVec[axis] = loc1[axis] - loc2[axis]
	end

	local vVec = Vector3.New(tVec['x'], tVec['y'], tVec['z'])

	return math.floor(vVec:Length())+1
end

function NearbyPlayers:IsHostileUnit(unitPlayer, unitTracked)
	if not unitPlayer then
		return nil
	end
 
	if unitTracked ~=nil then 
		if unitTracked:GetDispositionTo(unitPlayer) == Unit.CodeEnumDisposition.Hostile then
			return true
		else
			return false
		end 
	end

	return nil
end

function NearbyPlayers:tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function NearbyPlayers:SplitString(str)
	local tNames = {}
	str = string.lower(str)
	local pattern = '%a+,'

	for name in string.gmatch(str, pattern) do
		table.insert(tNames, string.sub(name, 1, (string.len(name) - 1)))
	end

	return tNames
end

-----------------------------------------------------------------------------------------------
-- NearbyPlayers Instance
-----------------------------------------------------------------------------------------------

local NearbyPlayersInstance = NearbyPlayers:new()
NearbyPlayersInstance:Initialize()
