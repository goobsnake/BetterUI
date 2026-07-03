--[[
File: Modules/Inventory/Dialogs/InventoryDialogs.lua
Purpose: Dialog registrations for Inventory operations:
         - Split Stack
         - Confirm Destroy Item
         - Confirm Destroy Armory Item
]]

local function TraceInventoryDialog(event, phase, data)
	local L = BETTERUI.Log
	if not (L and L.TraceEvent) then return end
	data = data or {}
	data.module = data.module or "Inventory"
	data.dialogName = data.dialogName or ZO_GAMEPAD_SPLIT_STACK_DIALOG
	local categories = L.CATEGORY or {}
	L.TraceEvent(categories.ACTION, event, phase, data)
end

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
		local placed = CallSecureProtected("PlaceInInventory", bagId, emptySlotIndex)
		TraceInventoryDialog("inventory.split_stack_dialog", placed and "place_success" or "place_failed", {
			fn = "BETTERUI_TryPlaceInventoryItemInEmptySlot",
			targetBag = targetBag,
			placeBagId = bagId,
			emptySlotIndex = emptySlotIndex,
		})
		if not placed then
			-- A failed placement leaves the picked-up stack stranded on the cursor.
			ClearCursor()
			local failedStringId = rawget(_G, "SI_BETTERUI_SECURE_ACTION_FAILED")
			BETTERUI.CIM.UserNotify("InventoryDialogs:PlaceFailed",
				(failedStringId and GetString(failedStringId)) or "The action could not be completed.")
		end
	else
		local errorStringId = (targetBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL
			or SI_INVENTORY_ERROR_BANK_FULL
		TraceInventoryDialog("inventory.split_stack_dialog", "place_blocked", {
			fn = "BETTERUI_TryPlaceInventoryItemInEmptySlot",
			reason = "noEmptySlot",
			targetBag = targetBag,
			errorStringId = errorStringId,
		})
		BETTERUI.CIM.UserNotify("InventoryDialogs:NoSlot", errorStringId)
	end
end

local function IsInventoryDialogManagedScene()
	if type(BETTERUI.GetModuleEnabled) == "function" and BETTERUI.GetModuleEnabled("Inventory") ~= true then
		return false
	end
	return type(BETTERUI.Utils) == "table" and type(BETTERUI.Utils.IsInventorySceneShowing) == "function"
		and BETTERUI.Utils.IsInventorySceneShowing() == true
end

local function GetDialogButtonCallback(dialogInfo, keybind)
	local buttons = dialogInfo and dialogInfo.buttons
	if type(buttons) ~= "table" then
		return nil
	end
	for _, button in ipairs(buttons) do
		if type(button) == "table" and button.keybind == keybind and type(button.callback) == "function" then
			return button.callback
		end
	end
	return nil
end

local function CallPreviousDialogCallback(callback, dialog, ...)
	if type(callback) ~= "function" then
		return false
	end
	local ok, err = pcall(callback, dialog, ...)
	if not ok then
		TraceInventoryDialog("inventory.dialog_restore", "callback_error", {
			fn = "InventoryDialogs.RestoreDelegate",
			error = tostring(err),
		})
		return false
	end
	return true
end

--- Initializes the split stack dialog for moving items.
--- Purpose: Allows splitting stacks when moving to/from bank.
--- Mechanics: Registers `ZO_GAMEPAD_SPLIT_STACK_DIALOG` with custom callback to `PickupInventoryItem`.
--- References: Called by Initialize.
---@return nil
function BETTERUI.Inventory.Class:InitializeSplitStackDialog()
	local existingDialogInfo = BETTERUI.CIM.Dialogs.GetCurrentInfo(ZO_GAMEPAD_SPLIT_STACK_DIALOG)
	local existingSetup = existingDialogInfo and existingDialogInfo.setup
	local existingHidden = existingDialogInfo and existingDialogInfo.OnHiddenCallback
	local existingNegative = GetDialogButtonCallback(existingDialogInfo, "DIALOG_NEGATIVE")
	local existingPrimary = GetDialogButtonCallback(existingDialogInfo, "DIALOG_PRIMARY")

	BETTERUI.CIM.Dialogs.Register(ZO_GAMEPAD_SPLIT_STACK_DIALOG, {
		canQueue = true,

		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.ITEM_SLIDER,
		},

		setup = function(dialog, data)
			local isManaged = IsInventoryDialogManagedScene()
			dialog._betteruiManaged = isManaged == true
			if isManaged then
				dialog:setupFunc()
				TraceInventoryDialog("inventory.split_stack_dialog", "setup", {
					fn = "InventoryDialogs.InitializeSplitStackDialog.setup",
					bagId = data and data.bagId,
					slotIndex = data and data.slotIndex,
					stackSize = data and data.stackSize,
					hasSlider = dialog and dialog.slider ~= nil,
					managed = true,
				})
				-- Hide custom slider hint controls from CraftBagQuantityDialog
				-- Both dialogs share the GAMEPAD_DIALOGS.ITEM_SLIDER template, so
				-- controls created by SetupSliderKeybindHints persist between uses
				if dialog._minIconLabel then dialog._minIconLabel:SetHidden(true) end
				if dialog._maxIconLabel then dialog._maxIconLabel:SetHidden(true) end
				if dialog._minTextLabel then dialog._minTextLabel:SetHidden(true) end
				if dialog._maxTextLabel then dialog._maxTextLabel:SetHidden(true) end
				return
			end

			local delegated = CallPreviousDialogCallback(existingSetup, dialog, data)
			TraceInventoryDialog("inventory.split_stack_dialog", "setup", {
				fn = "InventoryDialogs.InitializeSplitStackDialog.setup",
				bagId = data and data.bagId,
				slotIndex = data and data.slotIndex,
				stackSize = data and data.stackSize,
				managed = false,
				delegated = delegated,
			})
			if not delegated then
				dialog:setupFunc()
			end
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
				callback = function(dialog)
					if dialog and dialog._betteruiManaged then
						local dialogData = dialog.data
						TraceInventoryDialog("inventory.split_stack_dialog", "cancel", {
							fn = "InventoryDialogs.InitializeSplitStackDialog.cancel",
							bagId = dialogData and dialogData.bagId,
							slotIndex = dialogData and dialogData.slotIndex,
							stackSize = dialogData and dialogData.stackSize,
							managed = true,
						})
						return
					end

					CallPreviousDialogCallback(existingNegative, dialog)
				end,
			},
			{
				keybind = "DIALOG_PRIMARY",
				text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
				callback = function(dialog)
					if not (dialog and dialog._betteruiManaged) then
						CallPreviousDialogCallback(existingPrimary, dialog)
						return
					end

					local dialogData = dialog.data
					local quantity = ZO_GenericGamepadItemSliderDialogTemplate_GetSliderValue(dialog)
					TraceInventoryDialog("inventory.split_stack_dialog", "confirm", {
						fn = "InventoryDialogs.InitializeSplitStackDialog.confirm",
						bagId = dialogData and dialogData.bagId,
						slotIndex = dialogData and dialogData.slotIndex,
						stackSize = dialogData and dialogData.stackSize,
						quantity = quantity,
						managed = true,
					})
					if not dialogData or not dialogData.bagId or not dialogData.slotIndex or not quantity then
						TraceInventoryDialog("inventory.split_stack_dialog", "blocked", {
							fn = "InventoryDialogs.InitializeSplitStackDialog.confirm",
							reason = "missingDialogData",
							hasDialogData = dialogData ~= nil,
							hasQuantity = quantity ~= nil,
						})
						local failedStringId = rawget(_G, "SI_BETTERUI_SECURE_ACTION_FAILED")
						BETTERUI.CIM.UserNotify("InventoryDialogs:SplitMissingData",
							(failedStringId and GetString(failedStringId)) or "The action could not be completed.")
						return
					end

					-- Save the uniqueId BEFORE split so inventory refresh restores position
					-- Store in dedicated field to survive list selection callback overwriting currentlySelectedData
					local uniqueId = GetItemUniqueId(dialogData.bagId, dialogData.slotIndex)
					if uniqueId and GAMEPAD_INVENTORY then
						GAMEPAD_INVENTORY._splitStackUniqueId = uniqueId
					end

					local pickupSucceeded = CallSecureProtected("PickupInventoryItem", dialogData.bagId, dialogData.slotIndex, quantity)
					TraceInventoryDialog("inventory.split_stack_dialog", pickupSucceeded and "pickup_success" or "pickup_failed", {
						fn = "InventoryDialogs.InitializeSplitStackDialog.confirm",
						bagId = dialogData and dialogData.bagId,
						slotIndex = dialogData and dialogData.slotIndex,
						quantity = quantity,
						uniqueId = uniqueId,
						managed = true,
					})
					if pickupSucceeded then
						BETTERUI_TryPlaceInventoryItemInEmptySlot(dialogData.bagId)
					else
						-- Nothing was picked up, so there is no cursor item to clear.
						local failedStringId = rawget(_G, "SI_BETTERUI_SECURE_ACTION_FAILED")
						BETTERUI.CIM.UserNotify("InventoryDialogs:SplitPickupFailed",
							(failedStringId and GetString(failedStringId)) or "The action could not be completed.")
					end
				end,
			},
		},
		-- OnHiddenCallback clears the lock set by the hooked ZO_StackSplit_SplitItem
		-- This must fire BEFORE keybinds are restored to prevent re-triggering
		OnHiddenCallback = function(dialog)
			if dialog and dialog._betteruiManaged then
				BETTERUI.Inventory._splitStackLock = nil
				local inv = GAMEPAD_INVENTORY
				local inventorySceneShowing = BETTERUI.CIM and BETTERUI.CIM.Utils
					and BETTERUI.CIM.Utils.IsInventorySceneShowing
					and BETTERUI.CIM.Utils.IsInventorySceneShowing()
				if inventorySceneShowing and inv and inv.RestoreStateAfterDialog then
					inv:RestoreStateAfterDialog("splitStackDialogPostHideRefresh")
				end
				TraceInventoryDialog("inventory.split_stack_dialog", "hidden", {
					fn = "InventoryDialogs.InitializeSplitStackDialog.OnHiddenCallback",
					inventorySceneShowing = inventorySceneShowing == true,
					restoredState = inventorySceneShowing and inv and inv.RestoreStateAfterDialog ~= nil or false,
					lockCleared = BETTERUI.Inventory._splitStackLock == nil,
					managed = true,
				})
				return
			end

			local delegated = CallPreviousDialogCallback(existingHidden, dialog)
			TraceInventoryDialog("inventory.split_stack_dialog", "hidden", {
				fn = "InventoryDialogs.InitializeSplitStackDialog.OnHiddenCallback",
				delegated = delegated,
				managed = false,
			})
		end,
	})
end

--- Initializes the confirmation dialog for item destruction.
--- Purpose: Safety prompt before destroying items.
--- Mechanics: Registers `BETTERUI_CONFIRM_DESTROY_DIALOG`, shows item link, calls `TryDestroyItem` on confirm.
function BETTERUI.Inventory.Class:InitializeConfirmDestroyDialog()
	if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.ACTION, "Confirm destroy dialog initialized") end
	BETTERUI.CIM.Dialogs.Register("BETTERUI_CONFIRM_DESTROY_DIALOG", {
		blockDirectionalInput = true,
		canQueue = true,
		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.BASIC,
			allowRightStickPassThrough = true,
		},
		title = {
			text = function(dialog)
				return GetString(SI_PROMPT_TITLE_DESTROY_ITEM_PROMPT)
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
			{
				keybind = "DIALOG_NEGATIVE",
				text = GetString(rawget(_G, "SI_DIALOG_CANCEL")),
				callback = function(dialog)
					local d = dialog and dialog.data
					TraceInventoryDialog("inventory.destroy_dialog", "cancel", {
						fn = "InventoryDialogs.InitializeConfirmDestroyDialog.cancel",
						dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
						bagId = d and d.bagId,
						slotIndex = d and d.slotIndex,
						slotType = d and d.slotType,
						itemLink = d and d.itemLink,
					})
				end,
			},
			{
				keybind = "DIALOG_PRIMARY",
				text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
				callback = function(dialog)
					local d = dialog and dialog.data
					if d and d.bagId and d.slotIndex then
						TraceInventoryDialog("inventory.destroy_dialog", "confirm", {
							fn = "InventoryDialogs.InitializeConfirmDestroyDialog.confirm",
							dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
							bagId = d.bagId,
							slotIndex = d.slotIndex,
							slotType = d.slotType,
							itemLink = d.itemLink,
						})
						if BETTERUI.Inventory.Utils.IsSlotIdentityCurrent(d.expectedSlotIdentity, d.bagId, d.slotIndex) ~= true then
							TraceInventoryDialog("inventory.destroy_dialog", "blocked", {
								fn = "InventoryDialogs.InitializeConfirmDestroyDialog.confirm",
								dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
								reason = "staleSlot",
								bagId = d.bagId,
								slotIndex = d.slotIndex,
								slotType = d.slotType,
								itemLink = d.itemLink,
							})
							BETTERUI.CIM.UserNotify("InventoryDestroy:StaleSlot",
								GetString(rawget(_G, "SI_BETTERUI_ITEM_CHANGED_CANCELLED")))
							ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_CONFIRM_DESTROY_DIALOG")
							return
						end
						-- Force destruction on explicit user confirmation
						local destroyed = BETTERUI.Inventory.TryDestroyItem(d.bagId, d.slotIndex, true, nil, d.slotType)
						-- Refresh lists shortly after to reflect removal
						local refreshScheduled = false
						if destroyed then
							refreshScheduled = true
							BETTERUI.Inventory.Tasks:Schedule("destroyRefresh",
								BETTERUI.CIM.CONST.TIMING.LIST_DESTRUCTION_DELAY_MS, function()
									if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
										GAMEPAD_INVENTORY:RefreshItemList()
									end
							end)
						end
						local released = ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_CONFIRM_DESTROY_DIALOG")
						TraceInventoryDialog("inventory.destroy_dialog", "complete", {
							fn = "InventoryDialogs.InitializeConfirmDestroyDialog.confirm",
							dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
							bagId = d.bagId,
							slotIndex = d.slotIndex,
							slotType = d.slotType,
							itemLink = d.itemLink,
							destroyed = destroyed == true,
							refreshScheduled = refreshScheduled,
							releaseReturned = released ~= nil,
						})
						return
					end
					TraceInventoryDialog("inventory.destroy_dialog", "blocked", {
						fn = "InventoryDialogs.InitializeConfirmDestroyDialog.confirm",
						dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
						reason = "missingDialogData",
						hasDialog = dialog ~= nil,
						hasDialogData = d ~= nil,
					})
					local released = ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_CONFIRM_DESTROY_DIALOG")
					TraceInventoryDialog("inventory.destroy_dialog", "complete", {
						fn = "InventoryDialogs.InitializeConfirmDestroyDialog.confirm",
						dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
						destroyed = false,
						refreshScheduled = false,
						releaseReturned = released ~= nil,
					})
				end,
			},
		},
	})
end

--- Initializes the confirmation dialog for armory item destruction.
--- Purpose: Safety prompt before destroying armory-related items with 2-second cooldown.
--- Mechanics: Registers `ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG` with native `RespondToDestroyRequest()`.
function BETTERUI.Inventory.Class:InitializeConfirmDestroyArmoryItemDialog()
	local existingDialogInfo = BETTERUI.CIM.Dialogs.GetCurrentInfo(ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG)
	local existingSetup = existingDialogInfo and existingDialogInfo.setup
	local existingNoChoice = existingDialogInfo and existingDialogInfo.noChoiceCallback
	local existingPrimary = GetDialogButtonCallback(existingDialogInfo, "DIALOG_PRIMARY")
	local existingNegative = GetDialogButtonCallback(existingDialogInfo, "DIALOG_NEGATIVE")

	local function ReleaseDialog(destroyItem, source)
		TraceInventoryDialog("inventory.armory_destroy_dialog", destroyItem and "confirm" or "cancel", {
			fn = "InventoryDialogs.InitializeConfirmDestroyArmoryItemDialog.ReleaseDialog",
			dialogName = ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG,
			destroyItem = destroyItem == true,
			source = source,
		})
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
			local isManaged = IsInventoryDialogManagedScene()
			dialog._betteruiManaged = isManaged == true
			if isManaged then
				self.destroyConfirmText = nil
				dialog:setupFunc()
				TraceInventoryDialog("inventory.armory_destroy_dialog", "setup", {
					fn = "InventoryDialogs.InitializeConfirmDestroyArmoryItemDialog.setup",
					dialogName = ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG,
					managed = true,
				})
				return
			end

			local delegated = CallPreviousDialogCallback(existingSetup, dialog)
			TraceInventoryDialog("inventory.armory_destroy_dialog", "setup", {
				fn = "InventoryDialogs.InitializeConfirmDestroyArmoryItemDialog.setup",
				dialogName = ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG,
				managed = false,
				delegated = delegated,
			})
			if not delegated then
				dialog:setupFunc()
			end
		end,
		noChoiceCallback = function(dialog)
			if dialog and dialog._betteruiManaged then
				TraceInventoryDialog("inventory.armory_destroy_dialog", "no_choice", {
					fn = "InventoryDialogs.InitializeConfirmDestroyArmoryItemDialog.noChoiceCallback",
					dialogName = ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG,
					managed = true,
				})
				RespondToDestroyRequest(false)
				return
			end

			local delegated = CallPreviousDialogCallback(existingNoChoice, dialog)
			TraceInventoryDialog("inventory.armory_destroy_dialog", "no_choice", {
				fn = "InventoryDialogs.InitializeConfirmDestroyArmoryItemDialog.noChoiceCallback",
				dialogName = ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG,
				managed = false,
				delegated = delegated,
			})
			if not delegated then
				RespondToDestroyRequest(false)
			end
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
				callback = function(dialog)
					if dialog and dialog._betteruiManaged then
						ReleaseDialog(true, "primary")
						return
					end
					TraceInventoryDialog("inventory.armory_destroy_dialog", "confirm", {
						fn = "InventoryDialogs.InitializeConfirmDestroyArmoryItemDialog.primary",
						dialogName = ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG,
						managed = false,
					})
					local delegated = CallPreviousDialogCallback(existingPrimary, dialog)
					if not delegated then
						RespondToDestroyRequest(true)
					end
				end,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				text = GetString(rawget(_G, "SI_NO")),
				callback = function(dialog)
					if dialog and dialog._betteruiManaged then
						ReleaseDialog(false, "negative")
						return
					end
					TraceInventoryDialog("inventory.armory_destroy_dialog", "cancel", {
						fn = "InventoryDialogs.InitializeConfirmDestroyArmoryItemDialog.negative",
						dialogName = ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG,
						managed = false,
					})
					local delegated = CallPreviousDialogCallback(existingNegative, dialog)
					if not delegated then
						RespondToDestroyRequest(false)
					end
				end,
			},
		}
	})
end
