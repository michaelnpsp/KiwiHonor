local addonName, addonTbl = ...

local lkm = LibStub("LibKiwiDropDownMenu-1.0", true)

-- localization
local addon = _G[addonName]
local L = addonTbl.L

-- default values
local FONT_SIZE_DEFAULT = 12
local ROW_TEXTURE_DEFAULT = "Interface\\Buttons\\WHITE8X8"
local ROW_COLOR_DEFAULT = {.3,.3,.3,1}

-- addon.db
local config, frame, stats

-- here starts the definition of the KiwiFrame menu
local function cfgWidth(info)
	frame.frameWidth = info.value~=0 and math.max(addon:GetWidth()+info.value, 50) or addon.defaults.frameWidth
	addon:LayoutFrame()
end
local function cfgMargin(info)
	frame.frameMargin = info.value~=0 and math.max( (frame.frameMargin or 4) + info.value, 0) or 4
	addon:LayoutFrame()
end
local function cfgSpacing(info)
	frame.spacing = info.value~=0 and math.max( frame.spacing + info.value, 0) or 1
	addon.textLeft:SetText('')
	addon.textRight:SetText('')
	addon:LayoutFrame()
	addon:UpdateContent()
end
local function cfgFontSize(info)
	local font, size = addon:GetTextsFontInfo()
	frame.fontSize = info.value~=0 and math.max( (size or FONT_SIZE_DEFAULT) + info.value, 5) or nil
	addon:LayoutFrame()
end
local function cfgStrata(info,_,_,checked)
	if checked==nil then return info.value == (frame.frameStrata or 'MEDIUM') end
	frame.frameStrata = info.value~='MEDIUM' and info.value or nil
	addon:LayoutFrame()
end
local function cfgAnchor(info,_,_,checked)
	if checked==nil then return info.value == frame.framePos.anchor end
	frame.framePos.anchor = info.value
	addon:SavePosition()
	addon:RestorePosition()
end
local function cfgDisplay(info,_,_,checked)
	if checked==nil then return not config.display[info.value] end
	config.display[info.value] = not config.display[info.value] or nil
	addon:LayoutFrame()
	addon:UpdateContent()
end
local function cfgFont(info,_,_,checked)
	if checked==nil then return info.value == (frame.fontName or '') end
	frame.fontName = info.value~='' and info.value or nil
	addon:LayoutFrame()
	lkm:refreshMenu()
end
local function cfgBorder(info,_,_,checked)
	if checked==nil then return info.value == (frame.borderTexture or '') end
	frame.borderTexture = info.value~='' and info.value or nil
	addon:LayoutFrame()
	lkm:refreshMenu()
end
local function cfgRowTexture(info,_,_,checked)
	if checked==nil then return info.value == (frame.rowTexture or '') end
	frame.rowTexture = info.value~='' and info.value or nil
	addon:LayoutFrame()
	lkm:refreshMenu()
end
local function cfgColor(info, ...)
	if select('#',...)==0 then return unpack( frame[info.value] or ROW_COLOR_DEFAULT ) end
	frame[info.value] = {...}
	addon:LayoutFrame()
end
local function cfgDetails(info,_,_,checked)
	if checked==nil then return config.details~=nil end
	local msg = config.details and
				L["|cFF7FFF72KiwiHonor|r\nHonor stats will be displayed in a standalone window. Are you sure you want to disable KiwiHonor Details Plugin?"] or
				L["|cFF7FFF72KiwiHonor|r\nHonor stats will be displayed in a Details window. Are you sure you want to enable KiwiHonor Details Plugin?"]
	addon:ConfirmDialog(msg, function()
		config.details = (not config.details) or nil
		ReloadUI()
	end)
end
local function cfgProfile(info,_,_,checked)
	if checked==nil then return addon.db.profileName~='Default' end
	local msg = addon.db.profileName=='Default' and
				L["|cFF7FFF72KiwiHonor|r\nA specific profile for this char will be used to save the appearance settings. Are you sure?"] or
				L["|cFF7FFF72KiwiHonor|r\nA general profile will be used to save the appearance settings. Are you sure?"]
	addon:ConfirmDialog(msg, function()
		local lkf = LibStub("LibKiwiDisplayFrame-1.0", true)
		lkf:GetProfile(addon.db.sv, addon.defaults, addon.db.profileName=='Default' and lkf.charKey or 'Default')
		ReloadUI()
	end)
end
local function cfgToggleSession()
	if stats.snTimeStart then
		addon:ConfirmDialog( L["|cFF7FFF72KiwiHonor|r\nAre you sure you want to finish the session?"], function() addon:FinishSession(); end)
	else
		addon:StartSession()
	end
end
local function cfgSetHonorGoal()
	addon:EditDialog(L['|cFF7FFF72KiwiHonor|r\nSet the Weekly Honor Goal:\n'], stats.wkHonorGoal or '', function(v)
		stats.wkHonorGoal = tonumber(v) or nil
		addon:UpdateContent()
	end)
end
local function getSessionText()
	return stats.snTimeStart and L['Session Finish'] or L['Session Start']
end
local function isHideHidden()
	return not addon:IsVisible() or addon.plugin~=nil
end
local function cfgSetHide()
	addon:ToggleFrameVisibility(false)
end
local function isPlugin()
	return addon.plugin~=nil
end

-- submenu size
local menuSize = {
	{ text = L['Higher (+)'],   value =  1 },
	{ text = L['Smaller (-)'],  value = -1 },
	{ text = L['Default'],      value =  0 },
}

-- menu main
addon.menuMain = {
	{ text = L['Kiwi Honor [/khonor]'], isTitle = true },
	{ text = getSessionText, func = cfgToggleSession },
	{ text = L['Set Honor Goal'], func = cfgSetHonorGoal },
	{ text = L['Settings'], isTitle = true },
	{ text = L['Display'], default = { cf = cfgDisplay, keepShownOnClick = 1, isNotRadio = true }, menuList = {
		{ text = L['Zone'],             value = 'zone',         },
		{ text = L['Bg duration'],      value = 'bg_duration',  },
		{ text = L['Bg honor'],         value = 'bg_honor',     },
		{ text = L['Bg honor/h'],       value = 'bg_hph',       },
		{ text = L['Session duration'], value = 'sn_duration',  },
		{ text = L['Session honor'],    value = 'sn_honor',     },
		{ text = L['Session honor/h'],  value = 'sn_hph',       },
		{ text = L['Honor week'],       value = 'hr_week',      },
		{ text = L['Honor remain'],     value = 'hr_remain',    },
		{ text = L['Honor goal in'],    value = 'hr_goalin',    },
	} },
	{ text = L['Frame'], hidden = isPlugin, menuList = {
		{ text = L['Frame Strata'], default = { cf = cfgStrata, isNotRadio = false }, menuList = {
			{ text = L['HIGH'],    value = 'HIGH',   },
			{ text = L['MEDIUM'],  value = 'MEDIUM', },
			{ text = L['LOW'],     value = 'LOW',  	 },
		} },
		{ text = L['Frame Anchor'], default = { cf = cfgAnchor, isNotRadio = false }, menuList = {
			{ text = L['Top Left'],     value = 'TOPLEFT',     },
			{ text = L['Top Right'],    value = 'TOPRIGHT',    },
			{ text = L['Bottom Left'],  value = 'BOTTOMLEFT',  },
			{ text = L['Bottom Right'], value = 'BOTTOMRIGHT', },
			{ text = L['Left'],   		value = 'LEFT',   	   },
			{ text = L['Right'],  		value = 'RIGHT',  	   },
			{ text = L['Top'],    		value = 'TOP',    	   },
			{ text = L['Bottom'], 		value = 'BOTTOM', 	   },
			{ text = L['Center'], 		value = 'CENTER', 	   },
		} },
		{ text = L['Frame Width'], default = { func = cfgWidth, keepShownOnClick = 1 }, menuList = lkm:CopyTable(menuSize) },
	} },
	{ text = L['Text'], menuList = {
		{ text = L['Text Margin'],  default = { func = cfgMargin,   keepShownOnClick = 1 }, menuList = lkm:CopyTable(menuSize) },
		{ text = L['Text Spacing'], default = { func = cfgSpacing,  keepShownOnClick = 1 }, menuList = lkm:CopyTable(menuSize) },
		{ text = L['Text Size'],    default = { func = cfgFontSize, keepShownOnClick = 1 }, menuList = lkm:CopyTable(menuSize) },
		{ text = L['Text Font'], menuList = lkm:defMediaMenu('font', cfgFont, {[L['[Default]']] = ''}) },
	} },
	{ text = L['Background'], hidden = isPlugin, menuList = {
		{ text = L['Background color '], hasColorSwatch = true, hasOpacity = true, value = 'backColor', get = cfgColor, set = cfgColor },
	} },
	{ text = L['Border'], hidden = isPlugin, menuList = {
		{ text = L['Border Texture'], menuList = lkm:defMediaMenu('border', cfgBorder) },
		{ text = L['Border Color '],  hasColorSwatch = true, hasOpacity = true, value = 'borderColor', get = cfgColor, set = cfgColor },
	} },
	{ text = L['Bars'], menuList = {
		{ text = L['Bars Texture'], menuList = lkm:defMediaMenu('statusbar', cfgRowTexture, {[L['[None]']] = ''}) },
		{ text = L['Bars Color'],   hasColorSwatch = true, hasOpacity = true, value = 'rowColor', get = cfgColor, set = cfgColor },
	} },
	{ text = L['Miscellaneus'], menuList = {
		{ text = L['Details Plugin'], cf = cfgDetails, isNotRadio = true  },
		{ text = L['Profile per Char'], cf = cfgProfile, isNotRadio = true },
	} },
	{ text = L['Hide Frame'], hidden = isHideHidden, func = cfgSetHide },
}

-- show menu
function addon:ShowMenu()
	config, stats, frame = self.db.profile, self.db.stats, self.dbframe
	lkm:showMenu(self.menuMain, "KiwiHonorPopupMenu", "cursor", 0 , 0, 2)
end
