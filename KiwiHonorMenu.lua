local addon = _G[(...)]

local lkm = LibStub("LibKiwiDropDownMenu-1.0", true)

-- localization
local L = addon.L

-- default values
local FONT_SIZE_DEFAULT = 12
local ROW_TEXTURE_DEFAULT = "Interface\\Buttons\\WHITE8X8"
local ROW_COLOR_DEFAULT = {.3,.3,.3,1}

-- addon.db
local config

-- here starts the definition of the KiwiFrame menu
local function cfgWidth(info)
config.frameWidth = info.value~=0 and math.max(addon:GetWidth()+info.value, 50) or addon.DEFAULTS.frameWidth
	addon:LayoutFrame()
end
local function cfgMargin(info)
	config.frameMargin = info.value~=0 and math.max( (config.frameMargin or 4) + info.value, 0) or 4
	addon:LayoutFrame()
end
local function cfgSpacing(info)
	config.spacing = info.value~=0 and math.max( config.spacing + info.value, 0) or 1
	addon.textLeft:SetText('')
	addon.textRight:SetText('')
	addon:LayoutFrame()
	addon:UpdateContent()
end
local function cfgFontSize(info)
	local font, size = addon:GetTextsFontInfo()
	config.fontSize = info.value~=0 and math.max( (size or FONT_SIZE_DEFAULT) + info.value, 5) or nil
	addon:LayoutFrame()
end
local function cfgStrata(info,_,_,checked)
	if checked==nil then return info.value == (config.frameStrata or 'MEDIUM') end
	config.frameStrata = info.value~='MEDIUM' and info.value or nil
	addon:LayoutFrame()
end
local function cfgAnchor(info,_,_,checked)
	if checked==nil then return info.value == config.framePos.anchor end
	config.framePos.anchor = info.value
	addon:SavePosition()
	addon:RestorePosition()
end
local function cfgDisplay(info,_,_,checked)
	if checked==nil then return not addon.db.display[info.value] end
	addon.db.display[info.value] = not addon.db.display[info.value] or nil
	addon:LayoutFrame()
	addon:UpdateContent()
end
local function cfgFont(info,_,_,checked)
	if checked==nil then return info.value == (config.fontName or '') end
	config.fontName = info.value~='' and info.value or nil
	addon:LayoutFrame()
	lkm:refreshMenu()
end
local function cfgBorder(info,_,_,checked)
	if checked==nil then return info.value == (config.borderTexture or '') end
	config.borderTexture = info.value~='' and info.value or nil
	addon:LayoutFrame()
	lkm:refreshMenu()
end
local function cfgRowEnabled(info,_,_,checked)
	if checked==nil then return config.rowEnabled end
	config.rowEnabled = not config.rowEnabled or nil
	addon:LayoutFrame()
end
local function cfgRowTexture(info,_,_,checked)
	if checked==nil then return info.value == (config.rowTexture or ROW_TEXTURE_DEFAULT) end
	config.rowTexture = info.value~='' and info.value or nil
	addon:LayoutFrame()
	lkm:refreshMenu()
end
local function cfgColor(info, ...)
	if select('#',...)==0 then return unpack( config[info.value] or ROW_COLOR_DEFAULT ) end
	config[info.value] = {...}
	addon:LayoutFrame()
end
local function cfgToggleSession()
	if addon.db.snTimeStart then
		addon:ConfirmDialog( L["|cFF7FFF72KiwiHonor|r\nAre you sure you want to finish the session?"], function() addon:FinishSession(); end)
	else
		addon:StartSession()
	end
end
local function cfgSetHonorGoal()
	addon:EditDialog(L['|cFF7FFF72KiwiHonor|r\nSet the Weekly Honor Goal:\n'], addon.db.wkHonorGoal or '', function(v)
		addon.db.wkHonorGoal = tonumber(v) or nil
		addon:UpdateContent()
	end)
end
local function cfgToggleDetails()
	local msg = addon.db.details and
				L["|cFF7FFF72KiwiHonor|r\nHonor stats will be displayed in a standalone window. Are you sure you want to disable KiwiHonor Details Plugin?"] or
				L["|cFF7FFF72KiwiHonor|r\nHonor stats will be displayed in a Details window. Are you sure you want to enable KiwiHonor Details Plugin?"]
	addon:ConfirmDialog(msg, function()
		addon.db.details = (not addon.db.details) or nil
		ReloadUI()
	end)
end
local function getSessionText()
	return addon.db.snTimeStart and L['Session Finish'] or L['Session Start']
end
local function getDetailsText()
	return addon.db.details and L['Disable Details Plugin'] or L['Enable Details Plugin']
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
		{ text = L['BG duration'],      value = 'bg_duration',  },
		{ text = L['BG honor'],         value = 'bg_honor',     },
		{ text = L['BG honor/h'],       value = 'bg_hph',       },
		{ text = L['Session duration'], value = 'sn_duration',  },
		{ text = L['Session honor'],    value = 'sn_honor',     },
		{ text = L['Session honor/h'],  value = 'sn_hph',       },
		{ text = L['Honor week'],       value = 'hr_week',      },
		{ text = L['Honor remain'],     value = 'hr_remain',    },
		{ text = L['Honor goal in'],    value = 'hr_goalin',    },
	} },
	{ text = L['Frame appearance'], menuList = {
		{ text = L['Frame Strata'], hidden = isPlugin, default = { cf = cfgStrata, isNotRadio = false }, menuList = {
			{ text = L['HIGH'],    value = 'HIGH',   },
			{ text = L['MEDIUM'],  value = 'MEDIUM', },
			{ text = L['LOW'],     value = 'LOW',  	 },
		} },
		{ text = L['Frame Anchor'], hidden = isPlugin, default = { cf = cfgAnchor, isNotRadio = false }, menuList = {
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
		{ text = L['Frame Width'],  hidden = isPlugin, default = { func = cfgWidth,    keepShownOnClick = 1 }, menuList = lkm:CopyTable(menuSize) },
		{ text = L['Text Margin'],  default = { func = cfgMargin,   keepShownOnClick = 1 }, menuList = lkm:CopyTable(menuSize) },
		{ text = L['Text Spacing'], default = { func = cfgSpacing,  keepShownOnClick = 1 }, menuList = lkm:CopyTable(menuSize) },
		{ text = L['Text Size'],    default = { func = cfgFontSize, keepShownOnClick = 1 }, menuList = lkm:CopyTable(menuSize) },
		{ text = L['Text Font'], menuList = lkm:defMediaMenu('font', cfgFont, nil, 16, { [L['[Default]']] = ''}	) },
		{ text = L['Background Bars'], menuList = {
			{ text = L['Display Bars'], keepShownOnClick = 1, isNotRadio = true, cf = cfgRowEnabled },
			{ text = L['Bars Color'],   hasColorSwatch = true, hasOpacity = true, value = 'rowColor', get = cfgColor, set = cfgColor },
			{ text = L['Bars Texture'], menuList = lkm:defMediaMenu('statusbar', cfgRowTexture) },
		} },
		{ text = L['Border Texture'], hidden = isPlugin, menuList = lkm:defMediaMenu('border', cfgBorder) },
		{ text = L['Border color '],  hidden = isPlugin, hasColorSwatch = true, hasOpacity = true, value = 'borderColor', get = cfgColor, set = cfgColor },
		{ text = L['Background color '], hidden = isPlugin, hasColorSwatch = true, hasOpacity = true, value = 'backColor',   get = cfgColor, set = cfgColor },
	} },
	{ text = getDetailsText, func = cfgToggleDetails },
	{ text = L['Hide Window'], hidden = isHideHidden, func = cfgSetHide },
}

-- show menu
function addon:ShowMenu()
	config = self.db
	lkm:showMenu(self.menuMain, "KiwiHonorPopupMenu", "cursor", 0 , 0, 2)
end
