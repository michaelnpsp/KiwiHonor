-- ============================================================================
-- KiwiHonor (C) 2025 MiCHaEL
-- ============================================================================

local addonName, addonTbl = ...

-- libraries
local lkf = LibStub("LibKiwiDisplayFrame-1.0", true)

-- main frame
local addon = lkf:CreateFrame(addonName, addonTbl)

-- database profile defaults
addon.defaults = {
	-- text lines to hide
	display = {},
	-- frame appearance
	frame = lkf.defaults,
	-- minimap icon
	minimapIcon = {hide=false},
	-- details plugin enabled
	details = false,
}

-- local references
local time = time
local type = type
local print = print
local pairs = pairs
local tonumber = tonumber
local tconcat = table.concat
local max = math.max
local floor = math.floor
local ceil = math.ceil
local format = string.format
local C_Timer_After = C_Timer.After
local GetZoneText = GetZoneText
local IsInInstance = IsInInstance
local GetInstanceInfo = GetInstanceInfo
local GetPVPThisWeekStats = GetPVPThisWeekStats

-- localization
local L = addonTbl.L

-- temporary table
local tempTable = {}

-- ============================================================================
-- utils functions
-- ============================================================================

-- safe rounded division
local function safedivceil(dividend, divisor, default)
	if dividend and divisor and divisor~=0 then
		return ceil( dividend / divisor )
	else
		return default or nil
	end
end

-- calculate honor per hour
local function gethph(honor, elapsed)
	if honor and elapsed then
		return elapsed>0 and ceil(3600*honor/elapsed) or 0
	else
		return nil
	end
end

-- format duration
local function FmtDurationHM(seconds)
	if seconds then
		local m = floor(seconds/60)
		local h = floor(m/60)
		return h>0 and format("%d|cffeda55fh|r %d|cffeda55fm|r",h,m%60) or format("%d|cffeda55fm|r",m%60)
	else
		return '-'
	end
end

-- format countdown
local function FmtCountdownHM(seconds)
	if seconds then
		local m = ceil(seconds/60)
		local h = floor(m/60)
		return h>0 and format("%d|cffeda55fh|r %d|cffeda55fm|r",h,m%60) or format("%d|cffeda55fm|r",m%60)
	else
		return '-'
	end
end

-- format honor
local function FmtHonor(honor)
	if honor then
		return honor<1000 and honor or format("%.1f|cff00c000k|r",honor/1000)
	else
		return '-'
	end
end

-- format zone name
local function FmtZone(text)
	return format("|cFF7FFF72%s|r", text or '-')
end

-- get weekly honor gained
local function GetWeekHonor()
	local _, honor = GetPVPThisWeekStats()
	return honor
end

-- ============================================================================
-- addon methods
-- ============================================================================

function addon:InitDatabase()
	self.db = {}
	self.db.profile, self.db.profileName, self.db.sv = lkf:SetDatabaseProfile(addonName..'DB', addon.defaults, true)
	self.db.stats = lkf:SetDatabaseSection(self.db.sv, 'stats', lkf.charKey)
	self.InitDatabase = nil
	return self.db.profile
end

function addon:ShowTooltip(tooltip)
	tooltip:AddDoubleLine(addonName, C_AddOns.GetAddOnMetadata(addonName, "Version"))
	if self.plugin then
		tooltip:AddLine(L["|cFFff4040Left or Right Click|r to open menu"], 0.2, 1, 0.2)
	else
		tooltip:AddLine(L["|cFFff4040Left Click|r toggle visibility\n|cFFff4040Right Click|r open menu"], 0.2, 1, 0.2)
	end
end

function addon:LayoutContent()
	local function register(disabled, left)
		if disabled then return end
		tempTable[#tempTable+1] = L[left] .. ':'
	end
	local dd = self.db.profile.display
	local bg = self.db.stats.bgTimeStart
	register(dd.zone, "|cFF7FFF72KiwiHonor" )
	register(dd.bg_duration, bg and "Bg duration" or "Bg duration (avg)" )
	register(dd.bg_honor, bg and "Bg honor" or "Bg honor (avg)")
	register(dd.bg_hph, bg and "Bg honor/h" or "Bg honor/h (avg)")
	register(dd.sn_duration, "Session duration")
	register(dd.sn_honor, "Session honor")
	register(dd.sn_hph, "Session honor/h")
	register(dd.hr_week, "Honor week")
	register(dd.hr_remain, "Honor remain")
	register(dd.hr_goalin, "Honor goal in")
	self.textLeft:SetText( tconcat(tempTable,"|r\n") )
	wipe(tempTable)
end

function addon:UpdateContent(wkHonorOpt)
	if not self._zoneName or not self:IsVisible() then return end
	local db = self.db.stats
	local dp = self.db.profile.display
	local ctime = time()
	local wkHonor = tonumber(wkHonorOpt) or GetWeekHonor()
	-- session
	local snTimeStart = db.snTimeStart
	local snElapsed = snTimeStart and ctime-snTimeStart or 0
	local snHonor = snTimeStart and wkHonor-db.snHonorStart
	local snHPH = snTimeStart and gethph(snHonor, snElapsed)
	local bgTimeStart = db.bgTimeStart
	-- current bg
	local bgHonor = bgTimeStart and wkHonor-db.bgHonorStart or safedivceil(db.snBgHonor, db.snBgCount)
	local bgElapsed = bgTimeStart and ctime-bgTimeStart or safedivceil(db.snBgTime, db.snBgCount)
	local bgHPH = bgTimeStart and gethph(bgHonor, bgElapsed) or gethph(db.snBgHonor, db.snBgTime)
	-- week honor
	local wkHonorRemain = db.wkHonorGoal and max(db.wkHonorGoal - wkHonor, 0)
	local wkHonorTimeRemain = wkHonorRemain and ((wkHonorRemain==0 and 0) or safedivceil(wkHonorRemain*3600, snHPH))
	-- display data
	if not dp.zone         then tempTable[#tempTable+1] = FmtZone(self._zoneNameShort) end
	if not dp.bg_duration  then tempTable[#tempTable+1] = FmtDurationHM(bgElapsed) end
	if not dp.bg_honor     then tempTable[#tempTable+1] = FmtHonor(bgHonor) end
	if not dp.bg_hph       then tempTable[#tempTable+1] = FmtHonor(bgHPH) end
	if not dp.sn_duration  then tempTable[#tempTable+1] = FmtDurationHM(snTimeStart and snElapsed) end
	if not dp.sn_honor     then tempTable[#tempTable+1] = FmtHonor(snHonor) end
	if not dp.sn_hph       then tempTable[#tempTable+1] = FmtHonor(snHPH) end
	if not dp.hr_week      then tempTable[#tempTable+1] = FmtHonor(wkHonor~=0 and wkHonor) end
	if not dp.hr_remain    then tempTable[#tempTable+1] = FmtHonor(wkHonorRemain) end
	if not dp.hr_goalin    then tempTable[#tempTable+1] = FmtCountdownHM(wkHonorTimeRemain) end
	self.textRight:SetText( tconcat(tempTable,"\n") )
	wipe(tempTable)
	-- update timer
	if snTimeStart and not self.timerEnabled then self:EnableTimer(ctime) end
end

function addon:EnableTimer(ctime)
	if self then -- init, self==nil => called from C_Timer
		addon.timerEnabled = true
	elseif addon.db.stats.snTimeStart and addon:IsVisible() then  -- tick
		ctime = time()
		addon:UpdateContent()
	else
		addon.timerEnabled = nil
		return
	end
	C_Timer_After( 60.5-ctime%60, addon.EnableTimer)
end

function addon:StartBattleground()
	local db = self.db.stats
	if db.bgZoneName then return end
	db.bgZoneName = self._zoneName
	db.bgTimeStart = time()
	db.bgHonorStart = GetWeekHonor()
	db.snTimeStart = db.snTimeStart or db.bgTimeStart
	db.snHonorStart = db.snHonorStart or db.bgHonorStart
	self:LayoutContent()
	self:UpdatContent(db.bgHonorStart)
end

function addon:FinishBattleground()
	local db = self.db.stats
	if not db.bgZoneName then return end
	db.snBgCount = (db.snBgCount or 0) + 1
	db.snBgTime = (db.snBgTime or 0) + (time()-db.bgTimeStart)
	db.snBgHonor = (db.snBgHonor or 0) + (GetWeekHonor()-db.bgHonorStart)
	db.bgZoneName = nil
	db.bgTimeStart = nil
	db.bgHonorStart = nil
	self:LayoutContent()
	self:UpdateContent()
end

function addon:StartSession()
	local db = self.db.stats
	db.snBgCount = nil
	db.snBgHonor = nil
	db.snBgTime = nil
	db.snTimeStart = db.bgTimeStart or time()
	db.snHonorStart = db.bgHonorStart or GetWeekHonor()
	self:UpdateContent()
end

function addon:FinishSession()
	local db = self.db.stats
	db.snBgCount = nil
	db.snBgHonor = nil
	db.snBgTime = nil
	db.snTimeStart = db.bgTimeStart or nil
	db.snHonorStart = db.bgHonorStart or nil
	self:UpdateContent()
end

function addon:ZONE_CHANGED_NEW_AREA(event, isLogin)
	if event=='PLAYER_ENTERING_WORLD' and isLogin and self.db.stats.snTimeStart and time()-self.db.stats.snTimeStart>3600 then
		wipe(self.db.stats)
	end
	local inInstance, instanceType = IsInInstance()
	local zone = inInstance and GetInstanceInfo() or GetZoneText()
	if zone and zone~='' then
		local zoneKey = format("%s:%s",zone,tostring(inInstance))
		if zoneKey ~= self.lastZoneKey or (not event) then -- no event => called from config
			self._zoneName = zone
			self._zoneNameShort = #zone<16 and zone or strsplit(" ",zone,2)
			self.lastZoneKey = zoneKey
		end
	end
	self.instanceType = instanceType~='none' and instanceType or nil
	if instanceType == 'pvp' then
		self:StartBattleground()
	else
		self:FinishBattleground()
	end
	self:UpdateContent()
	self:SetShown(self.dbframe.visible)
end
addon.PLAYER_ENTERING_WORLD = addon.ZONE_CHANGED_NEW_AREA

addon.CHAT_MSG_COMBAT_HONOR_GAIN = addon.UpdateContent
addon.CHAT_MSG_BG_SYSTEM_NEUTRAL = addon.UpdateContent
addon.UPDATE_BATTLEFIELD_SCORE   = addon.UpdateContent
addon.PLAYER_PVP_KILLS_CHANGED   = addon.UpdateContent

-- ============================================================================
-- addon entry point
-- ============================================================================

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function(frame, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addon.__loaded = true
	end
	if not (addon.__loaded and IsLoggedIn()) then return end
	-- unregister init events
	addon:UnregisterAllEvents()
	-- database setup
	local profile = addon:InitDatabase()
	-- compartment icon
	lkf:RegisterCompartment(addonName, addon, "MouseClick")
	-- minimap icon
	lkf:RegisterMinimapIcon(addonName, addon, profile.minimapIcon, "MouseClick", "ShowTooltip")
	-- events
	addon:SetScript('OnEvent', lkf.DispatchEvent)
	addon:RegisterEvent("PLAYER_ENTERING_WORLD")
	addon:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	addon:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
	addon:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
	addon:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
	addon:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
	-- setup display
	lkf:SetupAddon(addon, profile.frame, profile.details)
end)
