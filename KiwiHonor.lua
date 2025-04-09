-- ============================================================================
-- KiwiHonor (C) 2025 MiCHaEL
-- ============================================================================

local addonName = ...

-- main frame
local addon = CreateFrame('Frame', "KiwiHonor", UIParent, BackdropTemplateMixin and "BackdropTemplate")

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
local FONTS = (GetLocale() == 'zhCN') and {
	Arial = 'Fonts\\ARHei.TTF',
	FrizQT = 'Fonts\\ARHei.TTF',
	Morpheus = 'Fonts\\ARHei.TTF',
	Skurri = 'Fonts\\ARHei.TTF',
} or {
	Arial = 'Fonts\\ARIALN.TTF',
	FrizQT = 'Fonts\\FRIZQT__.TTF',
	Morpheus = 'Fonts\\MORPHEUS.TTF',
	Skurri = 'Fonts\\SKURRI.TTF',
}
local BORDERS = {
	["None"] = [[]],
	["Blizzard Tooltip"] = [[Interface\Tooltips\UI-Tooltip-Border]],
	["Blizzard Party"] = [[Interface\CHARACTERFRAME\UI-Party-Border]],
	["Blizzard Dialog"] = [[Interface\DialogFrame\UI-DialogBox-Border]],
	["Blizzard Dialog Gold"] = [[Interface\DialogFrame\UI-DialogBox-Gold-Border]],
	["Blizzard Chat Bubble"] = [[Interface\Tooltips\ChatBubble-Backdrop]],
	["Blizzard Achievement Wood"] = [[Interface\AchievementFrame\UI-Achievement-WoodBorder]],
}

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
	--
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
	widget:SetFont(name or FONTS.Arial or STANDARD_TEXT_FONT, size or 14, flags or 'OUTLINE')
	if not widget:GetFont() then
		widget:SetFont(STANDARD_TEXT_FONT, size or 14, flags or 'OUTLINE')
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
	addon:SetWidth( config.frameWidth or (self.textLeft:GetWidth() * 1.75) + config.frameMargin*2 )
	addon:SetScript('OnUpdate', function(self)
		self:SetScript('OnUpdate', nil)
		self:SetAlpha(1)
	end)
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
		register(false,           "|cFF7FFF72KiwiHonor", "|cFF7FFF72%s|r")
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
	-- self:SetAlpha(0)
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

local function safedivceil(dividend, divisor)
	if dividend and divisor and divisor~=0 then
		return ceil( dividend / divisor )
	else
		return nil
	end
end

local function gethph( honor, elapsed, noZero)
	if honor and elapsed and elapsed>=1 then
		local hph = ceil( 3600 * honor / elapsed )
		if (not noZero) or hph~=0 then
			return hph
		end
	end
	return nil
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
	local bgHonor = (db.bgTimeStart and wkHonor-db.bgHonorStart) or (db.snBgCount and ceil(db.snBgHonor/db.snBgCount))
	local bgElapsed = (db.bgTimeStart and ctime-db.bgTimeStart) or (db.snBgCount and ceil(db.snBgTime/db.snBgCount))
	local bgHPH = db.bgTimeStart and gethph(bgHonor, bgElapsed) or gethph(db.snBgHonor, db.snBgTime)
	local wkHonorRemain = db.wkHonorGoal and max(db.wkHonorGoal - wkHonor, 0)
	local wkHonorTimeRemain = db.wkHonorGoal and ((wkHonorRemain<=0 and 0) or (snHPH and ceil(wkHonorRemain/snHPH*3600)))
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

addon:SetScript("OnMouseUp", function(self, button)
	if button == 'RightButton' then
		addon:ShowMenu(true)
	end
end)

-- combat start
function addon:PLAYER_REGEN_DISABLED()
end

-- combat end
function addon:PLAYER_REGEN_ENABLED()
end

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
			self:RegisterEvent("PLAYER_REGEN_DISABLED")
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
		else
			self:FinishBattleground()
			self:UnregisterEvent("PLAYER_REGEN_DISABLED")
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		end
		self:UpdateHonorStats()
		self:SetShown( self.db.visible )
	end
end
addon.PLAYER_ENTERING_WORLD = addon.ZONE_CHANGED_NEW_AREA

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
	-- popup menu main frame
	local menuFrame
	-- generic & enhanced popup menu management code, reusable for other menus
	local showMenu, refreshMenu, getMenuLevel, getMenuValue
	do
		-- workaround for classic submenus bug, level 3 submenu only displays up to 8 items without this
		local function FixClassicBug(level, count)
			local name = "DropDownList"..level
			local frame = _G[name]
			for index = 1, count do
				local button = _G[ name.."Button"..index ]
				if button and frame~=button:GetParent() then
					button:SetParent(frame)
				end
			end
		end
		-- color picker management
		local function picker_get_alpha()
			local a = ColorPickerFrame.SetupColorPickerAndShow and ColorPickerFrame:GetColorAlpha() or OpacitySliderFrame:GetValue()
			return WOW_PROJECT_ID~=WOW_PROJECT_MAINLINE and 1-a or a
		end
		local function picker_get_prev_color(c)
			local r, g, b, a
			if ColorPickerFrame.SetupColorPickerAndShow then
				r, g, b, a = ColorPickerFrame:GetPreviousValues()
			else
				r, g, b, a = c.r, c.g, c.b, c.opacity
			end
			return r, g, b, (WOW_PROJECT_ID~=WOW_PROJECT_MAINLINE and 1-a or a)
		end
		-- menu initialization: special management of enhanced menuList tables, using fields not supported by the base UIDropDownMenu code.
		local function initialize( frame, level, menuList )
			if level then
				frame.menuValues[level] = UIDROPDOWNMENU_MENU_VALUE
				local init = menuList.init
				if init then -- custom initialization function for the menuList
					init(menuList, level, frame)
				end
				if CLASSIC then
					FixClassicBug(level, #menuList)
				end
				for index=1,#menuList do
					local item = menuList[index]
					if item.hidden==nil or not item.hidden(item) then
						if item.useParentValue then -- use the value of the parent popup, needed to make splitMenu() transparent
							item.value = UIDROPDOWNMENU_MENU_VALUE
						end
						if type(item.text)=='function' then -- save function text in another field for later use
							item.textf = item.text
						end
						if type(item.disabled)=='function' then
							item.disabledf = item.disabled
						end
						if item.disabledf then -- support for functions instead of only booleans
							item.disabled = item.disabledf(item, level, frame)
						end
						if item.textf then -- support for functions instead of only strings
							item.text = item.textf(item, level, frame)
						end
						if item.hasColorSwatch then -- simplified color management, only definition of get&set functions required to retrieve&save the color
							if not item.swatchFunc then
								local get, set = item.get, item.set
								item.swatchFunc  = function() local r,g,b,a = get(item); r,g,b = ColorPickerFrame:GetColorRGB(); set(item,r,g,b,a) end
								item.opacityFunc = function() local r,g,b = get(item); set(item,r,g,b,picker_get_alpha()); end
								item.cancelFunc = function(c) set(item, picker_get_prev_color(c)); end
							end
							item.r, item.g, item.b, item.opacity = item.get(item)
							item.opacity = 1 - item.opacity
						end
						item.index = index
						UIDropDownMenu_AddButton(item,level)
					end
				end
			end
		end
		-- get the MENU_LEVEL of the specified menu element ( element = DropDownList|button|nil )
		function getMenuLevel(element)
			return element and ((element.dropdown and element:GetID()) or element:GetParent():GetID()) or UIDROPDOWNMENU_MENU_LEVEL
		end
		-- get the MENU_VALUE of the specified menu element ( element = level|DropDownList|button|nil )
		function getMenuValue(element)
			return element and (UIDROPDOWNMENU_OPEN_MENU.menuValues[type(element)=='table' and getMenuLevel(element) or element]) or UIDROPDOWNMENU_MENU_VALUE
		end
		-- refresh a submenu ( element = level | button | dropdownlist )
		function refreshMenu(element, hideChilds)
			local level = type(element)=='number' and element or getMenuLevel(element)
			if hideChilds then CloseDropDownMenus(level+1) end
			local frame = _G["DropDownList"..level]
			if frame and frame:IsShown() then
				local _, anchorTo = frame:GetPoint(1)
				if anchorTo and anchorTo.menuList then
					ToggleDropDownMenu(level, getMenuValue(level), nil, nil, nil, nil, anchorTo.menuList, anchorTo)
					return true
				end
			end
		end
		-- show my enhanced popup menu
		function showMenu(menuList, menuFrame, anchor, x, y, autoHideDelay )
			menuFrame = menuFrame or CreateFrame("Frame", "KiwiFarmPopupMenu", UIParent, "UIDropDownMenuTemplate")
			menuFrame.displayMode = "MENU"
			menuFrame.menuValues = menuFrame.menuValues  or {}
			UIDropDownMenu_Initialize(menuFrame, initialize, "MENU", nil, menuList);
			ToggleDropDownMenu(1, nil, menuFrame, anchor, x, y, menuList, nil, autoHideDelay);
		end
	end
	-- menu definition helper functions
	local defMenuStart, defMenuAdd, defMenuEnd, splitMenu, wipeMenu
	do
		-- store unused tables to avoid generate garbage
		local tables = {}
		-- clear menu table, preserving special control fields
		function wipeMenu(menu)
			local init = menu.init;	wipe(menu); menu.init = init
		end
		--
		local function strfirstword(str)
			return strmatch(str, "^(.-) ") or str
		end
		-- split a big menu items table in several submenus
		function splitMenu(menu, fsort, fdisp)
			local count = #menu
			if count>1 then
				fsort = fsort or 'text'
				fdisp = fdisp or fsort
				table.sort(menu, function(a,b) return a[fsort]<b[fsort] end )
				local items, first, last
				if count>28 then
					for i=1,count do
						if not items or #items>=28 then
							if items then
								menu[#menu].text = strfirstword(first[fdisp]) .. ' - ' .. strfirstword(last[fdisp])
							end
							items = {}
							tinsert(menu, { notCheckable = true, hasArrow = true, useParentValue = true, menuList = items } )
							first = menu[1]
						end
						last = table.remove(menu,1)
						tinsert(items, last)
					end
					menu[#menu].text = strfirstword(first[fdisp]) .. ' - ' .. strfirstword(last[fdisp])
					menu._split = true
					return true
				end
			end
		end
		-- start menu definition
		function defMenuStart(menu)
			local split = menu._split
			for _,item in ipairs(menu) do
				if split and item.menuList then
					for _,item in ipairs(item.menuList) do
						tables[#tables+1] = item; wipe(item)
					end
				end
				tables[#tables+1] = item; wipe(item)
			end
			wipeMenu(menu)
		end
		-- add an item to the menu
		function defMenuAdd(menu, text, value, menuList)
			local item = tremove(tables) or {}
			item.text, item.value, item.notCheckable, item.menuList, item.hasArrow = text, value, true, menuList, (menuList~=nil) or nil
			menu[#menu+1] = item
			return item
		end
		-- end menu definition
		function defMenuEnd(menu, text)
			if #menu==0 and text then
				menu[1] = tremove(tables) or {}
				menu[1].text, menu[1].notCheckable = text, true
			end
		end
	end

	-- here starts the definition of the KiwiFrame menu
	local openedFromMain -- was the menu opened from the main window ?
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

	-- submenu: fonts
	local menuFonts
	do
		local function set(info)
			config.fontName = info.value
			addon:LayoutFrame()
			refreshMenu()
		end
		local function checked(info)
			return info.value == (config.fontName or FONTS.Arial)
		end
		menuFonts  = { init = function(menu)
			local media = LibStub("LibSharedMedia-3.0", true)
			for name, key in pairs(media and media:HashTable('font') or FONTS) do
				tinsert( menu, { text = name, value = key, keepShownOnClick = 1, func = set, checked = checked } )
			end
			splitMenu(menu)
			menu.init = nil -- do not call this init function anymore
		end }
	end

	-- submenu: background textures
	local menuBorderTextures
	do
		local function set(info)
			config.borderTexture = info.value~='' and info.value or nil
			addon:LayoutFrame()
			refreshMenu()
		end
		local function checked(info)
			return info.value == (config.borderTexture or '')
		end
		menuBorderTextures  = { init = function(menu)
			local media = LibStub("LibSharedMedia-3.0", true)
			for name, key in pairs(media and media:HashTable('border') or BORDERS) do
				tinsert( menu, { text = name, value = key, keepShownOnClick = 1, func = set, checked = checked } )
			end
			splitMenu(menu)
			menu.init = nil -- do not call this init function anymore
		end }
	end

	-- submenu: sounds
	local menuSounds
	do
		-- groupKey = qualityID | 'price'
		local function set(info)
			local sound, groupKey = info.value, getMenuValue(info)
			notify.sound[groupKey] = sound
			PlaySoundFile(sound,"master")
			refreshMenu()
		end
		local function checked(info)
			local sound, groupKey = info.value, getMenuValue(info)
			return notify.sound[groupKey] == sound
		end
		menuSounds = { init = function(menu)
			local blacklist = { ['None']=true, ['BugSack: Fatality']=true }
			local media = LibStub("LibSharedMedia-3.0", true)
			if media then
				for name,fileID in pairs(SOUNDS) do
					media:Register("sound", name, fileID)
				end
			end
			for name, key in pairs(media and media:HashTable('sound') or SOUNDS) do
				if not blacklist[name] then
					tinsert( menu, { text = name, value = key, arg1=strlower(name), func = set, checked = checked, keepShownOnClick = 1 } )
				end
			end
			splitMenu(menu, 'arg1', 'text')
			menu.init = nil -- do not call this init function anymore
		end }
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
		-- { text = L['Honor/hour'],   value = 'honor_hour',   isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
		--{ text = L['Honor week'],   value = 'honor_week',   isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
		--{ text = L['Honor remain'], value = 'honor_remain', isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
		--{ text = L['Honor time'],   value = 'honor_time',   isNotRadio = true, keepShownOnClick=1, checked = DisplayChecked, func = SetDisplay },
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
			{ text = L['Text Font'], notCheckable= true, hasArrow = true, menuList = menuFonts },
			{ text = L['Border Texture'], notCheckable= true, hasArrow = true, menuList = menuBorderTextures },
			{ text =L['Border color '], notCheckable = true, hasColorSwatch = true, hasOpacity = true,
				get = function() return unpack(config.borderColor) end,
				set = function(info, ...) config.borderColor = {...}; addon:LayoutFrame(); end,
			},
			{ text =L['Background color '], notCheckable = true, hasColorSwatch = true, hasOpacity = true,
				get = function() return unpack(config.backColor) end,
				set = function(info, ...) config.backColor = {...}; addon:LayoutFrame(); end,
			},
		} },
		{ text = L['Hide Frame'], notCheckable = true, hidden = function() return not openedFromMain end, func = function() addon:ToggleFrameVisibility(false); end },
	}
	function addon:ShowMenu(fromMain)
		config = self.db
		openedFromMain = fromMain
		showMenu(menuMain, menuFrame, "cursor", 0 , 0)
	end
end
