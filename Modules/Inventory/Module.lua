--[[
File: Modules/Inventory/Module.lua
Purpose: Entry point and settings configuration for the Inventory module.
]]

-- Module initialization
---@type BetterUIModuleRoot
BETTERUI.Inventory = BETTERUI.Inventory or {}
local Inventory = BETTERUI.Inventory
local ARCHETYPES = BETTERUI.CIM and BETTERUI.CIM.ARCHETYPES or {}
local RUNTIME_COORDINATOR = ARCHETYPES.RUNTIME_COORDINATOR or "runtime-coordinator"

---@type BetterUIModuleArchetypeRuntimeCoordinator
Inventory.ARCHETYPE = RUNTIME_COORDINATOR
---@type BetterUIModuleRootContract
Inventory.ROOT_CONTRACT = {
    name = "Inventory",
    archetype = Inventory.ARCHETYPE,
    init = true,
    setup = true,
}

Inventory.Dialogs = Inventory.Dialogs or {}
Inventory.Dialogs.EQUIP_SLOT = "BETTERUI_EQUIP_SLOT_DIALOG"

function Inventory.GetEquipSlotDialogName()
    return Inventory.Dialogs.EQUIP_SLOT
end

function Inventory.InvokeDialog(methodName, ...)
    local dialogs = Inventory.Dialogs
    local dialogFn = dialogs and dialogs[methodName]
    if type(dialogFn) ~= "function" then
        return false
    end

    dialogFn(...)
    return true
end

local function EnsureLegacyEquipSlotDialogAlias()
    BETTERUI_EQUIP_SLOT_DIALOG = Inventory.GetEquipSlotDialogName()
end

local function InitializeSecureWheelHooks()
    local assignableUtilityWheelGamepad = ZO_AssignableUtilityWheel_Gamepad
    if assignableUtilityWheelGamepad and not BETTERUI._secureWheelHooked then
        ZO_PreHook(assignableUtilityWheelGamepad, "TryAssignPendingToSelectedEntry", function(self, clearPending)
            local selectedEntry = self:GetSelectedRadialEntry()
            local pendingSlotData = self.pendingSlotData
            if self.radialMenu:IsShown() and pendingSlotData and selectedEntry then
                local actionSlotIndex = selectedEntry.data.slotIndex
                local hotbarCategory = self:GetHotbarCategory()
                if pendingSlotData.actionId then
                    CallSecureProtected("SelectSlotSimpleAction", pendingSlotData.slotType, pendingSlotData.actionId,
                        actionSlotIndex, hotbarCategory)
                elseif pendingSlotData.bagId and pendingSlotData.itemSlotIndex then
                    CallSecureProtected("SelectSlotItem", pendingSlotData.bagId, pendingSlotData.itemSlotIndex,
                        actionSlotIndex, hotbarCategory)
                end

                if clearPending then
                    self.pendingSlotData = nil
                end
                if SOUNDS and PlaySound then
                    PlaySound(SOUNDS.RADIAL_MENU_SELECTION)
                end

                if self.data and self.data.customNarrationObjectName and SCREEN_NARRATION_MANAGER then
                    SCREEN_NARRATION_MANAGER:QueueCustomEntry(self.data.customNarrationObjectName)
                end

                if self.data and self.data.showPendingIcon then
                    self:RefreshPendingIcon()
                end
            end
            -- Always return true to cancel the original unprotected native execution
            return true
        end)
        BETTERUI._secureWheelHooked = true
    end
end

Inventory.InitializeSecureWheelHooks = InitializeSecureWheelHooks

local function TrackPanelRegistration(reason)
    Inventory._panelRegistrationReason = reason
    Inventory._panelRegistrationDeferred = reason == "missing_register_panel"
end

local function TryInitializeCraftBagQuantityDialog()
    local dialogs = Inventory.Dialogs
    local initializeDialog = dialogs and dialogs.InitializeCraftBagQuantityDialog
    if type(initializeDialog) ~= "function" then
        return false
    end

    initializeDialog()
    return true
end

local function TryRegisterInventoryNarration(...)
    local narration = BETTERUI.CIM and BETTERUI.CIM.Narration
    local registerNarration = narration and narration.RegisterListNarration
    if type(registerNarration) ~= "function" then
        return false
    end

    registerNarration(...)
    return true
end

local function NotifyInventorySetupFailure(context, messageText)
    assert(BETTERUI.CIM and BETTERUI.CIM.UserNotify,
        "Inventory setup failure handling requires BETTERUI.CIM.UserNotify")
    BETTERUI.CIM.UserNotify(context, messageText)
end

local function RegisterSharedItemSupport()
    local sharedItemSupport = BETTERUI.CIM and BETTERUI.CIM.SharedItemSupport
    local categories = BETTERUI.Inventory.Categories

    if Inventory._sharedItemSupportRegistered == true then
        return true
    end

    if not sharedItemSupport then
        return false
    end

    if type(sharedItemSupport.RegisterCategorySupport) == "function"
        and categories
        and categories.DoesItemMatchCategory
        and categories.GetBestItemCategoryDescription then
        sharedItemSupport.RegisterCategorySupport({
            doesItemMatchCategory = categories.DoesItemMatchCategory,
            getBestItemCategoryDescription = categories.GetBestItemCategoryDescription,
        })
    end

    if type(sharedItemSupport.RegisterTooltipSupport) == "function" then
        sharedItemSupport.RegisterTooltipSupport({
            applyTooltipStyles = BETTERUI.Inventory.ApplyTooltipStyles,
            cleanupEnhancedTooltip = BETTERUI.Inventory.CleanupEnhancedTooltip,
            isItemComparisonEnabled = BETTERUI.Inventory.IsItemComparisonEnabled,
            compareItem = function(candidateLink, candidateBagId, candidateSlotIndex, equippedBagId)
                if BETTERUI.Inventory.StatComparison and BETTERUI.Inventory.StatComparison.Compare then
                    return BETTERUI.Inventory.StatComparison.Compare(candidateLink,
                        candidateBagId, candidateSlotIndex, equippedBagId)
                end
                return nil
            end,
            showComparisonOnTooltip = BETTERUI.Inventory.ShowComparisonOnTooltip,
            updateTooltipEquippedText = BETTERUI.Inventory.UpdateTooltipEquippedText,
        })
    end

    Inventory._sharedItemSupportRegistered = true
    return true
end

BETTERUI.CIM.ApplyModuleSharedSettingsStatics(Inventory, "Inventory")

--- Initializes defaults and migrates legacy settings for the Inventory module.
---
---@param m_options BetterUIModuleOptions|nil Module options table
---@return BetterUIModuleOptions m_options Initialized options with defaults applied
---@type BetterUIModuleInitHook
function Inventory.InitModule(m_options)
    m_options = m_options or {}
    ---@cast m_options BetterUIModuleOptions
    local defaults = Inventory.DEFAULTS
    local fallbackDefaults = {
        quickDestroy = false,
        enableBatchDestroy = false,
        enableCarousel = true,
        useTriggersForSkip = false,
        triggerSpeed = 10,
        bindOnEquipProtection = true,
        enableCompanionJunk = false,
        showIconEnchantment = true,
        showIconSetGear = true,
        showIconUnboundItem = true,
        showIconResearchableTrait = true,
        showIconUnknownRecipe = true,
        showIconUnknownBook = true,
    }

    m_options = BETTERUI.CIM.InitModuleDefaults("Inventory", m_options, defaults, fallbackDefaults,
        function(options)
            -- Currency defaults should match the canonical "default" preset.
            local defaultCurrencyPreset = BETTERUI.CURRENCY_PRESETS and BETTERUI.CURRENCY_PRESETS.default
            if type(defaultCurrencyPreset) == "table" then
                for key, value in pairs(defaultCurrencyPreset) do
                    if options[key] == nil then
                        options[key] = value
                    end
                end
            else
                -- Fallback defaults if preset table is unavailable.
				local currencyFallbackDefaults = {
                    showCurrencyGold = true,
                    showCurrencyAlliancePoints = true,
                    showCurrencyTelVar = true,
                    showCurrencyCrownGems = true,
                    showCurrencyCrowns = true,
                    showCurrencyTransmute = true,
                    showCurrencyWritVouchers = true,
                    showCurrencyTradeBars = true,
                    showCurrencyUndauntedKeys = true,
                    showCurrencyOutfitTokens = true,
                    showCurrencySeals = true,
                    showCurrencyTomePoints = true,
                    orderCurrencyGold = 1,
                    orderCurrencyAlliancePoints = 2,
                    orderCurrencyTelVar = 3,
                    orderCurrencyUndauntedKeys = 4,
                    orderCurrencyTransmute = 5,
                    orderCurrencyCrowns = 6,
                    orderCurrencyCrownGems = 7,
                    orderCurrencyWritVouchers = 8,
                    orderCurrencyTradeBars = 9,
                    orderCurrencyOutfitTokens = 10,
                    orderCurrencySeals = 11,
                    orderCurrencyTomePoints = 12,
                }
				for key, value in pairs(currencyFallbackDefaults) do
                    if options[key] == nil then
                        options[key] = value
                    end
                end
            end

            if options["currencyPreset"] == nil then options["currencyPreset"] = "default" end
            if options["currencyOrder"] == nil then
                options["currencyOrder"] =
                "gold,ap,telvar,keys,transmute,crowns,gems,writs,tradebars,outfit,seals,tomepoints"
            end

            -- Migration: preset-based profiles should inherit newly enabled tome points.
            -- Do not override custom profiles.
            local activeCurrencyPreset = options["currencyPreset"]
            if activeCurrencyPreset ~= "custom" and BETTERUI.CURRENCY_PRESETS then
                local activePresetData = BETTERUI.CURRENCY_PRESETS[activeCurrencyPreset]
                if type(activePresetData) == "table" and activePresetData["showCurrencyTomePoints"] == true then
                    options["showCurrencyTomePoints"] = true
                end
            end
        end)

    return m_options
end

---@type BetterUIModuleSetupHook
function Inventory.Setup()
    BETTERUI.CIM.RegisterModuleAccessors(Inventory, "Inventory")
    RegisterSharedItemSupport()
    EnsureLegacyEquipSlotDialogAlias()
    if Inventory._inventoryActionModesRegistered ~= true
        and BETTERUI.CIM
        and BETTERUI.CIM.Keybinds
        and BETTERUI.CIM.Keybinds.RegisterInventoryActionModes
    then
        BETTERUI.CIM.Keybinds.RegisterInventoryActionModes({
            itemList = Inventory.CONST.ITEM_LIST_ACTION_MODE,
            craftBag = Inventory.CONST.CRAFT_BAG_ACTION_MODE,
            category = Inventory.CONST.CATEGORY_ITEM_ACTION_MODE,
        })
        Inventory._inventoryActionModesRegistered = true
    end

    if Inventory._inventoryDialogInvokerRegistered ~= true
        and BETTERUI.CIM
        and BETTERUI.CIM.RegisterInventoryDialogInvoker
    then
        BETTERUI.CIM.RegisterInventoryDialogInvoker(Inventory.InvokeDialog)
        Inventory._inventoryDialogInvokerRegistered = true
    end
    local panelOk, panelReason = BETTERUI.CIM.TryRegisterModulePanel(Inventory, "Inventory", "Inventory", "Inventory")
    TrackPanelRegistration(panelReason)
    if not panelOk and panelReason ~= nil and panelReason ~= "missing_register_panel" and BETTERUI.Debug then
        BETTERUI.Debug(string.format("[Inventory] Settings panel registration reported: %s", tostring(panelReason)))
    end

	Inventory.NativeGlobals = Inventory.NativeGlobals or {}
	local native = Inventory.NativeGlobals
	if native.gamepadInventoryFragment == nil then
		native.gamepadInventoryFragment = GAMEPAD_INVENTORY_FRAGMENT
	end

	-- Replace the native GAMEPAD_INVENTORY global with our custom class
	GAMEPAD_INVENTORY = Inventory.Class:New(BETTERUI_GamepadInventoryTopLevel)

	-- Create the replacement scene fragment using our custom top level control
	GAMEPAD_INVENTORY_FRAGMENT = ZO_SimpleSceneFragment:New(BETTERUI_GamepadInventoryTopLevel)
	GAMEPAD_INVENTORY_FRAGMENT:SetHideOnSceneHidden(true)

	-- Update the Inventory Scene with the new fragment
	-- Note: GAMEPAD_INVENTORY_ROOT_SCENE is the native scene, we are swapping the content fragment.
    if native.gamepadInventoryFragment
        and native.gamepadInventoryFragment ~= GAMEPAD_INVENTORY_FRAGMENT
        and GAMEPAD_INVENTORY_ROOT_SCENE
        and GAMEPAD_INVENTORY_ROOT_SCENE.RemoveFragment
    then
        GAMEPAD_INVENTORY_ROOT_SCENE:RemoveFragment(native.gamepadInventoryFragment)
    end
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(GAMEPAD_INVENTORY_FRAGMENT)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(MINIMIZE_CHAT_FRAGMENT)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)

	-- Initialize the Craft Bag quantity dialog for stow/retrieve operations
	local dialogOk = TryInitializeCraftBagQuantityDialog()
	if not dialogOk then
		NotifyInventorySetupFailure("Inventory.Setup:CraftBagQuantityDialog",
            "Inventory craft bag quantity dialog init failed")
	end

	-- Hook ZO_StackSplit_SplitItem to prevent duplicate dialogs using a lock flag.
	-- Uses ZO_PreHook instead of replacing the global function.
	if not Inventory._splitStackHookInstalled and type(ZO_PreHook) == "function" then
		ZO_PreHook("ZO_StackSplit_SplitItem", function(inventorySlotControl)
			if Inventory._splitStackLock then
				return true
			end

			Inventory._splitStackLock = true

			local retriesRemaining = 20
			local function ReleaseSplitLockIfNoDialog()
				if ZO_Dialogs_IsShowing and not ZO_Dialogs_IsShowing(ZO_GAMEPAD_SPLIT_STACK_DIALOG) then
					Inventory._splitStackLock = nil
					local inventorySceneShowing = BETTERUI.CIM and BETTERUI.CIM.Utils
						and BETTERUI.CIM.Utils.IsInventorySceneShowing
						and BETTERUI.CIM.Utils.IsInventorySceneShowing()
					if inventorySceneShowing and GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RestoreStateAfterDialog then
						GAMEPAD_INVENTORY:RestoreStateAfterDialog("splitStackLockFallbackRelease")
					end
					return
				end

				retriesRemaining = retriesRemaining - 1
				if retriesRemaining <= 0 then
					-- Safety release to avoid persistent lock if dialog lifecycle callbacks are missed.
					Inventory._splitStackLock = nil
					return
				end

				if Inventory.Tasks and Inventory.Tasks.Schedule then
					Inventory.Tasks:Schedule("splitStackLockFallbackRelease", 100, ReleaseSplitLockIfNoDialog)
				else
					zo_callLater(ReleaseSplitLockIfNoDialog, 100)
				end
			end

			if Inventory.Tasks and Inventory.Tasks.Schedule then
				Inventory.Tasks:Schedule("splitStackLockFallbackRelease", 120, ReleaseSplitLockIfNoDialog)
			else
				zo_callLater(ReleaseSplitLockIfNoDialog, 120)
			end

			return false
		end)
		Inventory._splitStackHookInstalled = true
	end

	-- Configure tooltip appearance and behavior
	ZO_GamepadTooltipTopLevelLeftTooltipContainer.tip.maxFadeGradientSize = BETTERUI.CIM.CONST
		.TOOLTIP_MAX_FADE_GRADIENT_SIZE

	-- Only apply custom tooltip styles (font scaling) if enhancements are enabled
	if BETTERUI.GetSetting("CIM", "enableTooltipEnhancements", true) ~= false then
		Inventory.ApplyTooltipStyles()
	end

	Inventory.EnableTooltipMouseWheel()

	-- Register custom dialog for Bind on Equip protection (if SaveEquip addon is not handling it)
	if not SaveEquip then
		BETTERUI.CIM.Dialogs.Register("CONFIRM_EQUIP_BOE", {
			gamepadInfo = {
				dialogType = GAMEPAD_DIALOGS.BASIC,
			},
			title = {
				text = SI_BETTERUI_SAVE_EQUIP_CONFIRM_TITLE,
			},
			mainText = {
				text = SI_BETTERUI_SAVE_EQUIP_CONFIRM_EQUIP_BOE,
			},
			buttons = {
				[1] = {
					text = SI_BETTERUI_SAVE_EQUIP_EQUIP,
					callback = function(dialog)
						dialog.data.callback()
					end
				},
				[2] = {
					text = SI_DIALOG_CANCEL,
				}
			}
		})
	end

	-- Register narration for Inventory scene (ACC-001)
	local narrOk = TryRegisterInventoryNarration(
		"gamepadInventory",
		function()
			return GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.currentlySelectedData
		end,
		function()
			return GetString(rawget(_G, "SI_BETTERUI_INV_TITLE"))
		end
	)
	if not narrOk then
		NotifyInventorySetupFailure("Inventory.Setup:Narration", "Inventory narration registration failed")
	end
end
