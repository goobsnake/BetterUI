local NAME = "BetterUIOrbs"
if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.Orbs == nil then BETTERUI.Orbs = {} end
local Orbs = BETTERUI.Orbs

-- Module State
local m_rootFrame = nil
local m_isInitialized = false
local m_pools = {}
local m_shieldBar = nil
local m_foodTracker = nil

-- Default Settings
local DEFAULTS = {
    enabled = false,
    scale = 1.15,
    offsetY = 80,
    useCustomTextures = false,
    doubleBarEnabled = false,
}

-------------------------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------------------------

-- Helper to find controls by name, handling both direct children and global names
local function FindControl(parent, name)
    local child = parent:GetNamedChild(name)
    if child then return child end
    return _G[parent:GetName() .. name]
end

-- Retrieve module settings
local function GetModuleSettings()
    if BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Orbs"] then
        return BETTERUI.Settings.Modules["Orbs"]
    end
    return DEFAULTS
end

-- Determine the base path for textures
local function GetTextureRootPath()
    local settings = GetModuleSettings()
    if settings.useCustomTextures then
        return "BetterUI/Modules/GeneralInterface/CustomOrbTextures"
    end
    return "BetterUI/Modules/GeneralInterface/OrbTextures"
end

-- Format a texture path
local function ResolveTexturePath(filename)
    return string.format("%s/%s", GetTextureRootPath(), filename)
end

-------------------------------------------------------------------------------------------------
-- Visuals & Layout
-------------------------------------------------------------------------------------------------

-- Update the frame's scale and position
local function UpdateFrameDimensions()
    if not m_rootFrame then return end
    local settings = GetModuleSettings()
    local scale = settings.scale or DEFAULTS.scale
    local offsetY = settings.offsetY or DEFAULTS.offsetY

    if scale then m_rootFrame:SetScale(scale) end
    if offsetY ~= nil then
        m_rootFrame:ClearAnchors()
        -- Invert offsetY because positive values should move the frame UP
        m_rootFrame:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -offsetY)
    end
end

-- Update textures for the main frame elements
local function ApplyThemeVisuals()
    if not m_rootFrame then return end
    
    local elements = {
        BgMiddle = 'BarBackgroundMiddle.dds',
        BgLeft = 'BarBackgroundLeft.dds',
        BgRight = 'BarBackgroundRight.dds',
        OrnamentLeft = 'OrnamentLeft.dds',
        OrnamentRight = 'OrnamentRight.dds'
    }

    for controlName, textureName in pairs(elements) do
        local ctrl = FindControl(m_rootFrame, controlName)
        if ctrl and ctrl.SetTexture then
            ctrl:SetTexture(ResolveTexturePath(textureName))
        end
    end

    -- Helper to update orb specific textures
    local function ApplyOrbTextures(parentName)
        local parent = FindControl(m_rootFrame, parentName)
        if not parent then return end
        
        local textures = {
            Aura = 'OrbGlow.dds',
            Fog = 'OrbFill.dds',
            Fog2 = 'OrbFill.dds',
            Border = 'OrbBorder.dds',
            BorderShade = 'OrbShadow.dds',
            Divide = 'OrbSplitter.dds'
        }

        for childName, textureFile in pairs(textures) do
            local child = FindControl(parent, childName)
            if child and child.SetTexture then
                child:SetTexture(ResolveTexturePath(textureFile))
            end
        end
    end

    ApplyOrbTextures('OrbHealth')
    ApplyOrbTextures('OrbMagicka')
    ApplyOrbTextures('OrbStamina')

    -- Update Overlays
    local overlays = {
        OrbShield = 'OrbOverlay_Shield.dds',
        OrbMount = 'OrbOverlay_Mount.dds',
        OrbWerewolf = 'OrbOverlay_Mount.dds'
    }

    for orbName, textureFile in pairs(overlays) do
        local orb = FindControl(m_rootFrame, orbName)
        if orb then
            local fog = FindControl(orb, 'Fog')
            if fog and fog.SetTexture then
                fog:SetTexture(ResolveTexturePath(textureFile))
            end
        end
    end
end

-- Layout constants
local LAYOUT_CONFIG = {
    GAMEPAD = {
        abilitySlotWidth = 64,
        abilitySlotOffsetX = 10,
        dualBarOffsetX = 44,
    },
    KEYBOARD = {
        abilitySlotWidth = 50,
        abilitySlotOffsetX = 2,
        dualBarOffsetX = 12,
    }
}

-- Skin the double action bar (back bar)
local function SkinBackBar(rootFrame, layout, actionBarContainer)
    local anchorControl = ZO_ActionBar1:GetNamedChild('WeaponSwap')
    local barParent = FindControl(rootFrame, 'ActionBarContainer')

    zo_callLater(function()
        local arrow = FindControl(actionBarContainer, 'Arrow')
        if arrow then arrow:SetHidden(true) end
    end, 150)

    local quickSlotButton = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if quickSlotButton and quickSlotButton.slot then
        quickSlotButton.slot:ClearAnchors()
        quickSlotButton.slot:SetAnchor(LEFT, barParent, LEFT)
    end

    anchorControl:ClearAnchors()
    anchorControl:SetAnchor(LEFT, barParent, LEFT, layout.dualBarOffsetX, 0)
end

-- Skin the main action bar
local function ApplyActionBarSkin(rootFrame, layout, actionBarContainer)
    local isGamePad = IsInGamepadPreferredMode()
    local template = isGamePad and 'BetterUI_OrbsSingle_Gamepad' or 'BetterUI_OrbsSingle_Keyboard'

    ZO_ActionBar1WeaponSwap:SetHidden(true)
    ZO_ActionBar1KeybindBG:SetHidden(true)
    ZO_WeaponSwap_SetPermanentlyHidden(ZO_ActionBar1WeaponSwap, true)

    if not isGamePad then
        zo_callLater(function()
            for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
                local btn = ZO_ActionBar_GetButton(i)
                if btn and btn.buttonText then btn.buttonText:SetHidden(true) end
            end
            local qs = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            if qs and qs.buttonText then qs.buttonText:SetHidden(true) end
        end, 150)
    end

    -- Companion Ultimate
    local companionButton = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION)
    if companionButton and companionButton.slot then
        companionButton.slot:ClearAnchors()
        companionButton.slot:SetAnchor(RIGHT, GuiRoot, RIGHT, -(layout.abilitySlotOffsetX + 13), layout.abilitySlotWidth)
    end

    ZO_HUDEquipmentStatus:ClearAnchors()
    ZO_HUDEquipmentStatus:SetAnchor(RIGHT, GuiRoot, RIGHT, -(layout.abilitySlotOffsetX + 13), 0)

    local barParent = FindControl(rootFrame, 'ActionBarContainer')
    local offsetX = ((layout.abilitySlotWidth + layout.abilitySlotOffsetX) * 5) / 2
    local settings = GetModuleSettings()

    -- Determine if we should use the double bar layout
    local useDoubleBar = settings.doubleBarEnabled or (actionBarContainer ~= nil)
    
    if useDoubleBar then
        template = isGamePad and 'BetterUI_OrbsDouble_Gamepad' or 'BetterUI_OrbsDouble_Keyboard'
    end

    ApplyTemplateToControl(rootFrame, template)

    -- Handle Layout Logic
    if useDoubleBar then
        if actionBarContainer ~= nil then
             -- External addon handling (Fancy Action Bar / AltAB)
            SkinBackBar(rootFrame, layout, actionBarContainer)
        else
            -- Native Double Bar Implementation
            local quickSlotButton = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            if quickSlotButton and quickSlotButton.slot then
                quickSlotButton.slot:ClearAnchors()
                quickSlotButton.slot:SetAnchor(BOTTOMLEFT, barParent, BOTTOMLEFT, 0, 0)
            end

            local firstActionButton = ZO_ActionBar_GetButton(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1)
            if firstActionButton and firstActionButton.slot then
                firstActionButton.slot:ClearAnchors()
                firstActionButton.slot:SetAnchor(BOTTOMLEFT, barParent, BOTTOM, -offsetX, 0)
            end

            local ultimateButton = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)
            if ultimateButton and ultimateButton.slot then
                ultimateButton.slot:ClearAnchors()
                ultimateButton.slot:SetAnchor(BOTTOMRIGHT, barParent, BOTTOMRIGHT, 0, 0)
            end
        end

        -- Active Bar Indicator Logic
        local indicator = FindControl(rootFrame, 'ActiveBarIndicator')
        if indicator then
            indicator:SetHidden(false)
            
            local function UpdateIndicator()
                local activeWeaponPair = GetActiveWeaponPairInfo()
                local isBackBar = (activeWeaponPair == ACTIVE_WEAPON_PAIR_BACKUP)
                
                indicator:ClearAnchors()
                if isBackBar then
                    indicator:SetAnchor(CENTER, barParent, TOP, 0, -20) 
                else
                    indicator:SetAnchor(CENTER, barParent, BOTTOM, 0, 20)
                end
            end
            
            UpdateIndicator()
            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, UpdateIndicator)
        end
    else
        -- Single Bar Logic
        local quickSlotButton = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if quickSlotButton and quickSlotButton.slot then
            quickSlotButton.slot:ClearAnchors()
            quickSlotButton.slot:SetAnchor(BOTTOMLEFT, barParent, BOTTOMLEFT)
        end

        local firstActionButton = ZO_ActionBar_GetButton(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1)
        if firstActionButton and firstActionButton.slot then
            firstActionButton.slot:ClearAnchors()
            firstActionButton.slot:SetAnchor(BOTTOMLEFT, barParent, BOTTOM, -offsetX, 0)
        end

        local ultimateButton = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)
        if ultimateButton and ultimateButton.slot then
            ultimateButton.slot:ClearAnchors()
            ultimateButton.slot:SetAnchor(BOTTOMRIGHT, barParent, BOTTOMRIGHT)
        end
        
        local indicator = FindControl(rootFrame, 'ActiveBarIndicator')
        if indicator then indicator:SetHidden(true) end
    end
end

-------------------------------------------------------------------------------------------------
-- BetterUIOrbBar Class
-------------------------------------------------------------------------------------------------

local BetterUIOrbBar = ZO_Object:Subclass()

local ORB_CONFIG = {
    [POWERTYPE_HEALTH] = {0, 1, 0, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restorehealth.dds'},
    [POWERTYPE_MAGICKA] = {0, 0.5, 0, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restoremagicka.dds'},
    [POWERTYPE_STAMINA] = {0.5, 0, 75, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restorestamina.dds'},
    [POWERTYPE_MOUNT_STAMINA] = {0.5, 0, 75, nil},
    [POWERTYPE_WEREWOLF] = {0.0, 0.5, 0, nil},
    [ATTRIBUTE_VISUAL_POWER_SHIELDING] = {1, 0, 0, nil},
}

function BetterUIOrbBar:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function BetterUIOrbBar:Initialize(control, powerType)
    self.control = control
    self.aura = FindControl(control, 'Aura')
    self.fog = FindControl(control, 'Fog')
    self.fog2 = FindControl(control, 'Fog2')
    self.label = FindControl(control, 'Label')
    self.currentValue = 0
    self.minValue = 0
    self.maxValue = 0
    
    local baseCoordLeft, baseCoordRight, baseAnchorX, ttIcon = unpack(ORB_CONFIG[powerType])
    self.baseCoordLeft = baseCoordLeft
    self.baseCoordRight = baseCoordRight
    self.baseAnchorX = baseAnchorX

    if self.aura ~= nil then
        self.auraAnimation = ANIMATION_MANAGER:CreateTimelineFromVirtual("BetterUIOrbsGlowAnim", self.aura)

        self.aura:SetHandler("OnMouseEnter", function(trigger)
            local hp = zo_round(self.currentValue).." / "..zo_round(self.maxValue)
            local text = zo_iconTextFormat(ttIcon, "70%", "70%", hp)
            InitializeTooltip(InformationTooltip, trigger, CENTER, 0, 25, TOP)
            SetTooltipText(InformationTooltip, text)
        end)
        self.aura:SetHandler("OnMouseExit", function()
            ClearTooltip(InformationTooltip)
        end)
    end
end

function BetterUIOrbBar:UpdateValue(value)
    self.currentValue = value
    self:RefreshVisuals()
    self:RefreshLabel()
end

function BetterUIOrbBar:GetMax()
    return self.maxValue
end

function BetterUIOrbBar:SetRange(min, max)
    self.minValue = min
    self.maxValue = max
end

function BetterUIOrbBar:RefreshLabel()
    if self.label ~= nil then
        self.label:SetText(zo_round((self.currentValue / 1000)) .. 'k')
    end
end

function BetterUIOrbBar:RefreshVisuals()
    local percent = 0
    if self.currentValue >= self.maxValue then
        percent = 100
    elseif self.maxValue ~= 0 then
        percent = zo_roundToNearest((self.currentValue / self.maxValue) * 100, 0.1)
    end

    percent = zo_max(0, percent - 3) -- Visual adjustment

    local height = (150 / 100) * percent
    local coordTop = 1 - (percent / 100)
    local anchorY = 150 - height

    if self.aura ~= nil then
        if percent < 30 then
            if not self.auraAnimation:IsPlaying() then
                self.auraAnimation:PlayFromStart()
            end
        else
            self.auraAnimation:Stop()
            self.aura:SetAlpha(0)
        end
    end

    if self.fog then
        self.fog:SetHeight(height)
        self.fog:SetTextureCoords(self.baseCoordLeft, self.baseCoordRight, coordTop, 1)
        self.fog:SetAnchor(TOPLEFT, self.control, nil, self.baseAnchorX, anchorY)
    end

    if self.fog2 ~= nil then
        self.fog2:SetHeight(height - 5)
        self.fog2:SetTextureCoords(self.baseCoordLeft, self.baseCoordRight, coordTop - 0.00000005, 1)
        self.fog2:SetAnchor(TOPLEFT, self.control, nil, self.baseAnchorX, anchorY - 5)
    end
end

-------------------------------------------------------------------------------------------------
-- FoodBuffTracker Class
-------------------------------------------------------------------------------------------------

local FoodBuffTracker = ZO_Object:Subclass()

local IGNORED_BUFFS = {
    [43752] = true, [21263] = true, [92232] = true, [64210] = true,
    [66776] = true, [77123] = true, [85501] = true, [85502] = true,
    [85503] = true, [86755] = true, [88445] = true, [89683] = true,
    [91369] = true,
}

function FoodBuffTracker:New(control)
    local obj = ZO_Object.New(self)
    obj.control = control
    return obj
end

function FoodBuffTracker:IsFood(abilityId)
    if IGNORED_BUFFS[abilityId] then return false end
    if not DoesAbilityExist(abilityId) or IsAbilityPermanent(abilityId) or GetAbilityDuration(abilityId) < 600000 then
        return false
    end
    return true
end

function FoodBuffTracker:ScanBuffs()
    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, _, _, _, _, _, _, abilityId, canClickOff = GetUnitBuffInfo("player", i)
        if canClickOff and self:IsFood(abilityId) then
            local timeLeft = timeEnding - GetFrameTimeSeconds()
            return buffName, timeLeft, (timeEnding - timeStarted)
        end
    end
    return nil, 0, 0
end

function FoodBuffTracker:Update()
    local buffName, timeLeft, duration = self:ScanBuffs()
    if not buffName then
        self.control:SetValue(0)
        self.control.ttt = nil
    else
        ZO_StatusBar_SmoothTransition(self.control, timeLeft, duration)
        self.control.ttt = string.format("%s (%s)", buffName, ZO_FormatTime(timeLeft, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR))
    end
end

-------------------------------------------------------------------------------------------------
-- Initialization Logic
-------------------------------------------------------------------------------------------------

local function SetupPowerPools(rootFrame)
    m_pools = {
        [POWERTYPE_HEALTH] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbHealth'), POWERTYPE_HEALTH),
        [POWERTYPE_MAGICKA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbMagicka'), POWERTYPE_MAGICKA),
        [POWERTYPE_STAMINA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbStamina'), POWERTYPE_STAMINA),
        [POWERTYPE_MOUNT_STAMINA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbMount'), POWERTYPE_MOUNT_STAMINA),
        [POWERTYPE_WEREWOLF] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbWerewolf'), POWERTYPE_WEREWOLF),
    }

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_POWER_UPDATE, function(_, _, _, powerType, powerValue, powerMax)
        local pool = m_pools[powerType]
        if pool ~= nil then
            ZO_StatusBar_SmoothTransition(pool, powerValue, powerMax)
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
end

local function SetupShieldBar(rootFrame)
    m_shieldBar = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbShield'), ATTRIBUTE_VISUAL_POWER_SHIELDING)

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function(_, _, unitAttributeVisual, _, _, _, value)
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
            m_shieldBar.label:GetParent():SetHidden(false)
            ZO_StatusBar_SmoothTransition(m_shieldBar, value, m_pools[POWERTYPE_HEALTH]:GetMax())
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, function(_, _, unitAttributeVisual, _, _, _, _, newValue)
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
            ZO_StatusBar_SmoothTransition(m_shieldBar, newValue, m_pools[POWERTYPE_HEALTH]:GetMax())
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(_, _, unitAttributeVisual)
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
            ZO_StatusBar_SmoothTransition(m_shieldBar, 0, m_pools[POWERTYPE_HEALTH]:GetMax())
            m_shieldBar.label:GetParent():SetHidden(true)
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, "player")
end

local function SetupStateHandlers()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MOUNTED_STATE_CHANGED, function(_, state)
        m_pools[POWERTYPE_MOUNT_STAMINA].control:SetHidden(not state)
    end)

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_WEREWOLF_STATE_CHANGED, function(_, state)
        m_pools[POWERTYPE_WEREWOLF].control:SetHidden(not state)
    end)
end

local function SetupFoodTracker(rootFrame)
    m_foodTracker = FoodBuffTracker:New(FindControl(rootFrame, 'FoodBar'))
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Food", 3000, function() 
        if m_foodTracker then m_foodTracker:Update() end 
    end)
end

local function SetupVisibilityFragments(rootFrame)
    local fragment = ZO_HUDFadeSceneFragment:New(rootFrame)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    
    local function UpdateDeathFragment()
        fragment:SetHiddenForReason("Dead", IsUnitDead("player"))
    end
    
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('BetterUIOrbs', true)
    end
    
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEAD, UpdateDeathFragment)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ALIVE, UpdateDeathFragment)
    
    return UpdateDeathFragment
end

local function RefreshAllData(rootFrame, updateDeathFragment)
    if updateDeathFragment then updateDeathFragment() end

    for powerType in pairs(m_pools) do
        local powerValue, powerMax = GetUnitPower("player", powerType)
        ZO_StatusBar_SmoothTransition(m_pools[powerType], powerValue, powerMax)
    end

    if m_shieldBar then
        m_shieldBar:SetRange(0, m_pools[POWERTYPE_HEALTH]:GetMax())
        m_shieldBar:UpdateValue(0)
    end

    if m_foodTracker then m_foodTracker:Update() end

    if m_pools[POWERTYPE_MOUNT_STAMINA] then
        m_pools[POWERTYPE_MOUNT_STAMINA].control:SetHidden(not IsMounted())
    end
end

local function Initialize(rootFrame)
    if m_isInitialized then return end
    m_isInitialized = true
    m_rootFrame = rootFrame
    
    local settings = GetModuleSettings()
    if not settings.enabled then
        rootFrame:SetHidden(true)
        return
    end

    -- Apply styles and layout
    local function ApplyStyle(layout)
        if AltAB_ActionBar ~= nil then
            ApplyActionBarSkin(rootFrame, layout, AltAB_ActionBar)
        elseif FAB_ActionBar ~= nil then
            ApplyActionBarSkin(rootFrame, layout, FAB_ActionBar)
        else
            ApplyActionBarSkin(rootFrame, layout)
        end
        UpdateFrameDimensions()
        ApplyThemeVisuals()
    end
    
    local isGamePad = IsInGamepadPreferredMode()
    local layout = isGamePad and LAYOUT_CONFIG.GAMEPAD or LAYOUT_CONFIG.KEYBOARD
    ApplyStyle(layout)

    SetupPowerPools(rootFrame)
    SetupShieldBar(rootFrame)
    SetupStateHandlers()
    SetupFoodTracker(rootFrame)
    
    local updateDeathFragment = SetupVisibilityFragments(rootFrame)

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function() 
        RefreshAllData(rootFrame, updateDeathFragment) 
    end)

    -- Platform Style Manager
    local styleManager = ZO_PlatformStyle:New(ApplyStyle, LAYOUT_CONFIG.KEYBOARD, LAYOUT_CONFIG.GAMEPAD)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ACTIVE_COMPANION_STATE_CHANGED, function() styleManager:Apply() end)
    
    rootFrame:SetHidden(false)
    RefreshAllData(rootFrame, updateDeathFragment)
end

-- Entry point called from XML
function BetterUIOrbs_Initialize(rootFrame)
    m_rootFrame = rootFrame
    rootFrame:SetHidden(true)
    
    -- Defer initialization to ensure BetterUI settings are loaded
    EVENT_MANAGER:RegisterForEvent(NAME .. "_WaitForBetterUI", EVENT_ADD_ON_LOADED, function(_, addonName)
        if addonName ~= "BetterUI" then return end
        EVENT_MANAGER:UnregisterForEvent(NAME .. "_WaitForBetterUI", EVENT_ADD_ON_LOADED)
        
        zo_callLater(function()
            if not m_isInitialized then
                Initialize(rootFrame)
            end
        end, 0)
    end)
end

-- Public API to apply settings changes
function Orbs.ApplySettings()
    local enabled = GetModuleSettings().enabled
    
    if enabled and not m_isInitialized and m_rootFrame then
        Initialize(m_rootFrame)
    elseif m_isInitialized then
        UpdateFrameDimensions()
        ApplyThemeVisuals()
    end
    
    if m_rootFrame then
        m_rootFrame:SetHidden(not enabled)
    end
    
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('BetterUIOrbs', enabled)
    end
end

-- Initialize default settings for the module
function Orbs.InitModule(m_options)
    m_options = m_options or {}
    local defaults = DEFAULTS
    if m_options.enabled == nil then m_options.enabled = defaults.enabled end
    if m_options.scale == nil then m_options.scale = defaults.scale end
    if m_options.offsetY == nil then m_options.offsetY = defaults.offsetY end
    if m_options.useCustomTextures == nil then m_options.useCustomTextures = defaults.useCustomTextures end
    if m_options.doubleBarEnabled == nil then m_options.doubleBarEnabled = defaults.doubleBarEnabled end
    return m_options
end
