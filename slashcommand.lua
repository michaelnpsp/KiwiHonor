
local addon = _G[...]

SLASH_KIWIHONOR1,SLASH_KIWIHONOR2 = "/khonor", "/kiwihonor"
SlashCmdList.KIWIHONOR = function(args)
	local noskip = not addon.plugin
	local arg1 = strlower(args)
	if arg1 == 'config' then
		addon:ShowMenu()
	elseif arg1 == 'minimap' then
		lkf:ToggleMinimapIcon(addonName, addon.db.minimapIcon)
	elseif arg1 == 'show' and noskip then
		addon:ToggleFrameVisibility(true)
	elseif arg1 == 'hide' and noskip then
		addon:ToggleFrameVisibility(false)
	elseif arg1 == 'toggle' and noskip then
		addon:ToggleFrameVisibility()
	elseif arg1 == 'resetpos' and noskip then
		addon.db.frame.framePos.x, addon.db.frame.framePos.x = 0, 0
		addon:RestorePosition()
	else
		print("Kiwi Honor:")
		print("  Display battlegrounds honor stats.")
		print(noskip and "  Right-Click to display config menu." or "  Left-Click to display config menu.")
		if noskip then print("  Click&Drag to move main frame.") end
		print("Commands:")
		print("  /khonor config      -- display config menu")
		print("  /khonor minimap     -- toggle minimap icon visibility")
		print("  /khonor show        -- show main window")
		print("  /khonor hide        -- hide main window")
		print("  /khonor toggle      -- show/hide main window")
		print("  /khonor resetpos    -- reset main window position")
	end
end
