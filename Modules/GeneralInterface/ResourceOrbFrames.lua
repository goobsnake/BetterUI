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
local m_castBar = nil

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

local ORB_CONFIG = {
    [POWERTYPE_HEALTH] = {0, 1, 0, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restorehealth.dds'},
    [POWERTYPE_MAGICKA] = {0, 0.5, 0, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restoremagicka.dds'},
    [POWERTYPE_STAMINA] = {0.5, 0, 75, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restorestamina.dds'},
    [ATTRIBUTE_VISUAL_POWER_SHIELDING] = {1, 0, 0, nil},
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
            Fog = 'OrbFill.dds',
            Fog2 = 'OrbFill.dds',
            Border = 'OrbBorder.dds',
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

    -- Local aliases for config table
    local cfg = BETTERUI_ORB_FRAMES
    
    -- Orb border sizes
    local leftBorderSize = cfg.orbs.left.borderSize
    local rightBorderSize = cfg.orbs.right.borderSize
    
    -- Ornament scales
    local leftOrnamentScale = cfg.ornaments.left.scale
    local rightOrnamentScale = cfg.ornaments.right.scale
    
    -- Fill scales from config
    local healthFillWidth = math.min(math.floor(leftBorderSize * cfg.fills.health.scaleW + 0.5), leftBorderSize)
    local healthFillHeight = math.min(math.floor(leftBorderSize * cfg.fills.health.scaleH + 0.5), leftBorderSize)
    local healthFillOffsetX = cfg.fills.health.x
    local healthFillOffsetY = cfg.fills.health.y
    
    local magickaFillWidth = math.min(math.floor(rightBorderSize * cfg.fills.magicka.scaleW + 0.5), rightBorderSize)
    local magickaFillHeight = math.min(math.floor(rightBorderSize * cfg.fills.magicka.scaleH + 0.5), rightBorderSize)
    local staminaFillWidth = math.min(math.floor(rightBorderSize * cfg.fills.stamina.scaleW + 0.5), rightBorderSize)
    local staminaFillHeight = math.min(math.floor(rightBorderSize * cfg.fills.stamina.scaleH + 0.5), rightBorderSize)
    local resourceFillWidth = math.min(math.floor(rightBorderSize * cfg.fills.resource.scaleW + 0.5), rightBorderSize)
    local resourceFillHeight = math.min(math.floor(rightBorderSize * cfg.fills.resource.scaleH + 0.5), rightBorderSize)
    
    local magickaFillOffsetX = cfg.fills.magicka.x
    local magickaFillOffsetY = cfg.fills.magicka.y
    local staminaFillOffsetX = cfg.fills.stamina.x
    local staminaFillOffsetY = cfg.fills.stamina.y
    
    -- Splitter settings
    local splitterWidth = cfg.splitter.width
    local splitterHeight = rightBorderSize * cfg.splitter.heightScale
    local splitterOffsetX = cfg.splitter.x
    local splitterOffsetY = cfg.splitter.y
    
    -- ========================================
    -- ORNAMENTS: Position relative to BgMiddle (center of skill bars)
    -- ========================================
    if leftOrnament then
        local leftSize = cfg.ornaments.left.size * leftOrnamentScale
        leftOrnament:ClearAnchors()
        leftOrnament:SetDimensions(leftSize, leftSize)
        leftOrnament:SetAnchor(CENTER, bgMiddle, CENTER, cfg.ornaments.left.x, cfg.ornaments.left.y)
    end
    
    if rightOrnament then
        local rightSize = cfg.ornaments.right.size * rightOrnamentScale
        rightOrnament:ClearAnchors()
        rightOrnament:SetDimensions(rightSize, rightSize)
        rightOrnament:SetAnchor(CENTER, bgMiddle, CENTER, cfg.ornaments.right.x, cfg.ornaments.right.y)
    end
    
    -- ========================================
    -- ORBS: Position relative to their Ornaments
    -- ========================================
    if leftOrb and leftOrnament then
        leftOrb:ClearAnchors()
        leftOrb:SetDimensions(leftBorderSize, leftBorderSize)
        leftOrb:SetAnchor(CENTER, leftOrnament, CENTER, cfg.orbs.left.x, cfg.orbs.left.y)
    end
    
    if rightOrb and rightOrnament then
        rightOrb:ClearAnchors()
        rightOrb:SetDimensions(rightBorderSize, rightBorderSize)
        rightOrb:SetAnchor(CENTER, rightOrnament, CENTER, cfg.orbs.right.x, cfg.orbs.right.y)
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
        
        -- Resize and show Border
        local border = FindControl(healthOrb, 'Border')
        if border then 
            border:SetHidden(false)
            border:SetDimensions(leftBorderSize, leftBorderSize) 
        end
    end
    
    -- ========================================
    -- RESOURCE ORB FILL (Right - Blue/Green for Magicka/Stamina)
    -- ========================================
    local subContainers = {'OrbMagicka', 'OrbStamina'}
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
                
                -- Update Label Positioning for split orbs (uses CONST offsets)
                local label = FindControl(container, 'Label')
                if label then
                    label:ClearAnchors()
                    local labelOffsetX, labelOffsetY = 0, 0
                    
                    if containerName == 'OrbMagicka' then
                        labelOffsetX = -math.floor(rightBorderSize * 0.25) + cfg.labels.magicka.x
                        labelOffsetY = cfg.labels.magicka.y
                    elseif containerName == 'OrbStamina' then
                        labelOffsetX = math.floor(rightBorderSize * 0.25) + cfg.labels.stamina.x
                        labelOffsetY = cfg.labels.stamina.y
                    end
                    
                    label:SetAnchor(CENTER, container, CENTER, labelOffsetX, labelOffsetY)
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
                            ctrl:SetAnchor(CENTER, container, CENTER, cfg.fills.resource.x, cfg.fills.resource.y)
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
            end
        end
                if BETTERUI_ORB_DEBUG_PRINTS then
                    d(string.format("BetterUI: UpdateOrbLayout Resource border=%d magW=%d magH=%d staW=%d staH=%d magHalf=%d staHalf=%d magX=%d magY=%d staX=%d staY=%d splitterW=%d splitterH=%.2f", rightBorderSize, magickaFillWidth, magickaFillHeight, staminaFillWidth, staminaFillHeight, magickaHalfWidth, staminaHalfWidth, magickaFillOffsetX, magickaFillOffsetY, staminaFillOffsetX, staminaFillOffsetY, splitterWidth, splitterHeight))
                end
    end
end


-- Layout config using structured constants
local LAYOUT_CONFIG = {
    GAMEPAD = {
        abilitySlotWidth = BETTERUI_ORB_FRAMES.slots.gamepad.width,
        abilitySlotOffsetX = BETTERUI_ORB_FRAMES.slots.gamepad.spacing,
        dualBarOffsetX = BETTERUI_ORB_FRAMES.slots.gamepad.dualBarOffset,
    },
    KEYBOARD = {
        abilitySlotWidth = BETTERUI_ORB_FRAMES.slots.keyboard.width,
        abilitySlotOffsetX = BETTERUI_ORB_FRAMES.slots.keyboard.spacing,
        dualBarOffsetX = BETTERUI_ORB_FRAMES.slots.keyboard.dualBarOffset,
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
    local ultimateGap = BETTERUI_ORB_FRAMES.bars.ultimateGap
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
        local shiftLeft = -(width * BETTERUI_ORB_FRAMES.bars.mainBarShiftFactor)
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
        quickSlotButton.slot:SetAnchor(RIGHT, barParent, LEFT, BETTERUI_ORB_FRAMES.bars.quickslotOffsetX, 0)
    end
end

local function UpdateBarPositions(rootFrame)
    local actionBarContainer = FindControl(rootFrame, 'ActionBarContainer')
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    
    if not actionBarContainer or not backBarContainer or not bgMiddle then return end
    
    local isGamePad = IsInGamepadPreferredMode()
    local bars = BETTERUI_ORB_FRAMES.bars
    
    local shiftY = bars.shiftY
    local bottomY = (isGamePad and bars.bottom.gamepadY or bars.bottom.keyboardY) + shiftY
    local topY = (isGamePad and bars.top.gamepadY or bars.top.keyboardY) + shiftY
    local bottomX = bars.bottom.x
    local topX = bars.top.x
    
    actionBarContainer:ClearAnchors()
    backBarContainer:ClearAnchors()
    actionBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, bottomX, bottomY)
    backBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, topX, topY)
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



function BetterUIOrbBar:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function BetterUIOrbBar:Initialize(control, powerType)
    self.control = control
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
        -- Format values with k/M notation
        if self.currentValue >= 1000000 then
            self.label:SetText(string.format("%.1fM", self.currentValue / 1000000))
        elseif self.currentValue >= 10000 then
           self.label:SetText(string.format("%.0fk", self.currentValue / 1000))
        elseif self.currentValue >= 1000 then
           self.label:SetText(string.format("%.1fk", self.currentValue / 1000))
        else
           self.label:SetText(string.format("%d", self.currentValue))
        end
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

-------------------------------------------------------------------------------------------------
-- BetterUIBarFrame Class (Base for XP and Cast Bars)
-------------------------------------------------------------------------------------------------

local BetterUIBarFrame = ZO_Object:Subclass()

function BetterUIBarFrame:New(control)
    local obj = ZO_Object.New(self)
    self.control = control
    return obj
end

function BetterUIBarFrame:Initialize(name, parent)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    self.control = control
    
    -- Fill (OrbFill.dds) - Create FIRST (Bottom) so it sits BEHIND the backdrop
    local fill = WINDOW_MANAGER:CreateControl(name .. "Fill", control, CT_TEXTURE)
    fill:SetTexture(ResolveTexturePath("OrbFill.dds"))
    fill:SetAnchor(LEFT, control, LEFT, 0, 0) -- Anchor will be updated in UpdateVisuals
    self.fill = fill

    -- Backdrop (Bar.dds) - Create SECOND (Top) so it masks the fill
    local backdrop = WINDOW_MANAGER:CreateControl(name .. "Backdrop", control, CT_TEXTURE)
    backdrop:SetTexture(ResolveTexturePath("Bar.dds"))
    backdrop:SetAnchor(CENTER, control, CENTER, 0, 0)
    self.backdrop = backdrop
    
    -- Label - Create LAST so it is ON TOP of everything
    local label = WINDOW_MANAGER:CreateControl(name .. "Label", control, CT_LABEL)
    label:SetAnchor(CENTER, control, CENTER, 0, 4) -- Nudge down 4px
    label:SetFont("ZoFontGame")
    label:SetColor(1, 1, 1, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.label = label
    
    return control
end

function BetterUIBarFrame:SetColor(r, g, b, a)
    if self.fill then
        self.fill:SetColor(r, g, b, a)
    end
end

function BetterUIBarFrame:UpdateVisuals(current, max, insetX, insetY, barWidth, barHeight)
    if not self.control or self.control:IsHidden() then return end
    
    -- Update Backdrop Size
    if self.backdrop then
        self.backdrop:SetDimensions(barWidth, barHeight)
    end
    
    -- Update Fill
    if self.fill and max > 0 then
        local percent = math.min(1, math.max(0, current / max))
        local fillMaxWidth = barWidth - (2 * insetX)
        local fillHeight = barHeight - (2 * insetY)
        
        -- Resize fill based on percentage
        self.fill:SetDimensions(fillMaxWidth * percent, fillHeight)
        -- Re-anchor to ensure it stays inside the inset
        self.fill:ClearAnchors()
        self.fill:SetAnchor(LEFT, self.control, LEFT, insetX, 0)
        self.fill:SetTextureCoords(0, percent, 0, 1) -- Basic L->R texture mapping
    end
end



function BetterUIBarFrame:ApplySettings(enabled, scale, offsetX, offsetY, textSize, textColor)
    if not self.control then return end
    
    -- Apply Visibility
    self.control:SetHidden(not enabled)
    
    -- Apply Scale (if needed, currently scale is applied via layout constants typically)
    self.control:SetScale(scale or 1.0)
    
    -- Apply Text Settings
    if self.label then
        local font = string.format("$(BOLD_FONT)|%d|thick-outline", textSize or 16)
        self.label:SetFont(font)
        self.label:SetColor(unpack(textColor or {1, 1, 1, 1}))
    end
    
    -- Update visual state immediately
    if enabled then
        -- Force re-layout if we had logic for it, but UpdateDynamicLayout handles main anchors
        if self.Update then self:Update() end
    end
end

-------------------------------------------------------------------------------------------------
-- Cast Bar Class
-------------------------------------------------------------------------------------------------

local CastBar = BetterUIBarFrame:Subclass()

function CastBar:New(parent)
    local obj = ZO_Object.New(self)
    obj:Initialize(parent)
    return obj
end

function CastBar:Initialize(parent)
    BetterUIBarFrame.Initialize(self, "BetterUICastBar", parent)
    self.isCasting = false
    self.duration = 0
    self.startTime = 0
    self:SetColor(1, 1, 0.4, 1) -- Light yellowish for cast
    -- Set default text immediately
    self.label:SetText("Cast Bar")
    
    local function OnCastStart(_, channelInfo)
        -- channelInfo is for channeled abilities, regular casts follow different flow
        -- But for simplicity we hook the visual events
    end
    
    -- Hook into ESO's event system
    -- EVENT_SPELL_CASTING_START: (eventCode, unitTag, spellName, rank, castId, isChanneled)
    EVENT_MANAGER:RegisterForEvent(NAME .. "CastStart", EVENT_SPELL_CASTING_START, function(_, unitTag, abilityName, _, _, isChanneled) 
        return self:OnCastStart(unitTag, abilityName, 0, isChanneled) 
    end)
    
    -- EVENT_SPELL_CASTING_UPDATE: (eventCode, unitTag, lastUpdateTimestamp, nextUpdateTimestamp)
    -- This event is fired for channels? Or simply updates the timer?
    -- Actually for channels, EVENT_SPELL_CASTING_START usually provides info, or EVENT_ABILITY_USE_START?
    
    -- Let's try hooking the visualizer events which are more reliable for UI
    -- But sticking to basic SPELL_CASTING for now as per API check.
    
    -- Correct signature for SPELL_CASTING_START based on commonly used addons:
    -- eventCode, unitTag, effectName, cost, mainIcon, castType, duration, startTime, endTime, isChanneled
    -- Wait, standard API is:
    -- EVENT_SPELL_CASTING_START (integer unitTag, string effectName, integer cost, string mainIcon, integer castType, integer duration, integer startTime, integer endTime, boolean isChanneled)
    
    EVENT_MANAGER:UnregisterForEvent(NAME .. "CastStart", EVENT_SPELL_CASTING_START) -- Clear old one
    EVENT_MANAGER:RegisterForEvent(NAME .. "CastStart", EVENT_SPELL_CASTING_START, function(_, unitTag, effectName, _, _, _, duration, startTime, endTime, isChanneled)
        return self:OnCastStart(unitTag, effectName, duration, isChanneled)
    end)

    EVENT_MANAGER:RegisterForEvent(NAME .. "CastStop", EVENT_SPELL_CASTING_STOP, function(_, unitTag, _, _, _, wasInterrupted) 
        return self:OnCastStop(unitTag, wasInterrupted) 
    end)
    
    -- Hide default cast bar if possible
    -- Standard ESO cast bar is often handled by ZO_PlayerProgress or specific HUD elements.
    -- Hide default cast bar if possible
    -- Standard ESO cast bar is often handled by ZO_PlayerProgress or specific HUD elements.
    local function HideDefaultCastBar()
        if ZO_CastingBar then ZO_CastingBar:SetHidden(true) end
        if ZO_PlayerCastingBar then ZO_PlayerCastingBar:SetHidden(true) end
        -- Hide main progress bars if using custom ones
        if ZO_PlayerProgressBar then ZO_PlayerProgressBar:SetHidden(true) end
        
        -- Gamepad specific hiding
        if ZO_GamepadPlayerProgressBar then ZO_GamepadPlayerProgressBar:SetHidden(true) end
        if GAMEPAD_PLAYER_PROGRESS_BAR_FRAGMENT then GAMEPAD_PLAYER_PROGRESS_BAR_FRAGMENT:SetHiddenForReason("BetterUICastBar", true) end
    end
    HideDefaultCastBar()
    EVENT_MANAGER:RegisterForEvent(NAME .. "HideDefaultCast", EVENT_PLAYER_ACTIVATED, HideDefaultCastBar)
    
    -- Srendarr-inspired Cast Detection
    -- We use EVENT_ACTION_SLOT_ABILITY_USED for immediate feedback and robust channel detection (e.g. Biting Jabs)
    EVENT_MANAGER:RegisterForEvent(NAME .. "SlotAbilityUsed", EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotIndex)
        local hotbar = GetActiveHotbarCategory()
        local abilityId = GetSlotBoundId(slotIndex, hotbar)
        
        -- Validate slot
        if not abilityId or abilityId == 0 then return end
        
        -- Srendarr Logic: Ignore toggled slots
        if IsSlotToggled(slotIndex) then return end
        
        -- Get Cast Info
        -- Note: As per Srendarr reference, Gold Coast API update merged channel/cast times.
        -- We check both returns for safety against future/past API versions.
        local isChanneled, castTime, channelTime = GetAbilityCastInfo(abilityId)
        local duration = math.max(castTime or 0, channelTime or 0)
        
        -- Filter out instants (less than 100ms? or 0)
        if duration <= 0 then return end
        
        local name = GetAbilityName(abilityId)
        
        -- Trigger Cast Start
        self:OnCastStart("player", name, duration, isChanneled)
    end)
    
    EVENT_MANAGER:AddFilterForEvent(NAME .. "SlotAbilityUsed", EVENT_ACTION_SLOT_ABILITY_USED, REGISTER_FILTER_UNIT_TAG, "player")

    -- Keep EVENT_SPELL_CASTING_START as a fallback/confirmation? 
    -- Srendarr relies purely on SlotUsed, but for compatibility we can keep listening 
    -- but ideally we avoid duplicate events.
    -- However, standard casting events are better for 'server confirmed' casts (latency handling).
    -- But since user wants Jabs (channel) to work, SlotUsed is best.
    
    -- Cleanup old events to avoid double triggers if possible, or handle overlap in OnCastStart
    -- We can set a flag 'self.lastCastId' or similar, but simplified approach first.
    
    EVENT_MANAGER:RegisterForEvent(NAME .. "CastStop", EVENT_SPELL_CASTING_STOP, function(_, unitTag, _, _, _, wasInterrupted) 
        return self:OnCastStop(unitTag, wasInterrupted) 
    end)
    
    EVENT_MANAGER:AddFilterForEvent(NAME .. "CastStop", EVENT_SPELL_CASTING_STOP, REGISTER_FILTER_UNIT_TAG, "player")
    
    -- Register Update Loop (Critical for Animation)
    self.control:SetHandler("OnUpdate", function() self:Update() end)
end

function CastBar:OnCastStart(unitTag, abilityName, castDuration, isChanneled)
    if unitTag ~= "player" then return end
    
    -- If already casting same ability, refresh
    self.isCasting = true
    self.duration = castDuration / 1000 -- Convert to seconds
    self.startTime = GetFrameTimeSeconds()
    self.abilityName = abilityName
    self.isChanneled = isChanneled
    
    self.control:SetHidden(false)
end

function CastBar:OnCastStop(unitTag, wasInterrupted)
    if unitTag ~= "player" then return end
    self.isCasting = false
    -- self.control:SetHidden(true) -- REMOVED: Do not hide on stop
    self:Update() -- Force one last update
end

function CastBar:OnCastUpdate(unitTag, castDuration)
    -- Handle pushback update if needed
end

function CastBar:Update()
    -- Check global setting
    if not BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarEnabled then
        self.control:SetHidden(true)
        return
    end
    
    -- Ensure dimensions are set (fixing previous bug)
    local w = BETTERUI_CAST_BAR_WIDTH or 250
    local h = BETTERUI_CAST_BAR_HEIGHT or 150
    self.control:SetDimensions(w, h)
    self.control:SetScale(BETTERUI_CAST_BAR_SCALE or 1.0)
    
    -- Ensure visible if enabled
    if self.control:IsHidden() then self.control:SetHidden(false) end

    local current, max = 0, 1
    local insetX = BETTERUI_CAST_BAR_FILL_INSET_X or 40
    local insetY = BETTERUI_CAST_BAR_FILL_INSET_Y or 55

    if self.isCasting then
        -- ACTIVE STATE
        local now = GetFrameTimeSeconds()
        local elapsed = now - self.startTime
        local remaining = math.max(0, self.duration - elapsed)
        
        -- Srendarr Logic & User Request: "Drain accordingly"
        -- We apply DRAIN logic (Full -> Empty) for BOTH Channels and Casts to ensure consistency.
        -- Use remaining time for current value.
        current = remaining
        max = self.duration
        
        -- Cap current to bounds
        if current < 0 then current = 0 end
        if current > max then current = max end
        
        -- Display "Ability Name (1.5s)"
        self.label:SetText(string.format("%s (%.1fs)", self.abilityName or "Casting", remaining))
        
        -- Auto-finish if duration exceeded?
        if elapsed > self.duration + 0.5 then -- Tolerance
             -- Force verify with engine if it's really done?
             -- Usually safe to assume done.
             self:OnCastStop("player", false)
        end
    else
        -- IDLE STATE (Fill 0)
        current = 0
        max = 1
        self.label:SetText("Cast Bar")
    end
    
    self:UpdateVisuals(current, max, insetX, insetY, w, h)
end

-------------------------------------------------------------------------------------------------
-- ExperienceBar Class (Refactored)
-------------------------------------------------------------------------------------------------

local ExperienceBar = BetterUIBarFrame:Subclass()

function ExperienceBar:New(parent)
    local obj = ZO_Object.New(self)
    obj:Initialize(parent)
    return obj
end

function ExperienceBar:Initialize(parent)
    BetterUIBarFrame.Initialize(self, "BetterUIXPBar", parent)
    self:SetColor(0.1, 0.85, 0.8, 1) -- Turquoise/Teal color
end

function ExperienceBar:Update()
    if not self.control then return end
    
    local isChampion = IsUnitChampion("player")
    local current, max, effectiveMax = 0, 0, 0
    local labelText = ""

    if isChampion then
        -- Confirmed by user debug: 
        -- GetPlayerChampionXP() returns XP towards NEXT point (Current).
        -- GetNumChampionXPInChampionPoint(cp) returns XP required for NEXT point (Max).
        local currentCP = GetPlayerChampionPointsEarned()
        current = GetPlayerChampionXP()
        
        -- Safe call for Max
        local success, size = pcall(GetNumChampionXPInChampionPoint, currentCP)
        if success and size then 
            max = size 
        else 
            max = 400000 -- Fallback standard
        end
        
        -- Ensure non-zero max division
        if max <= 0 then max = 1 end

        effectiveMax = max
        
        -- Label with Percent
        local percent = math.floor((current / max) * 100)
        labelText = string.format("CP: %d (%d%%)", currentCP, percent)
    else
        current = GetUnitXP("player")
        max = GetUnitXPMax("player")
        labelText = string.format("XP: %d / %d", current, max)
        effectiveMax = max
    end
    
    self.label:SetText(labelText)
    
    local insetX = BETTERUI_XP_BAR_FILL_INSET_X or 8
    local insetY = BETTERUI_XP_BAR_FILL_INSET_Y or 4
    local w = BETTERUI_XP_BAR_WIDTH or 250
    local h = BETTERUI_XP_BAR_HEIGHT or 150
    
    self.control:SetDimensions(w, h)
    self.control:SetScale(BETTERUI_XP_BAR_SCALE or 1.0)
    
    self:UpdateVisuals(current, effectiveMax, insetX, insetY, w, h)
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
    -- Use structured config table
    local cfg = BETTERUI_ORB_FRAMES
    local leftBorderSize = cfg.orbs.left.borderSize
    local rightBorderSize = cfg.orbs.right.borderSize
    
    -- Compute fill sizes from config scales
    local healthFillWidth = math.min(math.floor(leftBorderSize * cfg.fills.health.scaleW + 0.5), leftBorderSize)
    local healthFillHeight = math.min(math.floor(leftBorderSize * cfg.fills.health.scaleH + 0.5), leftBorderSize)
    local magickaFillWidth = math.min(math.floor(rightBorderSize * cfg.fills.magicka.scaleW + 0.5), rightBorderSize)
    local magickaFillHeight = math.min(math.floor(rightBorderSize * cfg.fills.magicka.scaleH + 0.5), rightBorderSize)
    local staminaFillWidth = math.min(math.floor(rightBorderSize * cfg.fills.stamina.scaleW + 0.5), rightBorderSize)
    local staminaFillHeight = math.min(math.floor(rightBorderSize * cfg.fills.stamina.scaleH + 0.5), rightBorderSize)
    local resourceFillWidth = math.min(math.floor(rightBorderSize * cfg.fills.resource.scaleW + 0.5), rightBorderSize)
    local resourceFillHeight = math.min(math.floor(rightBorderSize * cfg.fills.resource.scaleH + 0.5), rightBorderSize)

    m_pools = {
        [POWERTYPE_HEALTH] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbHealth'), POWERTYPE_HEALTH),
        [POWERTYPE_MAGICKA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbMagicka'), POWERTYPE_MAGICKA),
        [POWERTYPE_STAMINA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbStamina'), POWERTYPE_STAMINA),
    }
    
    -- Set fill sizes and offsets for health orb (left)
    m_pools[POWERTYPE_HEALTH].fillWidth = healthFillWidth
    m_pools[POWERTYPE_HEALTH].fillHeight = healthFillHeight
    m_pools[POWERTYPE_HEALTH].fillOffsetX = cfg.fills.health.x
    m_pools[POWERTYPE_HEALTH].fillOffsetY = cfg.fills.health.y
    
    -- Set fill sizes and offsets for resource orbs (right)
    m_pools[POWERTYPE_MAGICKA].fillWidth = magickaFillWidth
    m_pools[POWERTYPE_MAGICKA].fillHeight = magickaFillHeight
    m_pools[POWERTYPE_MAGICKA].fillOffsetX = cfg.fills.magicka.x
    m_pools[POWERTYPE_MAGICKA].fillOffsetY = cfg.fills.magicka.y
    
    m_pools[POWERTYPE_STAMINA].fillWidth = staminaFillWidth
    m_pools[POWERTYPE_STAMINA].fillHeight = staminaFillHeight
    m_pools[POWERTYPE_STAMINA].fillOffsetX = cfg.fills.stamina.x
    m_pools[POWERTYPE_STAMINA].fillOffsetY = cfg.fills.stamina.y

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
end

local function SetupFoodTracker(rootFrame)
    m_foodTracker = FoodBuffTracker:New(FindControl(rootFrame, 'FoodBar'))
end

local function SetupExperienceBar(rootFrame)
    m_experienceBar = ExperienceBar:New(rootFrame)
end

local function SetupCastBar(rootFrame)
    m_castBar = CastBar:New(rootFrame)
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
    else
         -- Explicitly hide FoodBar if not in use, because ExperienceBar no longer hijacks it
         local bar = FindControl(rootFrame, 'FoodBar')
         if bar then bar:SetHidden(true) end
    end
    
    -- Update BetterUI Bars
    if m_experienceBar then m_experienceBar:Update() end
    if m_castBar then m_castBar:Update() end

end

local function SetupModule(control)
    m_isInitialized = true
    
    SetupPowerPools(control)
    SetupShieldBar(control)
    SetupStateHandlers()
    SetupFoodTracker(control)
    SetupExperienceBar(control)
    SetupCastBar(control)
    
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

local function UpdateDynamicLayout()
    if not m_rootFrame then return end
    
    local ornamentLeft = FindControl(m_rootFrame, "OrnamentLeft")
    local ornamentRight = FindControl(m_rootFrame, "OrnamentRight")
    local bgMiddle = FindControl(m_rootFrame, "BgMiddle")
    local xpBar = FindControl(m_rootFrame, "BetterUIXPBar")
    local castBar = FindControl(m_rootFrame, "BetterUICastBar")
    
    if not ornamentLeft or not ornamentRight or not bgMiddle then return end
    
    local settings = GetModuleSettings()
    local cfg = BETTERUI_ORB_FRAMES
    
    -- Right Side: XP Bar
    local rightX = cfg.ornaments.right.x
    local rightY = cfg.ornaments.right.y
    
    ornamentRight:ClearAnchors()
    if settings.xpBarEnabled then
        -- Shift Ornament UP
        ornamentRight:SetAnchor(CENTER, bgMiddle, CENTER, rightX, rightY - 55)
        
        if xpBar then
            xpBar:ClearAnchors()
            xpBar:SetAnchor(TOP, ornamentRight, BOTTOM, BETTERUI_XP_BAR_OFFSET_X or 0, BETTERUI_XP_BAR_OFFSET_Y or -95) 
        end
    else
        -- Reset Ornament
        ornamentRight:SetAnchor(CENTER, bgMiddle, CENTER, rightX, rightY)
        
        -- Reset XP Bar
        if xpBar then 
            xpBar:ClearAnchors()
            xpBar:SetAnchor(BOTTOM, bgMiddle, BOTTOM, BETTERUI_XP_BAR_OFFSET_X, -BETTERUI_XP_BAR_OFFSET_Y)
        end
    end
    
    -- Left Side: Cast Bar
    local leftX = cfg.ornaments.left.x
    local leftY = cfg.ornaments.left.y
    
    ornamentLeft:ClearAnchors()
    if settings.castBarEnabled then
        -- Shift Ornament UP (same offset as Right)
        ornamentLeft:SetAnchor(CENTER, bgMiddle, CENTER, leftX, leftY - 45)
        
        -- Anchor Cast Bar to Left Ornament
        if castBar then
            castBar:ClearAnchors()
            -- Mirror logic: Anchor TOP to BOTTOM with overlap
            -- Uses global offset constants allowing user adjustment in CONST.lua
            castBar:SetAnchor(TOP, ornamentLeft, BOTTOM, BETTERUI_CAST_BAR_OFFSET_X or 0, BETTERUI_CAST_BAR_OFFSET_Y or -95) 
        end
    else
        -- Reset Ornament
        ornamentLeft:SetAnchor(CENTER, bgMiddle, CENTER, leftX, leftY)
        
        -- Reset Cast Bar
        if castBar then
            castBar:ClearAnchors()
            -- Default position if hidden/disabled (mirroring right roughly)
            castBar:SetAnchor(BOTTOM, bgMiddle, BOTTOM, 0, -160)
        end
    end
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
        
        -- Apply orb label visuals
        local function ApplyOrbLabelVisuals()
            local currentSettings = GetModuleSettings()
            
            local function ApplyStyle(powerType, sizeSetting, colorSetting)
                if m_pools[powerType] and m_pools[powerType].label then
                    local label = m_pools[powerType].label
                    local size = currentSettings[sizeSetting] or 20
                    local color = currentSettings[colorSetting] or {1, 1, 1, 1}
                    
                    -- Apply font and color
                    label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", size))
                    label:SetColor(unpack(color))
                    
                    -- Ensure visible
                    label:SetHidden(false)
                    
                    -- Ensure parent container is visible if it was hidden (e.g. for Shield/Label container logic)
                    -- For standard orbs (Health/Mag/Stam), the label is direct child of a control or container.
                    -- In XML, Health label is in a sub-control "inherits=...". 
                    -- We just need to make sure the label itself is shown, which we did.
                    -- Also force a refresh of the text content
                    m_pools[powerType]:RefreshLabel()
                end
            end

            ApplyStyle(POWERTYPE_HEALTH, "healthTextSize", "healthTextColor")
            ApplyStyle(POWERTYPE_MAGICKA, "magickaTextSize", "magickaTextColor")
            ApplyStyle(POWERTYPE_STAMINA, "staminaTextSize", "staminaTextColor")
        end
        ApplyOrbLabelVisuals()

        -- Apply Settings to Custom Bars
        if m_experienceBar then
            m_experienceBar:ApplySettings(
                settings.xpBarEnabled, 
                BETTERUI_XP_BAR_SCALE, 
                BETTERUI_XP_BAR_OFFSET_X, 
                BETTERUI_XP_BAR_OFFSET_Y, 
                settings.xpBarTextSize, 
                settings.xpBarTextColor
            )
            -- Trigger immediate update if enabled
            if settings.xpBarEnabled then m_experienceBar:Update() end
        end
        
        if m_castBar then
            m_castBar:ApplySettings(
                settings.castBarEnabled, 
                BETTERUI_CAST_BAR_SCALE, 
                BETTERUI_CAST_BAR_OFFSET_X, 
                BETTERUI_CAST_BAR_OFFSET_Y, 
                settings.castBarTextSize, 
                settings.castBarTextColor
            )
        end

        UpdateOrbLayout()  -- Apply layout constants for orbs and ornaments (including OrbSplitter scaling)
        UpdateDynamicLayout() -- Apply dynamic shifts based on visible bars
        RefreshAllData(m_rootFrame)
        
        -- Hide default bars
        if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
            PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
        end
    else
        m_rootFrame:SetHidden(true)
        -- Hide custom bars
        if m_experienceBar and m_experienceBar.control then m_experienceBar.control:SetHidden(true) end
        if m_castBar and m_castBar.control then m_castBar.control:SetHidden(true) end
        
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
