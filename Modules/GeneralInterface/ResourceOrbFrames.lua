local NAME = "ResourceOrbFrames"
if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.ResourceOrbFrames == nil then BETTERUI.ResourceOrbFrames = {} end
local ResourceOrbFrames = BETTERUI.ResourceOrbFrames

-- Module State
local m_rootFrame = nil
local m_isInitialized = false
local m_pools = {}
local m_shieldBar = nil
local m_foodTracker = nil
local m_experienceBar = nil
local m_updateDeathFragment = nil

-- Default Settings
local DEFAULTS = {
    enabled = false,
    scale = 1.15,
    offsetY = 80,
    useCustomTextures = false,
    centerBarType = "XP",
    -- Cooldown text settings
    cooldownTextSize = 18,
    cooldownTextColor = {1, 1, 1, 1}, -- RGBA white
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
    if BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["ResourceOrbFrames"] then
        return BETTERUI.Settings.Modules["ResourceOrbFrames"]
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
    
    -- Always use double bar textures
    local elements = {
        BgMiddle = 'BarBackgroundMiddle_Double.dds',
        BgLeft = 'BarBackgroundLeft_Double.dds',
        BgRight = 'BarBackgroundRight_Double.dds',
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

-- Layout constants (referencing global constants from BetterUI.CONST.lua)
local LAYOUT_CONFIG = {
    GAMEPAD = {
        abilitySlotWidth = BETTERUI_RESOURCE_ORB_FRAMES_GAMEPAD_SLOT_WIDTH,
        abilitySlotOffsetX = BETTERUI_RESOURCE_ORB_FRAMES_GAMEPAD_SLOT_SPACING,
        dualBarOffsetX = BETTERUI_RESOURCE_ORB_FRAMES_GAMEPAD_DUAL_BAR_OFFSET,
    },
    KEYBOARD = {
        abilitySlotWidth = BETTERUI_RESOURCE_ORB_FRAMES_KEYBOARD_SLOT_WIDTH,
        abilitySlotOffsetX = BETTERUI_RESOURCE_ORB_FRAMES_KEYBOARD_SLOT_SPACING,
        dualBarOffsetX = BETTERUI_RESOURCE_ORB_FRAMES_KEYBOARD_DUAL_BAR_OFFSET,
    }
}



local function UpdateBackBar(rootFrame)
    local activePair = GetActiveWeaponPairInfo()
    local backBarCategory = (activePair == ACTIVE_WEAPON_PAIR_MAIN) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    -- Slots 3-7 are skills, 8 is Ultimate
    local slots = {3, 4, 5, 6, 7, 8}
    
    for i, slotIndex in ipairs(slots) do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            local iconControl = FindControl(btn, 'Icon')
            local icon = GetSlotTexture(slotIndex, backBarCategory)
            
            if iconControl then
                if icon and icon ~= '' then
                    iconControl:SetTexture(icon)
                    iconControl:SetHidden(false)
                else
                    iconControl:SetHidden(true)
                end
            end
        end
    end
    
    backBarContainer:SetHidden(false)
end

local function UpdateBackBarCooldowns(rootFrame)
    local activePair = GetActiveWeaponPairInfo()
    local backBarCategory = (activePair == ACTIVE_WEAPON_PAIR_MAIN) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    -- Get settings for cooldown text
    local settings = GetModuleSettings()
    local textSize = settings.cooldownTextSize or DEFAULTS.cooldownTextSize
    local textColor = settings.cooldownTextColor or DEFAULTS.cooldownTextColor
    
    -- Slots 3-7 are skills, 8 is Ultimate
    local slots = {3, 4, 5, 6, 7, 8}
    
    for i, slotIndex in ipairs(slots) do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            -- Dynamically create Cooldown control if it doesn't exist
            if not btn.cooldownControl then
                btn.cooldownControl = WINDOW_MANAGER:CreateControl(btn:GetName() .. "CooldownControl", btn, CT_COOLDOWN)
                btn.cooldownControl:SetAnchor(TOPLEFT, btn, TOPLEFT, 1, 1)
                btn.cooldownControl:SetAnchor(BOTTOMRIGHT, btn, BOTTOMRIGHT, -1, -1)
                btn.cooldownControl:SetFillColor(0, 0, 0, 0.7)
                btn.cooldownControl:SetHidden(true)
                
                btn.cooldownEdge = WINDOW_MANAGER:CreateControl(btn:GetName() .. "CooldownEdge", btn, CT_TEXTURE)
                btn.cooldownEdge:SetTexture("esoui/art/actionbar/actionslot_cooldown_edge.dds")
                btn.cooldownEdge:SetBlendMode(TEX_BLEND_MODE_ADD)
                btn.cooldownEdge:SetAnchor(TOPLEFT, btn, TOPLEFT, 0, 0)
                btn.cooldownEdge:SetAnchor(BOTTOMRIGHT, btn, BOTTOMRIGHT, 0, 0)
                btn.cooldownEdge:SetHidden(true)
            end

            local cooldownControl = btn.cooldownControl
            local cooldownEdge = btn.cooldownEdge
            local cooldownText = FindControl(btn, 'CooldownText')
            
            -- Get the ability ID for this slot on the back bar
            local abilityId = GetSlotBoundId(slotIndex, backBarCategory)
            local remaining = 0
            local showCooldown = false
            local remainingMs, durationMs = 0, 0
            
            if abilityId and abilityId > 0 then
                -- Get cooldown from the back bar slot
                local remMs, durMs, isGlobal = GetSlotCooldownInfo(slotIndex, backBarCategory)
                
                -- Only show if it's not just the global cooldown (weapon swap ~1s)
                if remMs and remMs > 0 and durMs and durMs > 1500 then
                    remaining = remMs / 1000
                    remainingMs = remMs
                    durationMs = durMs
                    showCooldown = true
                end
                
                -- Also check for ability effect duration (buff remaining time)
                if not showCooldown then
                    local effectRemaining = GetActionSlotEffectTimeRemaining(slotIndex, backBarCategory)
                    if effectRemaining and effectRemaining > 0 then
                        remaining = effectRemaining / 1000
                        remainingMs = effectRemaining
                        durationMs = effectRemaining -- Approximate duration
                        showCooldown = true
                    end
                end
            end
            
            if cooldownControl and cooldownText then
                if showCooldown and remaining > 0.1 then
                    cooldownControl:SetHidden(false)
                    -- Use StartCooldown for the radial wipe effect
                    cooldownControl:StartCooldown(remainingMs, durationMs, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
                    
                    cooldownText:SetHidden(false)
                    
                    -- Apply text settings
                    cooldownText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", textSize))
                    cooldownText:SetColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1)
                    
                    if remaining >= 10 then
                        cooldownText:SetText(string.format("%.0f", remaining))
                    else
                        cooldownText:SetText(string.format("%.1f", remaining))
                    end
                    
                    if cooldownEdge then cooldownEdge:SetHidden(false) end
                else
                    cooldownControl:SetHidden(true)
                    cooldownControl:ResetCooldown()
                    cooldownText:SetHidden(true)
                    if cooldownEdge then cooldownEdge:SetHidden(true) end
                end
            end
        end
    end
end

local function UpdateFrontBarCooldownColors()
    local settings = GetModuleSettings()
    local textColor = settings.cooldownTextColor or DEFAULTS.cooldownTextColor
    
    for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
        local btn = ZO_ActionBar_GetButton(i)
        if btn and btn.slot then
            -- The native cooldown timer label is usually named "<ButtonName>CooldownTime"
            local timer = btn.slot:GetNamedChild("CooldownTime")
            if timer then
                timer:SetColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1)
            end
        end
    end
    
    -- Also update Companion Ultimate if present
    local companionButton = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION)
    if companionButton and companionButton.slot then
        local timer = companionButton.slot:GetNamedChild("CooldownTime")
        if timer then
            timer:SetColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1)
        end
    end
end

local function UpdateBackBarLayout(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    local isGamePad = IsInGamepadPreferredMode()
    local layout = isGamePad and LAYOUT_CONFIG.GAMEPAD or LAYOUT_CONFIG.KEYBOARD
    
    local width = layout.abilitySlotWidth
    local offset = layout.abilitySlotOffsetX
    
    -- Calculate total width: 6 buttons + 4 offsets + extra gap for Ultimate
    local ultimateGap = BETTERUI_RESOURCE_ORB_FRAMES_ULTIMATE_GAP
    local totalWidth = (6 * width) + (4 * offset) + ultimateGap
    local halfWidth = totalWidth / 2
    
    backBarContainer:SetDimensions(totalWidth, width)
    
    for i = 1, 6 do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            btn:SetDimensions(width, width)
            btn:ClearAnchors()
            if i == 1 then
                -- First button: anchor to CENTER of container, offset left by half width
                btn:SetAnchor(LEFT, backBarContainer, CENTER, -halfWidth, 0)
            elseif i == 6 then
                -- Ultimate Button (Button6)
                local prevBtn = FindControl(backBarContainer, 'Button' .. (i-1))
                btn:SetAnchor(LEFT, prevBtn, RIGHT, ultimateGap, 0)
            else
                local prevBtn = FindControl(backBarContainer, 'Button' .. (i-1))
                btn:SetAnchor(LEFT, prevBtn, RIGHT, offset, 0)
            end
        end
    end
end

local function UpdateMainBarLayout(rootFrame)
    local isGamePad = IsInGamepadPreferredMode()
    local layout = isGamePad and LAYOUT_CONFIG.GAMEPAD or LAYOUT_CONFIG.KEYBOARD
    
    local width = layout.abilitySlotWidth
    local offset = layout.abilitySlotOffsetX
    
    -- Calculate total width of native action bar (5 skills + ultimate)
    local totalWidth = (6 * width) + (5 * offset)
    
    -- Get the BetterUI ActionBarContainer (for positioning reference)
    local barParent = FindControl(rootFrame, 'ActionBarContainer')
    if not barParent then return end
    
    barParent:SetDimensions(totalWidth, width)
    
    -- Position the native ESO action bar (ZO_ActionBar1) relative to our container
    -- We don't manipulate individual buttons - ESO manages those
    -- Instead we position the whole bar
    local nativeBar = ZO_ActionBar1
    if nativeBar then
        nativeBar:ClearAnchors()
        -- Position nativeBar centered on our ActionBarContainer, shifted left
        -- This makes bottom bar's leftmost skill overlap with top bar
        local shiftLeft = -(width * BETTERUI_RESOURCE_ORB_FRAMES_MAIN_BAR_SHIFT_LEFT_FACTOR)
        nativeBar:SetAnchor(CENTER, barParent, CENTER, shiftLeft, 0)
    end
    
    -- Hide weapon swap control - we don't need it for dual bar
    if ZO_ActionBar1WeaponSwap then
        ZO_ActionBar1WeaponSwap:SetHidden(true)
    end
    
    -- Position quickslot to the left of the bar
    local quickSlotButton = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if quickSlotButton and quickSlotButton.slot then
        quickSlotButton.slot:SetHidden(false)
        quickSlotButton.slot:ClearAnchors()
        -- Anchor to the left of the ActionBarContainer
        quickSlotButton.slot:SetAnchor(RIGHT, barParent, LEFT, -10, 0)
    end
end

local function UpdateBarPositions(rootFrame)
    local actionBarContainer = FindControl(rootFrame, 'ActionBarContainer')
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    local indicator = FindControl(rootFrame, 'ActiveBarIndicator')
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    
    if not actionBarContainer or not backBarContainer or not bgMiddle then return end
    
    local isGamePad = IsInGamepadPreferredMode()
    
    -- Use global constants for positioning (from BetterUI.CONST.lua)
    local shiftY = BETTERUI_RESOURCE_ORB_FRAMES_BAR_SHIFT_Y
    local bottomY = (isGamePad and BETTERUI_RESOURCE_ORB_FRAMES_GAMEPAD_BOTTOM_BAR_Y or BETTERUI_RESOURCE_ORB_FRAMES_KEYBOARD_BOTTOM_BAR_Y) + shiftY
    local topY = (isGamePad and BETTERUI_RESOURCE_ORB_FRAMES_GAMEPAD_TOP_BAR_Y or BETTERUI_RESOURCE_ORB_FRAMES_KEYBOARD_TOP_BAR_Y) + shiftY
    
    actionBarContainer:ClearAnchors()
    backBarContainer:ClearAnchors()
    
    -- Active bar (ActionBarContainer) is ALWAYS on bottom
    -- Inactive bar (BackBarContainer) is ALWAYS on top
    actionBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, 0, bottomY)
    backBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, 0, topY)
    
    if indicator then
        indicator:ClearAnchors()
        indicator:SetAnchor(RIGHT, actionBarContainer, LEFT, BETTERUI_RESOURCE_ORB_FRAMES_INDICATOR_OFFSET_X, 0)
    end
end

local function SetupNativeBackBar(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    UpdateBackBar(rootFrame)
    UpdateBackBarLayout(rootFrame)
    UpdateMainBarLayout(rootFrame)
    UpdateBarPositions(rootFrame)
    
    -- Register event handlers
    EVENT_MANAGER:RegisterForEvent(NAME .. "BackBar", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function() 
        UpdateBackBar(rootFrame) 
        UpdateBarPositions(rootFrame)
        UpdateMainBarLayout(rootFrame)
    end)
    EVENT_MANAGER:RegisterForEvent(NAME .. "BackBarSlots", EVENT_ACTION_SLOTS_FULL_UPDATE, function() 
        UpdateBackBar(rootFrame)
        UpdateMainBarLayout(rootFrame)
    end)
    EVENT_MANAGER:RegisterForEvent(NAME .. "BackBarSlot", EVENT_ACTION_SLOT_UPDATED, function() UpdateBackBar(rootFrame) end)
    
    -- Update cooldowns periodically
    local function CooldownTick()
        UpdateBackBarCooldowns(rootFrame)
    end
    EVENT_MANAGER:RegisterForUpdate(NAME .. "BackBarCooldown", 100, CooldownTick)
end

-- Skin the main action bar
local function ApplyActionBarSkin(rootFrame, layout)
    local isGamePad = IsInGamepadPreferredMode()
    -- Always use double bar template
    local template = isGamePad and 'ResourceOrbFrames_Double_Gamepad' or 'ResourceOrbFrames_Double_Keyboard'

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

    ApplyTemplateToControl(rootFrame, template)

    -- Native Double Bar Implementation
    -- SetupNativeBackBar handles all positioning via UpdateMainBarLayout and UpdateBarPositions
    SetupNativeBackBar(rootFrame)
    
    -- Hide indicator (replaced by quickslot)
    local indicator = FindControl(rootFrame, 'ActiveBarIndicator')
    if indicator then indicator:SetHidden(true) end
    
    UpdateFrontBarCooldownColors()
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
        self.auraAnimation = ANIMATION_MANAGER:CreateTimelineFromVirtual("ResourceOrbFramesGlowAnim", self.aura)

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

function BetterUIOrbBar:SetValue(value)
    self:UpdateValue(value)
end

function BetterUIOrbBar:SetMinMax(min, max)
    self:SetRange(min, max)
end

function BetterUIOrbBar:GetValue()
    return self.currentValue
end

function BetterUIOrbBar:GetMinMax()
    return self.minValue, self.maxValue
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
-- ExperienceBar Class
-------------------------------------------------------------------------------------------------

local ExperienceBar = ZO_Object:Subclass()

function ExperienceBar:New(control)
    local obj = ZO_Object.New(self)
    obj.control = control
    return obj
end

function ExperienceBar:Update()
    if not self.control then return end
    
    local isChampion = IsUnitChampion("player")
    local current, max, effectiveMax = 0, 0, 0
    local tooltipText = ""

    current = GetUnitXP("player")
    max = GetUnitXPMax("player")
    effectiveMax = max

    if isChampion then
        tooltipText = string.format("CP: %d / %d", current, max)
    else
        tooltipText = string.format("XP: %d / %d", current, max)
    end

    if effectiveMax > 0 then
        ZO_StatusBar_SmoothTransition(self.control, current, effectiveMax)
    else
        self.control:SetValue(0)
    end
    
    self.control.ttt = tooltipText
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
end

local function SetupExperienceBar(rootFrame)
    local bar = FindControl(rootFrame, 'FoodBar')
    if bar then
        -- Set texture so bar is visible
        bar:SetTexture("BetterUI/Modules/GeneralInterface/OrbTextures/OrbFill.dds")
        bar:SetColor(0.73, 0.3, 0.04, 1) -- Orange/amber color for XP bar
    end
    m_experienceBar = ExperienceBar:New(bar)
end

local function SetupVisibilityFragments(rootFrame)
    local fragment = ZO_HUDFadeSceneFragment:New(rootFrame)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    
    local function UpdateDeathFragment()
        fragment:SetHiddenForReason("Dead", IsUnitDead("player"))
    end
    
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
    end
    
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEAD, UpdateDeathFragment)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ALIVE, UpdateDeathFragment)
    
    m_updateDeathFragment = UpdateDeathFragment
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

    local settings = GetModuleSettings()
    local centerBarType = settings.centerBarType or "XP"

    if centerBarType == "Food" and m_foodTracker then
        m_foodTracker:Update()
    elseif centerBarType == "XP" and m_experienceBar then
        m_experienceBar:Update()
    elseif centerBarType == "None" then
         local bar = FindControl(rootFrame, 'FoodBar')
         if bar then bar:SetHidden(true) end
    end

end

local function SetupModule(control)
    m_isInitialized = true
    
    SetupPowerPools(control)
    SetupShieldBar(control)
    SetupStateHandlers()
    SetupFoodTracker(control)
    SetupExperienceBar(control)
    
    local updateDeathFragment = SetupVisibilityFragments(control)
    
    -- Determine layout
    local isGamePad = IsInGamepadPreferredMode()
    local layout = isGamePad and LAYOUT_CONFIG.GAMEPAD or LAYOUT_CONFIG.KEYBOARD

    ApplyActionBarSkin(control, layout)
    UpdateFrontBarCooldownColors()
    
    -- Initial Refresh
    RefreshAllData(control, updateDeathFragment)
    

    
    -- Register for OnGamepadPreferredModeChanged
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        ReloadUI() -- Reload UI to switch templates cleanly
    end)
end

function ResourceOrbFrames.ApplySettings()
    local settings = GetModuleSettings()
    if not m_rootFrame then return end

    if settings.enabled then
        if not m_isInitialized then
             SetupModule(m_rootFrame)
        end
        m_rootFrame:SetHidden(false)
        if m_updateDeathFragment then m_updateDeathFragment() end
        UpdateFrameDimensions()
        ApplyThemeVisuals()
        RefreshAllData(m_rootFrame)
        
        -- Hide default bars
        if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
            PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
        end
    else
        m_rootFrame:SetHidden(true)
        -- Show default bars
        if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
            PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', false)
        end
    end
end

function ResourceOrbFrames_Initialize(control)
    m_rootFrame = control
    
    -- Register for generic updates to ensure settings are applied when player is activated (and settings are loaded)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function() 
        ResourceOrbFrames.ApplySettings()
    end)
    
    ResourceOrbFrames.ApplySettings()
end
