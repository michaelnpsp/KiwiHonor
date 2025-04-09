-- ============================================================================
-- KiwiHonor (C) 2025 MiCHaEL
-- ============================================================================

local addonName = ...

-- main frame
local addon = CreateFrame('Frame', "KiwiHonor", UIParent, BackdropTemplateMixin and "BackdropTemplate")

-- libraries
local lkm = LibStub("LibKiwiDropDownMenu-1.0", true)

-- game version
local VERSION = select(4,GetBuildInfo())
local VANILA = VERSION<30000
local CLASSIC = VERSION<90000
local RETAIL = VERSION>=90000

-- addon version
local GetAddOnInfo = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local versionToc = GetAddOnMetadata(addonName, "Version")
local versionStr = (versionToc=='\@project-version\@' and 'Dev' or versionToc)

-- player GUID
local playerGUID = UnitGUID("player")

-- default values
local COLOR_WHITE = { 1,1,1,1 }
local COLOR_TRANSPARENT = { 0,0,0,0 }
-- database defaults
local DEFAULTS = {
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
	backColor = {0,0,0,.4},
	borderColor = {1,1,1,1},
	borderTexture = nil,
	fontName = nil,
	fontsize = nil,
	frameMargin = 4,
	frameStrata = nil,
	framePos = {anchor='TOPLEFT', x=0, y=0},
	-- minimap icon
	minimapIcon = {hide=false},
}

local BackdropCfg = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = nil, -- config.borderTexture
	tile = true, tileSize = 8, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local BackdropDef = {
	bgFile = "Interface\\Buttons\\WHITE8X8"
}

-- local references
local time = time
local date = date
local type = type
local next = next
local print = print
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local select = select
local tinsert = tinsert
local tremove = tremove
local tonumber = tonumber
local gsub = gsub
local strfind = strfind
local strlower = strlower
local max = math.max
local floor = math.floor
local ceil = math.ceil
local format = string.format
local band = bit.band
local strmatch = strmatch
local C_Timer_After = C_Timer.After
local GetZoneText = GetZoneText
local IsInInstance = IsInInstance
local GetInstanceInfo = GetInstanceInfo

local L = setmetatable( {}, { __index = function(t,k) return k; end } )

-- ============================================================================
-- utils & misc functions
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
		profiles[charKey] = copy( profiles[charKey] or {}, DEFAULTS )
		return profiles[charKey], KiwiHonorDB
	end
end

-- truncate string
local strcut
do
	local strbyte = string.byte
	function strcut(s, c)
		local l, i = #s, 1
		while c>0 and i<=l do
			local b = strbyte(s, i)
			if     b < 192 then	i = i + 1
			elseif b < 224 then i = i + 2
			elseif b < 240 then	i = i + 3
			else				i = i + 4
			end
			c = c - 1
		end
		return s:sub(1, i-1)
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
local function gethph( honor, elapsed, noZero)
	if honor and elapsed and elapsed>=1 then
		local hph = ceil( 3600 * honor / elapsed )
		if (not noZero) or hph~=0 then
			return hph
		end
	end
	return nil
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

-- get weekly honor gained
local function GetWeekHonor()
	local _, honor = GetPVPThisWeekStats()
	return honor
end

-- fonts
local function SetTextFont(widget, name, size, flags)
	local loaded = widget:SetFont(name or lkm.FONTS.Arial or STANDARD_TEXT_FONT, size or 14, flags or 'OUTLINE')
	if not widget:GetFont() then
		widget:SetFont(STANDARD_TEXT_FONT, size or 14, flags or 'OUTLINE')
	end
	return loaded
end

-- dialogs
do
	local DUMMY = function() end
	StaticPopupDialogs["KIWIHONOR_DIALOG"] = { timeout = 0, whileDead = 1, hideOnEscape = 1, button1 = ACCEPT, button2 = CANCEL }

	function addon:ShowDialog(message, textDefault, funcAccept, funcCancel, textAccept, textCancel)
		local t = StaticPopupDialogs["KIWIHONOR_DIALOG"]
		t.OnShow = function (self) if textDefault then self.editBox:SetText(textDefault) end; self:SetFrameStrata("TOOLTIP") end
		t.OnHide = function(self) self:SetFrameStrata("DIALOG")	end
		t.hasEditBox = textDefault and true or nil
		t.text = message
		t.button1 = funcAccept and (textAccept or ACCEPT) or nil
		t.button2 = funcCancel and (textCancel or CANCEL) or nil
		t.OnCancel = funcCancel
		t.OnAccept = funcAccept and function (self)	funcAccept( textDefault and self.editBox:GetText() ) end or nil
		StaticPopup_Show("KIWIHONOR_DIALOG")
	end

	function addon:MessageDialog(message, funcAccept)
		addon:ShowDialog(message, nil, funcAccept or DUMMY)
	end

	function addon:ConfirmDialog(message, funcAccept, funcCancel, textAccept, textCancel)
		self:ShowDialog(message, nil, funcAccept, funcCancel or DUMMY, textAccept, textCancel )
	end

	function addon:EditDialog(message, text, funcAccept, funcCancel)
		self:ShowDialog(message, text or "", funcAccept, funcCancel or DUMMY)
	end
end

-- ============================================================================
-- addon specific functions
-- ============================================================================

function addon:MouseClick(button)
	if button == 'RightButton' then
		self:ShowMenu()
	else
		self:ToggleFrameVisibility()
	end
end

-- restore main frame position
function addon:RestorePosition()
	local config = self.db
	addon:ClearAllPoints()
	addon:SetPoint( config.framePos.anchor, UIParent, 'CENTER', config.framePos.x, config.framePos.y )
end

-- save main frame position
function addon:SavePosition()
	local config = self.db
	local p, cx, cy = config.framePos, UIParent:GetCenter() -- we are assuming addon frame scale=1 in calculations
	local x = (p.anchor:find("LEFT")   and addon:GetLeft())   or (p.anchor:find("RIGHT") and addon:GetRight()) or addon:GetLeft()+addon:GetWidth()/2
	local y = (p.anchor:find("BOTTOM") and addon:GetBottom()) or (p.anchor:find("TOP")   and addon:GetTop())   or addon:GetTop() -addon:GetHeight()/2
	p.x, p.y = x-cx, y-cy
end

-- frame sizing
function addon:UpdateFrameSize()
	local config = self.db
	addon:SetHeight( self.textLeft:GetHeight() + config.frameMargin*2 )
	addon:SetWidth( config.frameWidth or (self.textLeft:GetWidth() * 1.50) + config.frameMargin*2 )
	self:SetScript('OnUpdate', nil)
end

-- update text fonts
function addon:UpdateFrameFonts()
	local config = addon.db
	local l = SetTextFont(self.textLeft, config.fontName, config.fontSize, 'OUTLINE')
	local r = SetTextFont(self.textRight, config.fontName, config.fontSize, 'OUTLINE')
	addon:SetScript("OnUpdate", self.UpdateFrameSize)
	return l and r
end

-- change main frame visibility: nil == toggle visibility
function addon:ToggleFrameVisibility(visible)
	if visible == nil then
		visible = not self:IsShown()
	end
	self:SetShown(visible)
	self.db.visible = visible
end

-- timer to refresh data every minute
do
	local function TimerUpdate()
		if addon.db.snTimeStart and addon:IsVisible() then
			addon:UpdateHonorStats()
			C_Timer_After( 60.5-time()%60, TimerUpdate)
		else
			addon.timerEnabled = nil
		end
	end
	function addon:EnableTimer(ctime)
		self.timerEnabled = true
		C_Timer_After( 60.5-ctime%60, TimerUpdate)
	end
end

-- prepare content to display info
do
	local function register(disabled, left, right)
		if disabled then return end
		addon.text_head = addon.text_head .. L[left] .. ":|r\n"
		addon.text_mask = addon.text_mask .. (right or "%s") .. "\n"
	end
	function addon:LayoutContent()
		local dd = self.db.display
		local bg = self.db.bgTimeStart
		self.text_mask, self.text_head = '', ''
		register(false, "|cFF7FFF72KiwiHonor", "|cFF7FFF72%s|r")
		register(dd.battleground, bg and "Bg duration" or "Bg duration (avg)" )
		register(dd.battleground, bg and "Bg honor" or "Bg honor (avg)")
		register(dd.battleground, bg and "Bg honor/h" or "Bg honor/h (avg)")
		register(dd.session, "Session duration")
		register(dd.session, "Session honor")
		register(dd.session, "Session Honor/h")
		register(dd.honor, "Honor week")
		register(dd.honor, "Honor remain")
		register(dd.honor, "Honor goal in")
		self.textLeft:SetText(self.text_head)
	end
end

-- layout main frame
function addon:LayoutFrame()
	local config = addon.db
	self:SetFrameStrata(config.frameStrata or 'MEDIUM')
	-- background and border
	BackdropCfg.edgeFile = config.borderTexture
	self:SetBackdrop(nil)
	self:SetBackdrop( config.borderTexture and BackdropCfg or BackdropDef )
	self:SetBackdropBorderColor( unpack(config.borderColor or COLOR_WHITE) )
	self:SetBackdropColor( unpack(config.backColor or COLOR_TRANSPARENT) )
	--
	local textLeft = self.textLeft
	textLeft:ClearAllPoints()
	textLeft:SetPoint('TOPLEFT', config.frameMargin, -config.frameMargin)
	textLeft:SetJustifyH('LEFT')
	textLeft:SetJustifyV('TOP')
	SetTextFont(textLeft, config.fontName, config.fontSize, 'OUTLINE')
	self:LayoutContent()
	-- text right
	local textRight = self.textRight
	textRight:ClearAllPoints()
	textRight:SetPoint('TOPRIGHT', -config.frameMargin, -config.frameMargin)
	textRight:SetPoint('TOPLEFT', config.frameMargin, -config.frameMargin)
	textRight:SetJustifyH('RIGHT')
	textRight:SetJustifyV('TOP')
	SetTextFont(textRight, config.fontName, config.fontSize, 'OUTLINE')
	-- delayed frame sizing, because textl:GetHeight() returns incorrect height on first login for some fonts.
	addon:SetScript("OnUpdate", self.UpdateFrameSize)
end

-- update honor data
function addon:UpdateHonorStats(wkHonorOpt)
	if not self._zoneName then return end
	local db = self.db
	local dp = db.display
	local ctime = time()
	local wkHonor = tonumber(wkHonorOpt) or GetWeekHonor()
	local snTimeStart = db.snTimeStart
	local snElapsed = snTimeStart and ctime-snTimeStart or 0
	local snHonor = snTimeStart and wkHonor-db.snHonorStart
	local snHPH = gethph(snHonor, snElapsed, true)
	local bgHonor = db.bgTimeStart and wkHonor-db.bgHonorStart or safedivceil(db.snBgHonor,db.snBgCount)
	local bgElapsed = db.bgTimeStart and ctime-db.bgTimeStart or safedivceil(db.snBgTime,db.snBgCount)
	local bgHPH = db.bgTimeStart and gethph(bgHonor, bgElapsed) or gethph(db.snBgHonor, db.snBgTime)
	local wkHonorRemain = db.wkHonorGoal and max(db.wkHonorGoal - wkHonor, 0)
	local wkHonorTimeRemain = db.wkHonorGoal and snHPH and max( safedivceil(wkHonorRemain*3600, snHPH, 0), 0 )
	local data = self.fmtTable or {}
	data[#data+1] = self._zoneNameShort
	if not dp.battleground then data[#data+1] = FmtDurationHM(bgElapsed) end
	if not dp.battleground then data[#data+1] = FmtHonor(bgHonor) end
	if not dp.battleground then data[#data+1] = FmtHonor(bgHPH) end
	if not dp.session      then data[#data+1] = FmtDurationHM(snTimeStart and snElapsed) end
	if not dp.session      then data[#data+1] = FmtHonor(snTimeStart and snHonor) end
	if not dp.session      then data[#data+1] = FmtHonor(snHPH) end
	if not dp.honor        then data[#data+1] = FmtHonor(wkHonor~=0 and wkHonor) end
	if not dp.honor        then data[#data+1] = FmtHonor(wkHonorRemain) end
	if not dp.honor        then data[#data+1] = FmtCountdownHM(wkHonorTimeRemain) end
	self.textRight:SetFormattedText(self.text_mask, unpack(data))
	wipe(data)
	if snTimeStart and not self.timerEnabled then self:EnableTimer(ctime) end
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
	self:UpdateHonorStats(db.bgHonorStart)
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
	self:UpdateHonorStats()
end

function addon:StartSession()
	local db = self.db
	db.snBgCount = nil
	db.snBgHonor = nil
	db.snBgTime = nil
	db.snTimeStart = db.bgTimeStart or time()
	db.snHonorStart = db.bgHonorStart or GetWeekHonor()
	addon:UpdateHonorStats()
end

function addon:FinishSession()
	local db = self.db
	db.snBgCount = nil
	db.snBgHonor = nil
	db.snBgTime = nil
	db.snTimeStart = db.bgTimeStart or nil
	db.snHonorStart = db.bgHonorStart or nil
	addon:UpdateHonorStats()
end

-- ============================================================================
-- events
-- ============================================================================

-- main frame becomes visible
addon:SetScript("OnShow", addon.UpdateHonorStats)

-- popup menu
addon:SetScript("OnMouseUp", function(self, button)
	if button == 'RightButton' then
		addon:ShowMenu(true)
	end
end)

-- zones management
do
	local lastZoneKey
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
			if zoneKey ~= lastZoneKey or (not event) then -- no event => called from config
				self._zoneName = zone
				self._zoneNameShort = #zone<16 and zone or strsplit(" ",zone,2)
				lastZoneKey = zoneKey
			end
		end
		self.instanceType = instanceType~='none' and instanceType or nil
		if instanceType == 'pvp' then
			self:StartBattleground()
		else
			self:FinishBattleground()
		end
		self:UpdateHonorStats()
		self:SetShown( self.db.visible )
	end
end
addon.PLAYER_ENTERING_WORLD = addon.ZONE_CHANGED_NEW_AREA

-- update honor points
addon.CHAT_MSG_COMBAT_HONOR_GAIN = addon.UpdateHonorStats
addon.CHAT_MSG_BG_SYSTEM_NEUTRAL = addon.UpdateHonorStats
addon.UPDATE_BATTLEFIELD_SCORE   = addon.UpdateHonorStats
addon.PLAYER_PVP_KILLS_CHANGED   = addon.UpdateHonorStats

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
	-- main frame init
	addon:Hide()
	addon:SetSize(1,1)
	addon:EnableMouse(true)
	addon:SetMovable(true)
	addon:RegisterForDrag("LeftButton")
	addon:SetScript("OnDragStart", addon.StartMoving)
	addon:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)
		self:SavePosition()
		self:RestorePosition()
	end )
	-- text left
	addon.textLeft = addon:CreateFontString()
	-- text right
	addon.textRight = addon:CreateFontString()
	-- timer
	timer = addon:CreateAnimationGroup()
	timer.animation = timer:CreateAnimation()
	timer.animation:SetDuration(1)
	timer:SetLooping("REPEAT")
	timer:SetScript("OnLoop", RefreshText)
	-- database setup
	addon.db = InitDB()
	-- compartment icon
	if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
		AddonCompartmentFrame:RegisterAddon({
			text = "KiwiHonor",
			icon  = "Interface\\AddOns\\KiwiHonor\\KiwiHonor.tga",
			registerForAnyClick = true,
			notCheckable = true,
			func = function(_,_,_,_,button) addon:MouseClick(button); end,
		})
	end
	-- minimap icon
	LibStub("LibDBIcon-1.0"):Register(addonName, LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
		type  = "launcher",
		label = GetAddOnInfo( addonName, "Title"),
		icon  = "Interface\\AddOns\\KiwiHonor\\KiwiHonor",
		OnClick = function(_, button) addon:MouseClick(button); end,
		OnTooltipShow = function(tooltip)
			tooltip:AddDoubleLine("KiwiHonor", versionStr)
			tooltip:AddLine(L["|cFFff4040Left Click|r toggle visibility\n|cFFff4040Right Click|r open menu"], 0.2, 1, 0.2)
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
	-- frame position
	addon:RestorePosition()
	-- frame size & appearance
	addon:LayoutFrame()
end)

-- ============================================================================
-- config cmdline
-- ============================================================================

SLASH_KIWIHONOR1,SLASH_KIWIHONOR2 = "/khonor", "/kiwihonor"
SlashCmdList.KIWIHONOR = function(args)
	local config = addon.db
	local arg1,arg2,arg3 = strsplit(" ",args,3)
	arg1, arg2 = strlower(arg1 or ''), strlower(arg2 or '')
	if arg1 == 'show' then
		addon:Show()
	elseif arg1 == 'hide' then
		addon:Hide()
	elseif arg1 == 'toggle' then
		addon:UpdateFrameVisibility()
	elseif arg1 == 'config' then
		addon:ShowMenu()
	elseif arg1 == 'resetpos' then
		config.framePos.x, config.framePos.x = 0, 0
		addon:RestorePosition()
	elseif arg1 == 'minimap' then
		config.minimapIcon.hide = not config.minimapIcon.hide
		if config.minimapIcon.hide then
			LibStub("LibDBIcon-1.0"):Hide(addonName)
		else
			LibStub("LibDBIcon-1.0"):Show(addonName)
		end
	else
		print("Kiwi Honor:")
		print("  Right-Click to display config menu.")
		print("  Click&Drag to move main frame.")
		print("Commands:")
		print("  /khonor show        -- show main window")
		print("  /khonor hide        -- hide main window")
		print("  /khonor toggle      -- show/hide main window")
 		print("  /khonor config      -- display config menu")
		print("  /khonor minimap     -- toggle minimap icon visibility")
		print("  /khonor resetpos    -- reset main window position")
	end
end

-- ============================================================================
-- config popup menu
-- ============================================================================

do
	-- addon.db
	local config
	-- here starts the definition of the KiwiFrame menu
	local function SetWidth(info)
		config.frameWidth = info.value~=0 and math.max( (config.frameWidth or addon:GetWidth()) + info.value, 50) or nil
		addon:LayoutFrame()
	end
	local function SetMargin(info)
		config.frameMargin = info.value~=0 and math.max( (config.frameMargin or 4) + info.value, 0) or 4
		addon:LayoutFrame()
	end
	local function SetFontSize(info)
		config.fontSize = info.value~=0 and math.max( (config.fontSize or 14) + info.value, 5) or 14
		addon:LayoutFrame()
	end
	local function StrataChecked(info)
		return info.value == (config.frameStrata or 'MEDIUM')
	end
	local function SetStrata(info)
		config.frameStrata = info.value~='MEDIUM' and info.value or nil
		addon:LayoutFrame()
	end
	local function AnchorChecked(info)
		return info.value == config.framePos.anchor
	end
	local function SetAnchor(info)
		config.framePos.anchor = info.value
		addon:SavePosition()
		addon:RestorePosition()
	end
	local function DisplayChecked(info)
		return not addon.db.display[info.value]
	end
	local function SetDisplay(info)
		addon.db.display[info.value] = not addon.db.display[info.value] or nil
		addon:LayoutFrame()
		addon:UpdateHonorStats()
	end
	local function FontSet(info)
		config.fontName = info.value
		addon:UpdateFrameFonts()
		lkm:refreshMenu()
	end
	local function FontChecked(info)
		return info.value == (config.fontName or lkm.FONTS.Arial)
	end
	local function BorderSet(info)
		config.borderTexture = info.value~='' and info.value or nil
		addon:LayoutFrame()
		lkm:refreshMenu()
	end
	local function BorderChecked(info)
		return info.value == (config.borderTexture or '')
	end
	local function ResetSession()
		if addon.db.snTimeStart then
			addon:ConfirmDialog( L["Are you sure you want to finish the session?"], function() addon:FinishSession(); end)
		else
			addon:StartSession()
		end
	end
	local function SetHonorGoal()
		addon:EditDialog(L['|cFF7FFF72KiwiHonor|r\n Set the Weekly Honor Goal:\n'], addon.db.wkHonorGoal or '', function(v)
			addon.db.wkHonorGoal = tonumber(v) or nil
			addon:UpdateHonorStats()
		end)
	end
	-- menu: main
	local menuMain = {
		{ text = L['Kiwi Honor [/khonor]'], notCheckable = true, isTitle = true },
		{ text = function() return addon.db.snTimeStart and L['Session Finish'] or L['Session Start'] end, notCheckable= true, func = ResetSession },
		{ text = L['Set Honor Goal'], notCheckable= true, func = SetHonorGoal },
		{ text = L['Display'], notCheckable = true, isTitle = true },
		{ text = L['Battleground'], value = 'battleground', isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
		{ text = L['Session'],      value = 'session',      isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
		{ text = L['Honor'], value = 'honor',  isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
		{ text = L['Settings'], notCheckable = true, isTitle = true },
		{ text = L['Frame appearance'], notCheckable = true, hasArrow = true, menuList = {
			{ text = L['Frame Strata'], notCheckable= true, hasArrow = true, menuList = {
				{ text = L['HIGH'],    value = 'HIGH',   checked = StrataChecked, func = SetStrata },
				{ text = L['MEDIUM'],  value = 'MEDIUM', checked = StrataChecked, func = SetStrata },
				{ text = L['LOW'],     value = 'LOW',  	 checked = StrataChecked, func = SetStrata },
			} },
			{ text = L['Frame Anchor'], notCheckable= true, hasArrow = true, menuList = {
				{ text = L['Top Left'],     value = 'TOPLEFT',     checked = AnchorChecked, func = SetAnchor },
				{ text = L['Top Right'],    value = 'TOPRIGHT',    checked = AnchorChecked, func = SetAnchor },
				{ text = L['Bottom Left'],  value = 'BOTTOMLEFT',  checked = AnchorChecked, func = SetAnchor },
				{ text = L['Bottom Right'], value = 'BOTTOMRIGHT', checked = AnchorChecked, func = SetAnchor },
				{ text = L['Left'],   		 value = 'LEFT',   		checked = AnchorChecked, func = SetAnchor },
				{ text = L['Right'],  		 value = 'RIGHT',  		checked = AnchorChecked, func = SetAnchor },
				{ text = L['Top'],    		 value = 'TOP',    		checked = AnchorChecked, func = SetAnchor },
				{ text = L['Bottom'], 		 value = 'BOTTOM', 		checked = AnchorChecked, func = SetAnchor },
				{ text = L['Center'], 		 value = 'CENTER', 		checked = AnchorChecked, func = SetAnchor },
			} },
			{ text = L['Frame Width'], notCheckable= true, hasArrow = true, menuList = {
				{ text = L['Increase(+)'],   value =  1,  notCheckable= true, keepShownOnClick=1, func = SetWidth },
				{ text = L['Decrease(-)'],   value = -1,  notCheckable= true, keepShownOnClick=1, func = SetWidth },
				{ text = L['Default'],       value =  0,  notCheckable= true, keepShownOnClick=1, func = SetWidth },
			} },
			{ text = L['Frame Margin'], notCheckable= true, hasArrow = true, menuList = {
				{ text = L['Increase(+)'],   value =  1,  notCheckable= true, keepShownOnClick=1, func = SetMargin },
				{ text = L['Decrease(-)'],   value = -1,  notCheckable= true, keepShownOnClick=1, func = SetMargin },
				{ text = L['Default'],       value =  0,  notCheckable= true, keepShownOnClick=1, func = SetMargin },
			} },
			{ text = L['Text Size'], notCheckable= true, hasArrow = true, menuList = {
				{ text = L['Increase(+)'],  value =  1,  notCheckable= true, keepShownOnClick=1, func = SetFontSize },
				{ text = L['Decrease(-)'],  value = -1,  notCheckable= true, keepShownOnClick=1, func = SetFontSize },
				{ text = L['Default (14)'], value =  0,  notCheckable= true, keepShownOnClick=1, func = SetFontSize },
			} },
			{ text = L['Text Font'], notCheckable= true, hasArrow = true, menuList = lkm:defMenuFonts(FontSet, FontChecked) },
			{ text = L['Border Texture'], notCheckable= true, hasArrow = true, menuList = lkm:defMenuBorderTextures(BorderSet, BorderChecked) },
			{ text =L['Border color '], notCheckable = true, hasColorSwatch = true, hasOpacity = true,
				get = function() return unpack(config.borderColor) end,
				set = function(info, ...) config.borderColor = {...}; addon:LayoutFrame(); end,
			},
			{ text =L['Background color '], notCheckable = true, hasColorSwatch = true, hasOpacity = true,
				get = function() return unpack(config.backColor) end,
				set = function(info, ...) config.backColor = {...}; addon:LayoutFrame(); end,
			},
		} },
		{ text = L['Hide Frame'], notCheckable = true, hidden = function() return not addon:IsVisible() end, func = function() addon:ToggleFrameVisibility(false); end },
	}
	function addon:ShowMenu(fromMain)
		config = self.db
		lkm:showMenu(menuMain, "KiwiHonorPopupMenu", "cursor", 0 , 0)
	end
end
