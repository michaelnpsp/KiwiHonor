local addonName, addonTbl = ...

local lkm = LibStub("LibKiwiDropDownMenu-1.0", true)

-- addon, localization
local addon, L = _G[addonName], addonTbl.L

-- addon.db
local config, stats

-- here starts the definition of the KiwiFrame menu
local function cfgDisplay(info,_,_,checked)
	if checked==nil then return not addon.db.profile.display[info.value] end
	addon.db.profile.display[info.value] = not addon.db.profile.display[info.value] or nil
	addon:LayoutFrame()
	addon:UpdateContent()
end

local function cfgDetails(info,_,_,checked)
	if checked==nil then return addon.db.profile.details~=nil end
	local msg = addon.db.profile.details and
				L["|cFF7FFF72KiwiHonor|r\nHonor stats will be displayed in a standalone window. Are you sure you want to disable KiwiHonor Details Plugin?"] or
				L["|cFF7FFF72KiwiHonor|r\nHonor stats will be displayed in a Details window. Are you sure you want to enable KiwiHonor Details Plugin?"]
	addon:ConfirmDialog(msg, function()
		addon.db.profile.details = (not addon.db.profile.details) or nil
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
		lkf:GetProfile(addon.db.sv, addon.db.profile, addon.db.profileName=='Default' and lkf.charKey or 'Default')
		ReloadUI()
	end)
end

local function cfgToggleSession()
	if addon.db.stats.snTimeStart then
		addon:ConfirmDialog( L["|cFF7FFF72KiwiHonor|r\nAre you sure you want to finish the session?"], function() addon:FinishSession(); end)
	else
		addon:StartSession()
	end
end

local function cfgSetHonorGoal()
	addon:EditDialog(L['|cFF7FFF72KiwiHonor|r\nSet the Weekly Honor Goal:\n'], addon.db.stats.wkHonorGoal or '', function(v)
		addon.db.stats.wkHonorGoal = tonumber(v) or nil
		addon:UpdateContent()
	end)
end

local function getSessionText()
	return addon.db.stats.snTimeStart and L['Session Finish'] or L['Session Start']
end

local function cfgFrameHide(info,_,_,checked)
	if checked==nil then return not not addon.dbframe.visible end
	addon:ToggleFrameVisibility()
end

local function isPlugin()
	return addon.plugin~=nil
end

-- menu main
local menuMain = {
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
}
for _,item in ipairs(addon.menuMain) do
	menuMain[#menuMain+1] = item
end
menuMain[#menuMain+1] =	{ text = L['Miscellaneus'], menuList = {
	{ text = L['Details Plugin'], cf = cfgDetails, isNotRadio = true  },
	{ text = L['Profile per Char'], cf = cfgProfile, isNotRadio = true },
	{ text = L['Frame Visible'], cf =  cfgFrameHide, isNotRadio = true, hidden = isPlugin },
} }

-- Register popup menu
addon.menuMain = menuMain

