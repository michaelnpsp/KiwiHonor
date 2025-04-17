-- ============================================================================
-- KiwiHonor (C) 2025 MiCHaEL
-- ============================================================================

local addonName = ...

-- main frame
local addon = CreateFrame('Frame', "KiwiHonor", UIParent, BackdropTemplateMixin and "BackdropTemplate")

-- libraries
local media = LibStub("LibSharedMedia-3.0", true)
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
local FONT_SIZE_DEFAULT = 14
local COLOR_WHITE = { 1,1,1,1 }
local COLOR_TRANSPARENT = { 0,0,0,0 }
local TEXTURE_SOLID = "Interface\\Buttons\\WHITE8X8"
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
	rowEnabled = nil,
	rowTexture = nil,
	rowColor = nil,
	spacing = 0,
	fontName = nil,
	fontSize = nil,
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
local tinsert = table.insert
local tremove = table.remove
local tconcat = table.concat
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
	return format("|cFF7FFF72%s|r", text)
end

-- get weekly honor gained
local function GetWeekHonor()
	local _, honor = GetPVPThisWeekStats()
	return honor
end

-- font set
local function SetWidgetFont(widget, name, size)
	local loaded = widget:SetFont(name or lkm.FONTS.Arial or STANDARD_TEXT_FONT, size or FONT_SIZE_DEFAULT, 'OUTLINE')
	if not widget:GetFont() then
		widget:SetFont(STANDARD_TEXT_FONT, size or FONT_SIZE_DEFAULT, 'OUTLINE')
	end
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
	if button == 'RightButton' or self.plugin then
		self:ShowMenu()
	else
		self:ToggleFrameVisibility()
	end
end

-- restore main frame position
function addon:RestorePosition()
	if self.plugin then return end
	local config = self.db
	addon:ClearAllPoints()
	addon:SetPoint( config.framePos.anchor, UIParent, 'CENTER', config.framePos.x, config.framePos.y )
end

-- save main frame position
function addon:SavePosition()
	if self.plugin then return end
	local config = self.db
	local p, cx, cy = config.framePos, UIParent:GetCenter() -- we are assuming addon frame scale=1 in calculations
	local x = (p.anchor:find("LEFT")   and addon:GetLeft())   or (p.anchor:find("RIGHT") and addon:GetRight()) or addon:GetLeft()+addon:GetWidth()/2
	local y = (p.anchor:find("BOTTOM") and addon:GetBottom()) or (p.anchor:find("TOP")   and addon:GetTop())   or addon:GetTop() -addon:GetHeight()/2
	p.x, p.y = x-cx, y-cy
end

-- get font info from config
function KiwiHonor:GetTextsFontInfo()
	return self.db.fontName, self.db.fontSize
end

-- get font info from config
function KiwiHonor:GetRowsInfo()
	local color = self.db.rowColor or COLOR_TRANSPARENT
	local texture = self.db.rowTexture or TEXTURE_SOLID
	return color, texture
end

-- frame sizing
function addon:UpdateFrameSize()
	local config = self.db
	addon:SetHeight( self.textLeft:GetHeight() + config.frameMargin*2 )
	addon:SetWidth( config.frameWidth or (self.textLeft:GetWidth() * 1.5) + config.frameMargin*2 )
	self:SetScript('OnUpdate', nil)
end

-- change main frame visibility: nil == toggle visibility
function addon:ToggleFrameVisibility(visible)
	if self.plugin then return end
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

-- display stats
do
	local data_titles = {}
	local data_values = {}
	local data_rows   = {}

	local function register(disabled, left)
		if disabled then return end
		data_titles[#data_titles+1] = L[left] .. ':'
	end

	-- layout content
	function addon:LayoutContent()
		local dd = self.db.display
		local bg = self.db.bgTimeStart
		wipe(data_titles)
		register(dd.zone, "|cFF7FFF72KiwiHonor" )
		register(dd.battleground, bg and "Bg duration" or "Bg duration (avg)" )
		register(dd.battleground, bg and "Bg honor" or "Bg honor (avg)")
		register(dd.battleground, bg and "Bg honor/h" or "Bg honor/h (avg)")
		register(dd.session, "Session duration")
		register(dd.session, "Session honor")
		register(dd.session, "Session honor/h")
		register(dd.honor, "Honor week")
		register(dd.honor, "Honor remain")
		register(dd.honor, "Honor goal in")
	end

	-- update honor data
	function addon:UpdateHonorStats(wkHonorOpt)
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
		-- create datasheet
		if not dp.zone         then data_values[#data_values+1] = FmtZone(self._zoneNameShort) end
		if not dp.battleground then data_values[#data_values+1] = FmtDurationHM(bgElapsed) end
		if not dp.battleground then data_values[#data_values+1] = FmtHonor(bgHonor) end
		if not dp.battleground then data_values[#data_values+1] = FmtHonor(bgHPH) end
		if not dp.session      then data_values[#data_values+1] = FmtDurationHM(snTimeStart and snElapsed) end
		if not dp.session      then data_values[#data_values+1] = FmtHonor(snHonor) end
		if not dp.session      then data_values[#data_values+1] = FmtHonor(snHPH) end
		if not dp.honor        then data_values[#data_values+1] = FmtHonor(wkHonor~=0 and wkHonor) end
		if not dp.honor        then data_values[#data_values+1] = FmtHonor(wkHonorRemain) end
		if not dp.honor        then data_values[#data_values+1] = FmtCountdownHM(wkHonorTimeRemain) end
		-- display data
		self.textLeft:SetText( tconcat(data_titles,"|r\n") )
		self.textRight:SetText( tconcat(data_values,"\n") )
		wipe(data_values)
		-- update timer
		if snTimeStart and not self.timerEnabled then self:EnableTimer(ctime) end
	end

	-- Clear Rows
	function addon:ClearRows(index)
		for i=index or 1,#data_rows do
			data_rows[i]:Hide()
		end
	end

	-- Layout Rows
	function addon:LayoutRows()
		if not self.db.rowEnabled then return end
		local sheight = self.textLeft:GetStringHeight()
		if sheight<=0 then C_Timer.After(0, function() addon:LayoutRows() end); return end
		local count = #data_titles
		local spacing = self.db.spacing
		local height = (sheight - (count-1)*spacing) / count
		local fheight = height + spacing
		local rows = math.floor( (self.textLeft:GetHeight()+spacing)/fheight )
		local margin = self.db.frameMargin
		local color, texture = self:GetRowsInfo()
		local offset = 0
		for i=1,rows do
			local row = data_rows[i] or self:CreateTexture(nil, "BACKGROUND")
			row:SetTexture(texture)
			row:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
			row:ClearAllPoints()
			row:SetPoint('TOPLEFT',   margin, -offset-margin)
			row:SetPoint('TOPRIGHT', -margin, -offset-margin)
			row:SetHeight(height)
			row:Show()
			offset = offset + fheight
			data_rows[i] = row
			i = i + 1
		end
		self:ClearRows(rows+1)
	end

	-- layout main frame
	function addon:LayoutFrame()
		local config = addon.db
		local plugin = self.plugin
		local font, size = self:GetTextsFontInfo()
		-- background, border, strata
		self:SetBackdrop(nil)
		if not plugin then
			BackdropCfg.edgeFile = config.borderTexture
			self:SetBackdrop( config.borderTexture and BackdropCfg or BackdropDef )
			self:SetBackdropBorderColor( unpack(config.borderColor or COLOR_WHITE) )
			self:SetBackdropColor( unpack(config.backColor or COLOR_TRANSPARENT) )
			self:SetFrameStrata(config.frameStrata or 'MEDIUM')
		end
		-- text preparation
		self:LayoutContent()
		-- text left
		local textLeft = self.textLeft
		textLeft:ClearAllPoints()
		textLeft:SetPoint('TOPLEFT', config.frameMargin, -config.frameMargin)
		textLeft:SetJustifyH('LEFT')
		textLeft:SetJustifyV('TOP')
		textLeft:SetTextColor(1,1,1,1)
		textLeft:SetSpacing(config.spacing)
		SetWidgetFont(textLeft, font, size)
		textLeft:SetText('')
		-- text right
		local textRight = self.textRight
		textRight:ClearAllPoints()
		textRight:SetPoint('TOPRIGHT', -config.frameMargin, -config.frameMargin)
		textRight:SetPoint('TOPLEFT', config.frameMargin, -config.frameMargin)
		textRight:SetJustifyH('RIGHT')
		textRight:SetJustifyV('TOP')
		textRight:SetTextColor(1,1,1,1)
		textRight:SetSpacing(config.spacing)
		SetWidgetFont(textRight, font, size)
		textRight:SetText('')
		-- display stats
		self:UpdateHonorStats()
		-- adjust height
		if plugin then -- details plugin text height
			local w, h = plugin:GetPluginInstance():GetSize()
			textLeft:SetHeight(h-config.frameMargin*2)
			textRight:SetHeight(h-config.frameMargin*2)
		else -- delayed frame sizing, because textl:GetHeight() returns incorrect height on first login for some fonts.
			addon:SetScript("OnUpdate", self.UpdateFrameSize)
		end
		self:LayoutRows()
	end
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
	-- database setup
	addon.db = InitDB()
	-- main frame init
	addon:Hide()
	if not addon.db.details then
		addon:SetSize(1,1)
		addon:EnableMouse(true)
		addon:SetMovable(true)
		addon:RegisterForDrag("LeftButton")
		addon:SetScript("OnShow", addon.UpdateHonorStats)
		addon:SetScript("OnDragStart", addon.StartMoving)
		addon:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			self:SetUserPlaced(false)
			self:SavePosition()
			self:RestorePosition()
		end )
		addon:SetScript("OnMouseUp", function(self, button)
			if button == 'RightButton' then
				addon:ShowMenu(true)
			end
		end)
	end
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
	if not addon:EnableDetailsPlugin() then
		addon:RestorePosition()
		addon:LayoutFrame()
	end
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
		addon:ToggleFrameVisibility()
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
	local function SetSpacing(info)
		config.spacing = info.value~=0 and math.max( config.spacing + info.value, 0) or 0
		addon.textLeft:SetText('')
		addon.textRight:SetText('')
		addon:LayoutFrame()
		addon:UpdateHonorStats()
	end
	local function SetFontSize(info)
		local font, size = addon:GetTextsFontInfo()
		config.fontSize = info.value~=0 and math.max( (size or FONT_SIZE_DEFAULT) + info.value, 5) or nil
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
		config.fontName = info.value~='' and info.value or nil
		addon:LayoutFrame()
		lkm:refreshMenu()
	end
	local function FontChecked(info)
		return info.value == (config.fontName or '')
	end
	local function BorderSet(info)
		config.borderTexture = info.value~='' and info.value or nil
		addon:LayoutFrame()
		lkm:refreshMenu()
	end
	local function BorderChecked(info)
		return info.value == (config.borderTexture or '')
	end
	local function ToggleSession()
		if addon.db.snTimeStart then
			addon:ConfirmDialog( L["|cFF7FFF72KiwiHonor|r\nAre you sure you want to finish the session?"], function() addon:FinishSession(); end)
		else
			addon:StartSession()
		end
	end
	local function SetHonorGoal()
		addon:EditDialog(L['|cFF7FFF72KiwiHonor|r\nSet the Weekly Honor Goal:\n'], addon.db.wkHonorGoal or '', function(v)
			addon.db.wkHonorGoal = tonumber(v) or nil
			addon:UpdateHonorStats()
		end)
	end
	local function ToggleDetails()
		local msg = addon.db.details and
					L["|cFF7FFF72KiwiHonor|r\nHonor stats will be displayed in a standalone window. Are you sure you want to disable KiwiHonor Details Plugin?"] or
					L["|cFF7FFF72KiwiHonor|r\nHonor stats will be displayed in a Details window. Are you sure you want to enable KiwiHonor Details Plugin?"]
		addon:ConfirmDialog( msg, function()
			addon.db.details = (not addon.db.details) or nil
			ReloadUI()
		end)
	end
	local function RowSet(info)
		config.rowEnabled = not config.rowEnabled or nil
		addon:ClearRows()
		addon:LayoutFrame()
	end
	local function RowChecked(info)
		return config.rowEnabled
	end
	local function RowTexSet(info)
		config.rowTexture = info.value~='' and info.value or nil
		addon:LayoutFrame()
		lkm:refreshMenu()
	end
	local function RowTexChecked(info)
		return info.value == (config.rowTexture or '')
	end
	-- main menu
	addon.menuMain = {
		{ text = L['Kiwi Honor [/khonor]'], notCheckable = true, isTitle = true },
		{ text = function() return addon.db.snTimeStart and L['Session Finish'] or L['Session Start'] end, notCheckable= true, func = ToggleSession },
		{ text = L['Set Honor Goal'], notCheckable= true, func = SetHonorGoal },
		{ text = L['Display'], notCheckable = true, isTitle = true },
		{ text = L['Zone'],         value = 'zone', isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
		{ text = L['Battleground'], value = 'battleground', isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
		{ text = L['Session'],      value = 'session',      isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
		{ text = L['Honor'],        value = 'honor',        isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
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
				{ text = L['Left'],   		value = 'LEFT',   	   checked = AnchorChecked, func = SetAnchor },
				{ text = L['Right'],  		value = 'RIGHT',  	   checked = AnchorChecked, func = SetAnchor },
				{ text = L['Top'],    		value = 'TOP',    	   checked = AnchorChecked, func = SetAnchor },
				{ text = L['Bottom'], 		value = 'BOTTOM', 	   checked = AnchorChecked, func = SetAnchor },
				{ text = L['Center'], 		value = 'CENTER', 	   checked = AnchorChecked, func = SetAnchor },
			} },
			{ text = L['Frame Width'], notCheckable= true, hasArrow = true, menuList = {
				{ text = L['Increase(+)'],   value =  1,  notCheckable= true, keepShownOnClick=1, func = SetWidth },
				{ text = L['Decrease(-)'],   value = -1,  notCheckable= true, keepShownOnClick=1, func = SetWidth },
				{ text = L['Default'],       value =  0,  notCheckable= true, keepShownOnClick=1, func = SetWidth },
			} },
			{ text = L['Text Margin'], notCheckable= true, hasArrow = true, menuList = {
				{ text = L['Increase(+)'],   value =  1,  notCheckable= true, keepShownOnClick=1, func = SetMargin },
				{ text = L['Decrease(-)'],   value = -1,  notCheckable= true, keepShownOnClick=1, func = SetMargin },
				{ text = L['Default'],       value =  0,  notCheckable= true, keepShownOnClick=1, func = SetMargin },
			} },
			{ text = L['Text Spacing'], notCheckable= true, hasArrow = true, menuList = {
				{ text = L['Increase(+)'],   value =  1,  notCheckable= true, keepShownOnClick=1, func = SetSpacing },
				{ text = L['Decrease(-)'],   value = -1,  notCheckable= true, keepShownOnClick=1, func = SetSpacing },
				{ text = L['Default'],       value =  0,  notCheckable= true, keepShownOnClick=1, func = SetSpacing },
			} },
			{ text = L['Text Size'], notCheckable= true, hasArrow = true, menuList = {
				{ text = L['Increase(+)'],  value =  1,  notCheckable= true, keepShownOnClick=1, func = SetFontSize },
				{ text = L['Decrease(-)'],  value = -1,  notCheckable= true, keepShownOnClick=1, func = SetFontSize },
				{ text = L['Default'], value =  0,  notCheckable= true, keepShownOnClick=1, func = SetFontSize },
			} },
			{ text = L['Text Font'], notCheckable= true, hasArrow = true, menuList = lkm:defMediaMenu('font', FontSet, FontChecked, 16, { [L['[Default]']] = ''}) },
			{ text = L['Background Bars'], notCheckable = true, hasArrow = true, menuList = {
				{ text = L['Display Bars'], keepShownOnClick=1, isNotRadio = true, checked = RowChecked, func = RowSet },
				{ text = L['Bars Color'], notCheckable = true, hasColorSwatch = true, hasOpacity = true,
					get = function() return unpack(config.rowColor or {0,0,0,0}) end,
					set = function(info, ...) config.rowColor = {...}; addon:LayoutFrame(); end,
				},
				{ text = L['Bars Texture'], notCheckable= true, hasArrow = true, menuList = lkm:defMediaMenu('statusbar', RowTexSet, RowTexChecked) },
			} },
			{ text = L['Border Texture'], notCheckable= true, hasArrow = true, menuList = lkm:defMediaMenu('border', BorderSet, BorderChecked) },
			{ text =L['Border color '], notCheckable = true, hasColorSwatch = true, hasOpacity = true,
				get = function() return unpack(config.borderColor) end,
				set = function(info, ...) config.borderColor = {...}; addon:LayoutFrame(); end,
			},
			{ text =L['Background color '], notCheckable = true, hasColorSwatch = true, hasOpacity = true,
				get = function() return unpack(config.backColor) end,
				set = function(info, ...) config.backColor = {...}; addon:LayoutFrame(); end,
			},
		} },
		{ text = function() return addon.db.details and L['Disable Details Plugin'] or L['Enable Details Plugin'] end, notCheckable = true, func = ToggleDetails },
		{ text = L['Hide Frame'], notCheckable = true, hidden = function() return not addon:IsVisible() or addon.plugin~=nil end, func = function() addon:ToggleFrameVisibility(false); end },
	}
	-- show menu
	function addon:ShowMenu()
		config = self.db
		lkm:showMenu(self.menuMain, "KiwiHonorPopupMenu", "cursor", 0 , 0, 2)
	end
end

-- ============================================================================
-- details plugin
-- ============================================================================

function KiwiHonor:EnableDetailsPlugin()
	self.EnableDetailsPlugin = nil
	if not self.db.details then return end
	-- access details addon
	local Details = _G.Details
	if not Details then
		print("KiwiHonor warning: this addon is configured as a Details plugin but Details addon is not installed!")
		return
	end
	-- override some functions and scripts
	function KiwiHonor:GetTextsFontInfo()
		local font = self.db.fontName or media:Fetch("font", self.instance.row_info.font_face, true)
		local size = self.db.fontSize or self.instance.row_info.font_size
		return font, size
	end
	function KiwiHonor:GetRowsInfo()
		local color = self.db.rowColor or self.instance.row_info.fixed_texture_color
		local texture = self.db.rowTexture or media:Fetch("statusbar", self.instance.row_info.texture, true)
		return color, texture
	end
	self:SetScript("OnMouseDown", function(self, button)
		if button == 'LeftButton' or (button == 'RightButton' and IsShiftKeyDown()) then
			self:ShowMenu()
		else
			self.instance.windowSwitchButton:GetScript("OnMouseDown")(self.instance.windowSwitchButton, button)
		end
	end)
	-- create&install details plugin
	local Plugin = Details:NewPluginObject("Details_KiwiHonor")
	Plugin:SetPluginDescription("Display battlegrounds Honor stats.")
	self.plugin = Plugin
	function Plugin:OnDetailsEvent(event, ...)
		local instance = self:GetPluginInstance()
		if instance and (event == "SHOW" or instance == select(1,...)) then
			self.Frame:SetSize(instance:GetSize())
			addon.instance = instance
			addon:SetFrameLevel(5)
			addon:LayoutFrame()
			addon:UpdateHonorStats()
		end
	end
	local install= Details:InstallPlugin("RAID", "KiwiHonor", "Interface\\AddOns\\KiwiHonor\\KiwiHonor.tga", Plugin, "DETAILS_PLUGIN_KIWIHONOR", 1, "MiCHaEL", "v0.1")
	if type (install) == "table" and install.error then
		print(install.error)
	end
	Details:RegisterEvent(Plugin, "DETAILS_INSTANCE_ENDRESIZE")
	Details:RegisterEvent(Plugin, "DETAILS_INSTANCE_SIZECHANGED")
	Details:RegisterEvent(Plugin, "DETAILS_INSTANCE_STARTSTRETCH")
	Details:RegisterEvent(Plugin, "DETAILS_INSTANCE_ENDSTRETCH")
	Details:RegisterEvent(Plugin, "DETAILS_OPTIONS_MODIFIED")
	-- reconfigure main menu
	local menuFrame = table.remove(self.menuMain,10).menuList
	for i=8,4,-1 do	table.insert(self.menuMain, 10, menuFrame[i]); end
	-- reparent kiwihonor to details frame
	self:Hide()
	self:SetParent(Plugin.Frame)
	self:ClearAllPoints()
	self:SetAllPoints()
	self:Show()
	return true
end
