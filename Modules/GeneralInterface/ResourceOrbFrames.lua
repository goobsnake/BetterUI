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
    -- Fine-tune resource orb fills (magicka/stamina)
    -- developer-only
}

-------------------------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------------------------

-- Helper to find controls by name, handling both direct children and global names
local function FindControl(parent, name)
    -- First try to grab a direct child with the given short name
    local child = parent:GetNamedChild(name)
    if child then return child end

    -- Try global by several possible name prefixes. We iterate up the parent chain
    -- and check for a global control name formed by concatenating that ancestor's
    -- name + name. This accommodates XML controls that use $(parent), $(grandparent)
    -- or similar variable substitution to provide a name that doesn't match the
    -- direct child name.
    local probe = parent
    local guards = 0
    while probe ~= nil and guards < 6 do
        local globalName = probe:GetName() .. name
        local ctrl = _G[globalName]
        if ctrl ~= nil then return ctrl end
        -- Move to the next ancestor. If GetParent is not available, bail out.
        if probe.GetParent then
            probe = probe:GetParent()
        else
            probe = nil
        end
        guards = guards + 1
    end

    -- Fall back to direct global name (name without prefix)
    if _G[name] then return _G[name] end
    return nil
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

-- Force Update Layout from Constants (orbs, ornaments positioning)
local function UpdateOrbLayout()
    local leftOrb = FindControl(m_rootFrame, 'OrbHealth')
    local rightOrb = FindControl(m_rootFrame, 'OrbResource')
    local leftOrnament = FindControl(m_rootFrame, 'OrnamentLeft')
    local rightOrnament = FindControl(m_rootFrame, 'OrnamentRight')
    local bgMiddle = FindControl(m_rootFrame, 'BgMiddle')
    
    if not bgMiddle then return end

    -- Get dimension constants (separate for left/right orbs)
    local leftBorderSize = BETTERUI_ORB_BORDER_LEFT_SIZE or 175
    local rightBorderSize = BETTERUI_ORB_BORDER_RIGHT_SIZE or 175
    local auraSize = BETTERUI_ORB_AURA_SIZE or 350
    
    -- Ornament scale multipliers
    local leftOrnamentScale = BETTERUI_ORNAMENT_LEFT_SCALE or 1.0
    local rightOrnamentScale = BETTERUI_ORNAMENT_RIGHT_SCALE or 1.0
    
    -- Fill scale factor (fill size = border size * scale)
    -- Independent width/height scales for health, magicka and stamina fills (developer-only)
    -- Use explicit width/height scale constants
    local leftFillWidthScale = BETTERUI_ORB_FILL_HEALTH_SCALE_WIDTH or 0.55
    local leftFillHeightScale = BETTERUI_ORB_FILL_HEALTH_SCALE_HEIGHT or 0.55
    local magickaFillWidthScale = BETTERUI_ORB_FILL_MAGICKA_SCALE_WIDTH or 0.5
    local magickaFillHeightScale = BETTERUI_ORB_FILL_MAGICKA_SCALE_HEIGHT or 0.5
    local staminaFillWidthScale = BETTERUI_ORB_FILL_STAMINA_SCALE_WIDTH or 0.5
    local staminaFillHeightScale = BETTERUI_ORB_FILL_STAMINA_SCALE_HEIGHT or 0.5
    local resourceFillWidthScale = BETTERUI_ORB_FILL_RESOURCE_SCALE_WIDTH or 0.5
    local resourceFillHeightScale = BETTERUI_ORB_FILL_RESOURCE_SCALE_HEIGHT or 0.5
    
    -- Health fill constants (left orb): compute width & height separately
    local healthFillWidth = math.min(math.floor(leftBorderSize * leftFillWidthScale + 0.5), leftBorderSize)
    local healthFillHeight = math.min(math.floor(leftBorderSize * leftFillHeightScale + 0.5), leftBorderSize)
    local healthFillOffsetX = BETTERUI_ORB_FILL_HEALTH_OFFSET_X or 0
    local healthFillOffsetY = BETTERUI_ORB_FILL_HEALTH_OFFSET_Y or 0
    
    -- Resource fill constants (right orb), computed per half for magicka and stamina with width & height
    local magickaFillWidth = math.min(math.floor(rightBorderSize * magickaFillWidthScale + 0.5), rightBorderSize)
    local magickaFillHeight = math.min(math.floor(rightBorderSize * magickaFillHeightScale + 0.5), rightBorderSize)
    local staminaFillWidth = math.min(math.floor(rightBorderSize * staminaFillWidthScale + 0.5), rightBorderSize)
    local staminaFillHeight = math.min(math.floor(rightBorderSize * staminaFillHeightScale + 0.5), rightBorderSize)
    local resourceFillWidth = math.min(math.floor(rightBorderSize * resourceFillWidthScale + 0.5), rightBorderSize)
    local resourceFillHeight = math.min(math.floor(rightBorderSize * resourceFillHeightScale + 0.5), rightBorderSize)
    -- Read offsets from constants only (developer-facing only, not exposed in settings)
    local magickaFillOffsetX = BETTERUI_ORB_FILL_MAGICKA_OFFSET_X or BETTERUI_ORB_FILL_RESOURCE_OFFSET_X or 0
    local magickaFillOffsetY = BETTERUI_ORB_FILL_MAGICKA_OFFSET_Y or BETTERUI_ORB_FILL_RESOURCE_OFFSET_Y or 0
    local staminaFillOffsetX = BETTERUI_ORB_FILL_STAMINA_OFFSET_X or BETTERUI_ORB_FILL_RESOURCE_OFFSET_X or 0
    local staminaFillOffsetY = BETTERUI_ORB_FILL_STAMINA_OFFSET_Y or BETTERUI_ORB_FILL_RESOURCE_OFFSET_Y or 0
    
    -- Splitter (divider line) constants (magicka/stamina separator)
    local splitterWidth = BETTERUI_ORB_SPLITTER_WIDTH or 16
    local splitterHeightScale = BETTERUI_ORB_SPLITTER_HEIGHT_SCALE or 1.0
    -- note: overall multiplier 'splitterScale' removed; width is in px, height is derived from border size
    local splitterHeight = rightBorderSize * splitterHeightScale
    local splitterOffsetX = BETTERUI_ORB_SPLITTER_OFFSET_X or 0
    local splitterOffsetY = BETTERUI_ORB_SPLITTER_OFFSET_Y or 0
    
    -- ========================================
    -- ORNAMENTS: Position relative to BgMiddle (center of skill bars)
    -- ========================================
    if leftOrnament then
        local leftSize = (BETTERUI_ORNAMENT_LEFT_SIZE or 465) * leftOrnamentScale
        leftOrnament:ClearAnchors()
        leftOrnament:SetDimensions(leftSize, leftSize)
        leftOrnament:SetAnchor(CENTER, bgMiddle, CENTER, BETTERUI_ORNAMENT_LEFT_OFFSET_X, BETTERUI_ORNAMENT_LEFT_OFFSET_Y)
    end
    
    if rightOrnament then
        local rightSize = (BETTERUI_ORNAMENT_RIGHT_SIZE or 480) * rightOrnamentScale
        rightOrnament:ClearAnchors()
        rightOrnament:SetDimensions(rightSize, rightSize)
        rightOrnament:SetAnchor(CENTER, bgMiddle, CENTER, BETTERUI_ORNAMENT_RIGHT_OFFSET_X, BETTERUI_ORNAMENT_RIGHT_OFFSET_Y)
    end
    
    -- ========================================
    -- ORBS: Position relative to their Ornaments
    -- ========================================
    if leftOrb and leftOrnament then
        leftOrb:ClearAnchors()
        leftOrb:SetDimensions(leftBorderSize, leftBorderSize)
        leftOrb:SetAnchor(CENTER, leftOrnament, CENTER, BETTERUI_ORB_LEFT_OFFSET_X, BETTERUI_ORB_LEFT_OFFSET_Y)
    end
    
    if rightOrb and rightOrnament then
        rightOrb:ClearAnchors()
        rightOrb:SetDimensions(rightBorderSize, rightBorderSize)
        rightOrb:SetAnchor(CENTER, rightOrnament, CENTER, BETTERUI_ORB_RIGHT_OFFSET_X, BETTERUI_ORB_RIGHT_OFFSET_Y)
    end
    
    -- ========================================
    -- HEALTH ORB FILL (Left - Red)
    -- ========================================
    local healthOrb = FindControl(m_rootFrame, 'OrbHealth')
    if healthOrb then
        -- Show and resize Fog textures (health fill)
        local fogElements = {'Fog', 'Fog2'}
        for _, name in ipairs(fogElements) do
            local ctrl = FindControl(healthOrb, name)
                    if ctrl then 
                ctrl:ClearAnchors()
                ctrl:SetHidden(false)
                ctrl:SetAlpha(1)
                ctrl:SetDimensions(healthFillWidth, healthFillHeight)
                ctrl:SetAnchor(CENTER, healthOrb, CENTER, healthFillOffsetX, healthFillOffsetY)
            end
        end
        if BETTERUI_ORB_DEBUG_PRINTS then
            d(string.format("BetterUI: UpdateOrbLayout Health: border=%d fullW=%d fullH=%d offsetX=%d offsetY=%d", leftBorderSize, healthFillWidth, healthFillHeight, healthFillOffsetX, healthFillOffsetY))
        end
        
        -- Hide BorderShade
        local borderShade = FindControl(healthOrb, 'BorderShade')
        if borderShade then borderShade:SetHidden(true) end
        
        -- Resize and show Border
        local border = FindControl(healthOrb, 'Border')
        if border then 
            border:SetHidden(false)
            border:SetDimensions(leftBorderSize, leftBorderSize) 
        end
        
        -- Resize Aura
        local aura = FindControl(healthOrb, 'Aura')
        if aura then aura:SetDimensions(auraSize, auraSize) end
    end
    
    -- ========================================
    -- RESOURCE ORB FILL (Right - Blue/Green for Magicka/Stamina)
    -- ========================================
    local subContainers = {'OrbMagicka', 'OrbStamina', 'OrbWerewolf', 'OrbMount'}
    local resourceOrb = FindControl(m_rootFrame, 'OrbResource')
    
    if resourceOrb then
        for _, containerName in ipairs(subContainers) do
            local container = FindControl(resourceOrb, containerName)
            if container then
                -- Show and resize Fog textures (resource fill)
                local fogElements = {'Fog', 'Fog2', 'Fog3'}
                            -- For Magicka/Stamina we want to use full square fills and offset them to the left/right halves
                local magickaRoundedW = math.floor(magickaFillWidth + 0.5)
                local magickaRoundedH = math.floor(magickaFillHeight + 0.5)
                local staminaRoundedW = math.floor(staminaFillWidth + 0.5)
                local staminaRoundedH = math.floor(staminaFillHeight + 0.5)
                -- For compatibility we compute half widths for auras per-half
                local magickaHalfWidth = math.floor(math.min(magickaFillWidth * 0.5, rightBorderSize * 0.5) + 0.5)
                local staminaHalfWidth = math.floor(math.min(staminaFillWidth * 0.5, rightBorderSize * 0.5) + 0.5)
                -- Compute TOPLEFT anchors for placing a full-size square over the left and right halves
                local leftFogAnchorX = math.floor((rightBorderSize / 4) - (magickaRoundedW / 2) + magickaFillOffsetX)
                local rightFogAnchorX = math.floor((3 * rightBorderSize / 4) - (staminaRoundedW / 2) + staminaFillOffsetX)
                if BETTERUI_ORB_DEBUG_PRINTS then
                    d(string.format("BetterUI: UpdateOrbLayout ResourceFill: magickaW=%d magickaH=%d staminaW=%d staminaH=%d magHalf=%d staminaHalf=%d leftAnchor=%d rightAnchor=%d magOffsetX=%d staOffsetX=%d borderSize=%d",
                        magickaRoundedW, magickaRoundedH, staminaRoundedW, staminaRoundedH, magickaHalfWidth, staminaHalfWidth, leftFogAnchorX, rightFogAnchorX, magickaFillOffsetX, staminaFillOffsetX, rightBorderSize))
                end
                -- compute vertical center offsets for per-half fills
                local magickaCenterOffsetY = math.floor((rightBorderSize - magickaFillHeight) / 2)
                local staminaCenterOffsetY = math.floor((rightBorderSize - staminaFillHeight) / 2)
                for _, name in ipairs(fogElements) do
                    local ctrl = FindControl(container, name)
                        if ctrl then 
                        ctrl:ClearAnchors()
                        ctrl:SetHidden(false)
                        ctrl:SetAlpha(1)
                            if containerName == 'OrbMagicka' then
                            -- Left half of the resource orb (Magicka): use a full square, anchored to the left half
                            ctrl:SetDimensions(magickaRoundedW, magickaRoundedH)
                            ctrl:SetAnchor(TOPLEFT, container, TOPLEFT, leftFogAnchorX, magickaCenterOffsetY + magickaFillOffsetY)
                        elseif containerName == 'OrbStamina' then
                            -- Right half of the resource orb (Stamina): use a full square, anchored to the right half
                            ctrl:SetDimensions(staminaRoundedW, staminaRoundedH)
                            ctrl:SetAnchor(TOPLEFT, container, TOPLEFT, rightFogAnchorX, staminaCenterOffsetY + staminaFillOffsetY)
                        else
                            -- Fallback: center-aligned full-size square for other types
                            ctrl:SetDimensions(math.floor(resourceFillWidth + 0.5), math.floor(resourceFillHeight + 0.5))
                            -- Use generic resource offsets
                            ctrl:SetAnchor(CENTER, container, CENTER, BETTERUI_ORB_FILL_RESOURCE_OFFSET_X or 0, BETTERUI_ORB_FILL_RESOURCE_OFFSET_Y or 0)
                        end
                        -- If this is the background layer (Fog2), ensure it's shown at full texture coords
                        if name == 'Fog2' then
                            -- Use the same horizontal texture coords as the foreground fog so Fog2 visually matches the same segment
                            if containerName == 'OrbMagicka' then
                                local baseLeft, baseRight = unpack(ORB_CONFIG[POWERTYPE_MAGICKA])
                                ctrl:SetTextureCoords(baseLeft, baseRight, 0, 1)
                            elseif containerName == 'OrbStamina' then
                                local baseLeft, baseRight = unpack(ORB_CONFIG[POWERTYPE_STAMINA])
                                ctrl:SetTextureCoords(baseLeft, baseRight, 0, 1)
                            else
                                -- Fallback: full texture coords
                                ctrl:SetTextureCoords(0, 1, 0, 1)
                            end
                        end
                    end
                end
                
                -- Hide BorderShade
                local borderShade = FindControl(container, 'BorderShade')
                if borderShade then borderShade:SetHidden(true) end
                
                -- Resize and show Border
                local border = FindControl(container, 'Border')
                if border then 
                    border:SetHidden(false)
                    border:SetDimensions(rightBorderSize, rightBorderSize) 
                end
                
                -- Resize and position Divide (magicka/stamina separator - OrbSplitter.dds)
                local divide = FindControl(container, 'Divide')
                if divide then 
                    divide:ClearAnchors()
                    -- Ensure integer pixel dimensions
                    local w = math.floor(splitterWidth + 0.5)
                    local h = math.floor(splitterHeight + 0.5)
                    divide:SetDimensions(w, h)
                    divide:SetAnchor(CENTER, container, CENTER, splitterOffsetX, splitterOffsetY)
                    -- Make sure the texture is visible and fully opaque
                    divide:SetHidden(false)
                    divide:SetAlpha(1)
                    -- Ensure the border draws in front of the divide: use border draw level as divide + 1
                    if border and border.SetDrawLevel and divide.GetDrawLevel then
                        local divLevel = divide:GetDrawLevel() or 0
                        border:SetDrawLevel(divLevel + 1)
                    end
                end
                
                -- Resize Aura (magicka/stamina halves need half-width auras)
                local aura = FindControl(container, 'Aura')
                    if aura then 
                    aura:ClearAnchors()
                    if containerName == 'OrbMagicka' or containerName == 'OrbStamina' then
                        local auraHalfWidth = (containerName == 'OrbMagicka') and magickaHalfWidth or (containerName == 'OrbStamina' and staminaHalfWidth or math.floor(math.min(resourceFillWidth * 0.5, rightBorderSize * 0.5) + 0.5))
                        aura:SetDimensions(auraHalfWidth, math.floor(auraSize + 0.5))
                        -- Place aura in the center of that half
                        local xOffset = (containerName == 'OrbMagicka') and -math.floor(auraHalfWidth/2 + 0.5) or math.floor(auraHalfWidth/2 + 0.5)
                        -- Apply the section-specific offsets to the aura so it follows the fill
                        if containerName == 'OrbMagicka' then
                            aura:SetAnchor(CENTER, container, CENTER, xOffset + magickaFillOffsetX, magickaFillOffsetY)
                        else
                            aura:SetAnchor(CENTER, container, CENTER, xOffset + staminaFillOffsetX, staminaFillOffsetY)
                        end
                    else
                        aura:SetDimensions(math.floor(auraSize + 0.5), math.floor(auraSize + 0.5))
                        aura:SetAnchor(CENTER, container, CENTER, 0, 0)
                    end
                end
            end
        end
                if BETTERUI_ORB_DEBUG_PRINTS then
                    d(string.format("BetterUI: UpdateOrbLayout Resource border=%d magW=%d magH=%d staW=%d staH=%d magHalf=%d staHalf=%d magX=%d magY=%d staX=%d staY=%d splitterW=%d splitterH=%.2f", rightBorderSize, magickaFillWidth, magickaFillHeight, staminaFillWidth, staminaFillHeight, magickaHalfWidth, staminaHalfWidth, magickaFillOffsetX, magickaFillOffsetY, staminaFillOffsetX, staminaFillOffsetY, splitterWidth, splitterHeight))
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
        quickSlotButton.slot:SetAnchor(RIGHT, barParent, LEFT, BETTERUI_RESOURCE_ORB_FRAMES_QUICKSLOT_OFFSET_X, 0)
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
    
    -- Horizontal offsets for bar alignment
    local bottomX = BETTERUI_RESOURCE_ORB_FRAMES_BOTTOM_BAR_OFFSET_X or 0
    local topX = BETTERUI_RESOURCE_ORB_FRAMES_TOP_BAR_OFFSET_X or 0
    
    actionBarContainer:ClearAnchors()
    backBarContainer:ClearAnchors()
    
    -- Bottom bar (main/active bar)
    actionBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, bottomX, bottomY)
    
    -- Top bar (back/inactive bar)
    backBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, topX, topY)
    
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
    self.powerType = powerType
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

-- Mirror Fog to Fog2 helper: ensures background fog2 layer matches the foreground fog layer
function BetterUIOrbBar:MirrorFogToFog2(fullWidth, fullHeight, fogAnchorX, centerOffsetY, fillOffsetY)
    if not self.fog or not self.fog2 then return end
    -- Fog2 should mirror the static, full-size visuals of Fog (background), not the dynamic fill height.
    -- Set Fog2 to full fill width/height and full texture coords (no cropping/partial fill)
    local staticFillWidth = fullWidth or (self.fillWidth or 150)
    local staticFillHeight = fullHeight or (self.fillHeight or 150)
    self.fog2:SetDimensions(staticFillWidth, staticFillHeight)
    -- Full vertical height for background
    self.fog2:SetHeight(staticFillHeight)
    -- Use full vertical texture coords (top=0, bottom=1) so Fog2 is always fully visible
    self.fog2:SetTextureCoords(self.baseCoordLeft, self.baseCoordRight, 0, 1)

    -- Compute a static anchor X for fog2 using the same centering logic as Fog, but NOT including dynamic anchorY.
    -- This will keep fog2 anchored to the same spot visually regardless of fill percent.
    local controlWidth = self.control:GetWidth()
    local isHalfTexture = math.abs(self.baseCoordRight - self.baseCoordLeft - 0.5) < 0.001
    local fillOffsetX = self.fillOffsetX or 0
    local function computeHalfAnchorX(isLeft)
        if isLeft then
            return math.floor((controlWidth / 4) - (staticFillWidth / 2) + fillOffsetX)
        else
            return math.floor((3 * controlWidth / 4) - (staticFillWidth / 2) + fillOffsetX)
        end
    end

    local fog2AnchorX
    if isHalfTexture then
        local isLeft = (self.baseCoordLeft < self.baseCoordRight)
        fog2AnchorX = computeHalfAnchorX(isLeft)
    else
        local centerOffsetX = (controlWidth - staticFillWidth) / 2
        fog2AnchorX = math.floor(centerOffsetX + (self.baseAnchorX or 0) + fillOffsetX)
    end

    self.fog2:ClearAnchors()
    self.fog2:SetAnchor(TOPLEFT, self.control, TOPLEFT, fog2AnchorX, centerOffsetY + (fillOffsetY or 0))
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

    -- Use configurable full fill dimensions (defaults to 150x150 for backward compatibility)
    local fullWidth = self.fillWidth or 150
    local fullHeight = self.fillHeight or 150

    local height = (fullHeight * percent) / 100
    local coordTop = 1 - (percent / 100)
    local anchorY = fullHeight - height
    
    -- Calculate center offset: center the fill within the control (border size)
    -- The control is sized to borderSize, fill is smaller, so we offset to center it
    local controlWidth = self.control:GetWidth()
    local centerOffsetX = (controlWidth - fullWidth) / 2
    local centerOffsetY = (controlWidth - fullHeight) / 2
    -- (fillOffsetX, fillOffsetY already set above to apply to anchors)

    -- Add user-defined offsets on top of centering
    local fillOffsetX = self.fillOffsetX or 0
    local fillOffsetY = self.fillOffsetY or 0

    -- If this bar uses half texture coords (half of texture), apply horizontal shift to center it on left or right half
    local isHalfTexture = math.abs(self.baseCoordRight - self.baseCoordLeft - 0.5) < 0.001
    local fogAnchorXBase = centerOffsetX + self.baseAnchorX + fillOffsetX
    local function computeHalfAnchorX(isLeft)
        local containerW = controlWidth
        if isLeft then
            return math.floor((containerW / 4) - (fullWidth / 2) + fillOffsetX)
        else
            return math.floor((3 * containerW / 4) - (fullWidth / 2) + fillOffsetX)
        end
    end
    
    -- (fillOffsetX, fillOffsetY already set above to apply to anchors)

    if BETTERUI_ORB_DEBUG_PRINTS then
        d(string.format("BetterUI: RefreshVisuals[%s] powerType=%s controlW=%d fullW=%d fullH=%d isHalf=%s centerOffX=%d centerOffY=%d fillOffsetX=%d fillOffsetY=%d",
            tostring(self.label and self.label:GetText() or "unknown"), tostring(self.powerType), controlWidth, fullWidth, fullHeight, tostring(isHalfTexture), centerOffsetX, centerOffsetY, fillOffsetX, fillOffsetY))
    end

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
        self.fog:SetDimensions(fullWidth, fullHeight)
        self.fog:SetHeight(height)
        self.fog:SetTextureCoords(self.baseCoordLeft, self.baseCoordRight, coordTop, 1)
        self.fog:ClearAnchors()
        local fogAnchorX
        if isHalfTexture then
            local isLeft = (self.baseCoordLeft < self.baseCoordRight)
            fogAnchorX = computeHalfAnchorX(isLeft)
        else
            fogAnchorX = fogAnchorXBase
        end
        self.fog:SetAnchor(TOPLEFT, self.control, TOPLEFT, fogAnchorX, centerOffsetY + anchorY + fillOffsetY)
        if BETTERUI_ORB_DEBUG_PRINTS and self.fog then
            local w,h = self.fog:GetWidth(), self.fog:GetHeight()
                if w and h and w ~= h then
                d(string.format("BetterUI: WARNING fog non-square: powerType=%s w=%s h=%s fullW=%s fullH=%s", tostring(self.powerType), tostring(w), tostring(h), tostring(fullWidth), tostring(fullHeight)))
            end
        end
    end

    if self.fog2 ~= nil then
        local fog2AnchorX
        if isHalfTexture then
            local isLeft = (self.baseCoordLeft < self.baseCoordRight)
            fog2AnchorX = computeHalfAnchorX(isLeft)
        else
            fog2AnchorX = fogAnchorXBase
        end
        self:MirrorFogToFog2(fullWidth, fullHeight, fog2AnchorX, centerOffsetY, fillOffsetY)
    end

    -- Mirror Fog to Fog2 defined at class level
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
    -- Calculate fill sizes based on border size and per-orb width/height scales
    -- Use width/height scales exclusively; no single-value fallbacks
    local leftFillWidthScale = BETTERUI_ORB_FILL_HEALTH_SCALE_WIDTH or 0.55
    local leftFillHeightScale = BETTERUI_ORB_FILL_HEALTH_SCALE_HEIGHT or 0.55
    local magickaFillWidthScale = BETTERUI_ORB_FILL_MAGICKA_SCALE_WIDTH or 0.5
    local magickaFillHeightScale = BETTERUI_ORB_FILL_MAGICKA_SCALE_HEIGHT or 0.5
    local staminaFillWidthScale = BETTERUI_ORB_FILL_STAMINA_SCALE_WIDTH or 0.5
    local staminaFillHeightScale = BETTERUI_ORB_FILL_STAMINA_SCALE_HEIGHT or 0.5
    local resourceFillWidthScale = BETTERUI_ORB_FILL_RESOURCE_SCALE_WIDTH or 0.5
    local resourceFillHeightScale = BETTERUI_ORB_FILL_RESOURCE_SCALE_HEIGHT or 0.5
    local leftBorderSize = BETTERUI_ORB_BORDER_LEFT_SIZE or 175
    local rightBorderSize = BETTERUI_ORB_BORDER_RIGHT_SIZE or 175
    -- compute per-orb width/height fills
    local healthFillWidth = math.min(math.floor(leftBorderSize * leftFillWidthScale + 0.5), leftBorderSize)
    local healthFillHeight = math.min(math.floor(leftBorderSize * leftFillHeightScale + 0.5), leftBorderSize)
    local magickaFillWidth = math.min(math.floor(rightBorderSize * magickaFillWidthScale + 0.5), rightBorderSize)
    local magickaFillHeight = math.min(math.floor(rightBorderSize * magickaFillHeightScale + 0.5), rightBorderSize)
    local staminaFillWidth = math.min(math.floor(rightBorderSize * staminaFillWidthScale + 0.5), rightBorderSize)
    local staminaFillHeight = math.min(math.floor(rightBorderSize * staminaFillHeightScale + 0.5), rightBorderSize)
    local resourceFillWidth = math.min(math.floor(rightBorderSize * resourceFillWidthScale + 0.5), rightBorderSize)
    local resourceFillHeight = math.min(math.floor(rightBorderSize * resourceFillHeightScale + 0.5), rightBorderSize)
    
    -- Get offset constants
    local healthFillOffsetX = BETTERUI_ORB_FILL_HEALTH_OFFSET_X or 0
    local healthFillOffsetY = BETTERUI_ORB_FILL_HEALTH_OFFSET_Y or 0
    local resourceFillOffsetX = BETTERUI_ORB_FILL_RESOURCE_OFFSET_X or 0
    local resourceFillOffsetY = BETTERUI_ORB_FILL_RESOURCE_OFFSET_Y or 0
    -- Individual magicka/stamina offsets (developer-only constants)
    local magickaFillOffsetX = BETTERUI_ORB_FILL_MAGICKA_OFFSET_X or resourceFillOffsetX
    local magickaFillOffsetY = BETTERUI_ORB_FILL_MAGICKA_OFFSET_Y or resourceFillOffsetY
    local staminaFillOffsetX = BETTERUI_ORB_FILL_STAMINA_OFFSET_X or resourceFillOffsetX
    local staminaFillOffsetY = BETTERUI_ORB_FILL_STAMINA_OFFSET_Y or resourceFillOffsetY

    m_pools = {
        [POWERTYPE_HEALTH] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbHealth'), POWERTYPE_HEALTH),
        [POWERTYPE_MAGICKA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbMagicka'), POWERTYPE_MAGICKA),
        [POWERTYPE_STAMINA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbStamina'), POWERTYPE_STAMINA),
        [POWERTYPE_MOUNT_STAMINA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbMount'), POWERTYPE_MOUNT_STAMINA),
        [POWERTYPE_WEREWOLF] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbWerewolf'), POWERTYPE_WEREWOLF),
    }
    
    -- Set fill sizes and offsets for health orb (left)
    m_pools[POWERTYPE_HEALTH].fillWidth = healthFillWidth
    m_pools[POWERTYPE_HEALTH].fillHeight = healthFillHeight
    m_pools[POWERTYPE_HEALTH].fillOffsetX = healthFillOffsetX
    m_pools[POWERTYPE_HEALTH].fillOffsetY = healthFillOffsetY
    
    -- Set fill sizes and offsets for resource orbs (right)
    for _, powerType in ipairs({POWERTYPE_MAGICKA, POWERTYPE_STAMINA, POWERTYPE_MOUNT_STAMINA, POWERTYPE_WEREWOLF}) do
        if m_pools[powerType] then
            -- Apply per-power sizes and offsets
            if powerType == POWERTYPE_MAGICKA then
                m_pools[powerType].fillWidth = magickaFillWidth
                m_pools[powerType].fillHeight = magickaFillHeight
                m_pools[powerType].fillOffsetX = magickaFillOffsetX
                m_pools[powerType].fillOffsetY = magickaFillOffsetY
            elseif powerType == POWERTYPE_STAMINA then
                m_pools[powerType].fillWidth = staminaFillWidth
                m_pools[powerType].fillHeight = staminaFillHeight
                m_pools[powerType].fillOffsetX = staminaFillOffsetX
                m_pools[powerType].fillOffsetY = staminaFillOffsetY
            else
                -- Fallback to generic resource offsets and sizes (Mount, Werewolf)
                m_pools[powerType].fillWidth = resourceFillWidth
                m_pools[powerType].fillHeight = resourceFillHeight
                m_pools[powerType].fillOffsetX = resourceFillOffsetX
                m_pools[powerType].fillOffsetY = resourceFillOffsetY
            end
        end
    end

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
    
    -- Apply layout constants for orbs and ornaments
    UpdateOrbLayout()
    
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
        UpdateOrbLayout()  -- Apply layout constants for orbs and ornaments (including OrbSplitter scaling)
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
