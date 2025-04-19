-- ============================================================================
-- KiwiHonor (C) 2025 MiCHaEL
-- ============================================================================

local addonName = ...

-- libraries
local lkf = LibStub("LibKiwiDisplayFrame-1.0", true)

-- main frame
local addon = lkf:CreateFrame(addonName)

-- addon version
addon.versionToc = C_AddOns.GetAddOnMetadata(addonName, "Version")
addon.versionStr = (addon.versionToc=='\@project-version\@' and 'Dev' or addon.versionToc)

-- addon icon
addon.iconFile = "Interface\\AddOns\\KiwiHonor\\KiwiHonor.tga"

-- localization
local L = setmetatable( {}, { __index = function(t,k) return k; end } )
addon.L = L

-- database defaults
addon.DEFAULTS = {
	-- honor info
	bgZoneName = nil,
	bgTimeStart = nil,
	bgHonorStart = nil,
	snTimeStart = nil,
	snHonorStart = nil,
	snBgCount = nil,
	snBgHonor = nil,
	snBgTime = nil,
	wkHonorGoal = nil,
	-- text sections to hide
	display = {},
	-- frame appearance
	visible = true, -- main frame visibility
	backColor = {0,0,0,.5},
	borderColor = {1,1,1,1},
	borderTexture = nil,
	rowEnabled = nil,
	rowTexture = nil,
	rowColor = nil,
	spacing = 1,
	fontName = nil,
	fontSize = nil,
	frameWidth = 2/3,
	frameMargin = 4,
	frameStrata = nil,
	framePos = {anchor='TOPLEFT', x=0, y=0},
	-- minimap icon
	minimapIcon = {hide=false},
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

-- ============================================================================
-- utils functions
-- ============================================================================

-- initialize addon database
local InitDB
do
	local function copy(dst, src)
		for k,v in pairs(src) do
			if type(v)=="table" then
				dst[k] = copy(dst[k] or {}, v)
			elseif dst[k]==nil then
				dst[k] = v
			end
		end
		return dst
	end
	function InitDB()
		KiwiHonorDB = KiwiHonorDB or {profilePerChar={}}
		local charKey = UnitName("player") .. " - " .. GetRealmName()
		local profiles = KiwiHonorDB.profilePerChar
		profiles[charKey] = copy( profiles[charKey] or {}, addon.DEFAULTS )
		return profiles[charKey], KiwiHonorDB
	end
end

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

function addon:LayoutContent()
	local data_titles = self.data_titles
	local function register(disabled, left)
		if disabled then return end
		data_titles[#data_titles+1] = L[left] .. ':'
	end
	local dd = self.db.display
	local bg = self.db.bgTimeStart
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
	self.textLeft:SetText( tconcat(data_titles,"|r\n") )
	wipe(data_titles)
end

function addon:UpdateContent(wkHonorOpt)
	if not self._zoneName or not self:IsVisible() then return end
	local db = self.db
	local dp = db.display
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
	local data_values = self.data_values
	if not dp.zone         then data_values[#data_values+1] = FmtZone(self._zoneNameShort) end
	if not dp.bg_duration  then data_values[#data_values+1] = FmtDurationHM(bgElapsed) end
	if not dp.bg_honor     then data_values[#data_values+1] = FmtHonor(bgHonor) end
	if not dp.bg_hph       then data_values[#data_values+1] = FmtHonor(bgHPH) end
	if not dp.sn_duration  then data_values[#data_values+1] = FmtDurationHM(snTimeStart and snElapsed) end
	if not dp.sn_honor     then data_values[#data_values+1] = FmtHonor(snHonor) end
	if not dp.sn_hph       then data_values[#data_values+1] = FmtHonor(snHPH) end
	if not dp.hr_week      then data_values[#data_values+1] = FmtHonor(wkHonor~=0 and wkHonor) end
	if not dp.hr_remain    then data_values[#data_values+1] = FmtHonor(wkHonorRemain) end
	if not dp.hr_goalin    then data_values[#data_values+1] = FmtCountdownHM(wkHonorTimeRemain) end
	self.textRight:SetText( tconcat(data_values,"\n") )
	wipe(data_values)
	-- update timer
	if snTimeStart and not self.timerEnabled then self:EnableTimer(ctime) end
end

function addon:EnableTimer(ctime)
	if self then -- init
		addon.timerEnabled = true
	elseif addon.db.snTimeStart and addon:IsVisible() then  -- tick
		ctime = time()
		addon:UpdateContent()
	else
		addon.timerEnabled = nil
		return
	end
	C_Timer_After( 60.5-ctime%60, addon.EnableTimer)
end

function addon:StartBattleground()
	local db = self.db
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
	local db = self.db
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
	local db = self.db
	db.snBgCount = nil
	db.snBgHonor = nil
	db.snBgTime = nil
	db.snTimeStart = db.bgTimeStart or time()
	db.snHonorStart = db.bgHonorStart or GetWeekHonor()
	addon:UpdateContent()
end

function addon:FinishSession()
	local db = self.db
	db.snBgCount = nil
	db.snBgHonor = nil
	db.snBgTime = nil
	db.snTimeStart = db.bgTimeStart or nil
	db.snHonorStart = db.bgHonorStart or nil
	addon:UpdateContent()
end

function addon:ZONE_CHANGED_NEW_AREA(event, isLogin)
	if event=='PLAYER_ENTERING_WORLD' and isLogin and self.db.snTimeStart and time()-self.db.snTimeStart>3600 then
		self.db.bgZoneName = nil
		self.db.bgTimeStart = nil
		self.db.bgHonorStart = nil
		self.db.snTimeStart = nil
		self.db.snHonorStart = nil
		self.db.snBgCount = nil
		self.db.snBgHonor = nil
		self.db.snBgTime = nil
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
	self:SetShown(self.db.visible)
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
	addon.db = InitDB()
	-- temp tables
	addon.data_titles = {}
	addon.data_values = {}
	-- compartment icon
	if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
		AddonCompartmentFrame:RegisterAddon({
			text = addonName,
			icon  = addon.iconFile,
			registerForAnyClick = true,
			notCheckable = true,
			func = function(_,_,_,_,button) addon:MouseClick(button); end,
		})
	end
	-- minimap icon
	LibStub("LibDBIcon-1.0"):Register(addonName, LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
		type  = "launcher",
		label = C_AddOns.GetAddOnInfo(addonName, "Title"),
		icon  = addon.iconFile,
		OnClick = function(_, button) addon:MouseClick(button); end,
		OnTooltipShow = function(tooltip)
			tooltip:AddDoubleLine(addonName, addon.versionStr)
			if addon.plugin then
				tooltip:AddLine(L["|cFFff4040Left or Right Click|r to open menu"], 0.2, 1, 0.2)
			else
				tooltip:AddLine(L["|cFFff4040Left Click|r toggle visibility\n|cFFff4040Right Click|r open menu"], 0.2, 1, 0.2)
			end
		end,
	}) , addon.db.minimapIcon)
	-- events
	addon:SetScript('OnEvent', function(self,event,...) self[event](self,event,...) end)
	addon:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	addon:RegisterEvent("PLAYER_ENTERING_WORLD")
	addon:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
	addon:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
	addon:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
	addon:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
	-- display setup
	lkf:SetupAddon(addon, nil, addon.db.details, addon.iconFile, L["Display battlegrounds Honor stats."], "MiCHaEL", addon.versionStr)
end)
