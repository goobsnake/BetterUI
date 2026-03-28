--[[
File: Modules/Inventory/Dialogs/InventoryDialogs.lua
Purpose: Dialog registrations for Inventory operations:
         - Split Stack
         - Confirm Destroy Item
         - Confirm Destroy Armory Item
]]

local function BETTERUI_TryPlaceInventoryItemInEmptySlot(targetBag)
	local emptySlotIndex, bagId
	if targetBag == BAG_BANK or targetBag == BAG_SUBSCRIBER_BANK then
		--should find both in bank and subscriber bank
		emptySlotIndex = FindFirstEmptySlotInBag(BAG_BANK)
		if emptySlotIndex ~= nil then
			bagId = BAG_BANK
		else
			emptySlotIndex = FindFirstEmptySlotInBag(BAG_SUBSCRIBER_BANK)
			if emptySlotIndex ~= nil then
				bagId = BAG_SUBSCRIBER_BANK
			end
		end
	else
		--just find the bag
		emptySlotIndex = FindFirstEmptySlotInBag(targetBag)
		if emptySlotIndex ~= nil then
			bagId = targetBag
		end
	end

	if bagId ~= nil then
		CallSecureProtected("PlaceInInventory", bagId, emptySlotIndex)
	else
		local errorStringId = (targetBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL
			or SI_INVENTORY_ERROR_BANK_FULL
		BETTERUI.CIM.UserNotify("InventoryDialogs:NoSlot", errorStringId)
	end
end

--- Initializes the split stack dialog for moving items.
--- Purpose: Allows splitting stacks when moving to/from bank.
--- Mechanics: Registers `ZO_GAMEPAD_SPLIT_STACK_DIALOG` with custom callback to `PickupInventoryItem`.
--- References: Called by Initialize.
---@return nil
function BETTERUI.Inventory.Class:InitializeSplitStackDialog()
	BETTERUI.CIM.Dialogs.Register(ZO_GAMEPAD_SPLIT_STACK_DIALOG, {
		canQueue = true,

		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.ITEM_SLIDER,
		},

		setup = function(dialog, data)
			dialog:setupFunc()
			-- Hide custom slider hint controls from CraftBagQuantityDialog
			-- Both dialogs share the GAMEPAD_DIALOGS.ITEM_SLIDER template, so
			-- controls created by SetupSliderKeybindHints persist between uses
			if dialog._minIconLabel then dialog._minIconLabel:SetHidden(true) end
			if dialog._maxIconLabel then dialog._maxIconLabel:SetHidden(true) end
			if dialog._minTextLabel then dialog._minTextLabel:SetHidden(true) end
			if dialog._maxTextLabel then dialog._maxTextLabel:SetHidden(true) end
		end,

		title = {
			text = SI_GAMEPAD_INVENTORY_SPLIT_STACK_TITLE,
		},

		mainText = {
			text = SI_GAMEPAD_INVENTORY_SPLIT_STACK_PROMPT,
		},

		-- ESO passes: sliderMin=1, sliderMax=stackSize-1, sliderStartValue=stackSize/2, stackSize
		-- The slider value represents how many to move to the NEW stack
		-- Display: left shows remaining (stackSize - value), right shows moving (value)
		OnSliderValueChanged = function(dialog, sliderControl, value)
			if dialog and dialog.data and value then
				local stackSize = dialog.data.stackSize or 0
				dialog.sliderValue1:SetText(stackSize - value)
				dialog.sliderValue2:SetText(value)
			end
		end,

		narrationText = function(dialog, itemName)
			if not dialog or not dialog.slider then return nil end
			local stack2 = dialog.slider:GetValue()
			local stack1 = (dialog.data.stackSize or 0) - stack2
			return SCREEN_NARRATION_MANAGER:CreateNarratableObject(
				zo_strformat(SI_GAMEPAD_INVENTORY_SPLIT_STACK_NARRATION_FORMATTER, itemName, stack1, stack2)
			)
		end,

		additionalInputNarrationFunction = function()
			return ZO_GetHorizontalDirectionalInputNarrationData(
				GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_SPLIT_STACK_LEFT_NARRATION")),
				GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_SPLIT_STACK_RIGHT_NARRATION"))
			)
		end,

		buttons = {
			{
				keybind = "DIALOG_NEGATIVE",
				text = GetString(rawget(_G, "SI_DIALOG_CANCEL")),
			},
			{
				keybind = "DIALOG_PRIMARY",
				text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
				callback = function(dialog)
					local dialogData = dialog.data
					local quantity = ZO_GenericGamepadItemSliderDialogTemplate_GetSliderValue(dialog)

					-- Save the uniqueId BEFORE split so inventory refresh restores position
					-- Store in dedicated field to survive list selection callback overwriting currentlySelectedData
					local uniqueId = GetItemUniqueId(dialogData.bagId, dialogData.slotIndex)
					if uniqueId and GAMEPAD_INVENTORY then
						GAMEPAD_INVENTORY._splitStackUniqueId = uniqueId
					end

					CallSecureProtected("PickupInventoryItem", dialogData.bagId, dialogData.slotIndex, quantity)
					BETTERUI_TryPlaceInventoryItemInEmptySlot(dialogData.bagId)
				end,
			},
		},
		-- OnHiddenCallback clears the lock set by the hooked ZO_StackSplit_SplitItem
		-- This must fire BEFORE keybinds are restored to prevent re-triggering
		OnHiddenCallback = function(dialog)
			BETTERUI.Inventory._splitStackLock = nil
		end,
	})
end

--- Initializes the confirmation dialog for item destruction.
--- Purpose: Safety prompt before destroying items.
--- Mechanics: Registers `BETTERUI_CONFIRM_DESTROY_DIALOG`, shows item link, calls `TryDestroyItem` on confirm.
function BETTERUI.Inventory.Class:InitializeConfirmDestroyDialog()
	BETTERUI.CIM.Dialogs.Register("BETTERUI_CONFIRM_DESTROY_DIALOG", {
		blockDirectionalInput = true,
		canQueue = true,
		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.BASIC,
			allowRightStickPassThrough = true,
		},
		title = {
			text = function(dialog)
				return GetString(rawget(_G, "SI_DESTROY_ITEM_PROMPT_TITLE")) or "Destroy Item"
			end,
		},
		mainText = {
			text = function(dialog)
				local link = dialog and dialog.data and dialog.data.itemLink
				if link and link ~= "" then
					return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_DESTROY_CONFIRM_FORMAT")), link)
				end
				return GetString(rawget(_G, "SI_BETTERUI_DESTROY_CONFIRM_GENERIC"))
			end,
		},
		buttons = {
			{ keybind = "DIALOG_NEGATIVE", text = GetString(rawget(_G, "SI_DIALOG_CANCEL")) },
			{
				keybind = "DIALOG_PRIMARY",
				text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
				callback = function(dialog)
					local d = dialog and dialog.data
					if d and d.bagId and d.slotIndex then
						-- Force destruction on explicit user confirmation
						local destroyed = BETTERUI.Inventory.TryDestroyItem(d.bagId, d.slotIndex, true)
						-- Refresh lists shortly after to reflect removal
						if destroyed then
							BETTERUI.Inventory.Tasks:Schedule("destroyRefresh",
								BETTERUI.CIM.CONST.TIMING.LIST_DESTRUCTION_DELAY_MS, function()
									if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
										GAMEPAD_INVENTORY:RefreshItemList()
									end
								end)
						end
					end
					ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_CONFIRM_DESTROY_DIALOG")
				end,
			},
		},
	})
end

--- Initializes the confirmation dialog for armory item destruction.
--- Purpose: Safety prompt before destroying armory-related items with 2-second cooldown.
--- Mechanics: Registers `ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG` with native `RespondToDestroyRequest()`.
function BETTERUI.Inventory.Class:InitializeConfirmDestroyArmoryItemDialog()
	local function ReleaseDialog(destroyItem)
		RespondToDestroyRequest(destroyItem == true)
		ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG)
	end

	BETTERUI.CIM.Dialogs.Register(ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG, {
		blockDialogReleaseOnPress = true,
		canQueue = true,
		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.BASIC,
			allowRightStickPassThrough = true,
		},
		setup = function(dialog)
			self.destroyConfirmText = nil
			dialog:setupFunc()
		end,
		noChoiceCallback = function(dialog)
			RespondToDestroyRequest(false)
		end,
		title = {
			text = SI_DIALOG_DESTROY_ARMORY_ITEM_TITLE,
		},
		mainText = {
			text = SI_GAMEPAD_ARMORY_CONFIRM_DESTROY_ITEM_BODY,
		},
		buttons = {
			{
				onShowCooldown = 2000,
				keybind = "DIALOG_PRIMARY",
				text = GetString(rawget(_G, "SI_YES")),
				callback = function()
					ReleaseDialog(true)
				end,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				text = GetString(rawget(_G, "SI_NO")),
				callback = function()
					ReleaseDialog()
				end,
			},
		}
	})
end
