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
local m_castBar = nil
local m_mountStaminaBar = nil
local m_updateDeathFragment = nil



-- Default Settings
local DEFAULTS = {
    enabled = false,
    scale = 1,
    offsetY = 0,
    useCustomTextures = false,
    centerBarType = "XP",
    -- Cooldown text settings
    cooldownTextSize = 27,
    cooldownTextColor = {0.86, 0.84, 0.13, 1}, -- DCD822 Yellow
    quickslotTextSize = 27,
    quickslotTextColor = {1, 1, 1, 1}, -- White
    shieldTextColor = {0, 1, 1, 1}, -- Cyan matching shield graphic
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

    if scale then 
        m_rootFrame:SetScale(scale)
        -- NOTE: We intentionally do NOT scale ZO_ActionBar1.
        -- ESO's internal ApplyStyle/SetCompanionAnchors/animation code
        -- assumes scale 1.0. When we set a different scale, ESO's
        -- positioning calculations conflict with our scaled container,
        -- causing the "buttons get bigger" issue on companion spawn/weapon swap.
    end
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
    -- REMOVED math.floor rounding to prevent scaling alignment issues (user reported misalignment at 1.5 scale)
    local healthFillWidth = math.min(leftBorderSize * cfg.fills.health.scaleW, leftBorderSize)
    local healthFillHeight = math.min(leftBorderSize * cfg.fills.health.scaleH, leftBorderSize)
    local healthFillOffsetX = cfg.fills.health.x
    local healthFillOffsetY = cfg.fills.health.y
    
    local magickaFillWidth = math.min(rightBorderSize * cfg.fills.magicka.scaleW, rightBorderSize)
    local magickaFillHeight = math.min(rightBorderSize * cfg.fills.magicka.scaleH, rightBorderSize)
    local staminaFillWidth = math.min(rightBorderSize * cfg.fills.stamina.scaleW, rightBorderSize)
    local staminaFillHeight = math.min(rightBorderSize * cfg.fills.stamina.scaleH, rightBorderSize)
    local resourceFillWidth = math.min(rightBorderSize * cfg.fills.resource.scaleW, rightBorderSize)
    local resourceFillHeight = math.min(rightBorderSize * cfg.fills.resource.scaleH, rightBorderSize)
    
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
    -- ORBS: Position relative to their Ornaments (Restored Hierarchy)
    -- ========================================
    -- We anchor the Orbs to the Ornaments to ensure they stay locked together
    -- during scaling. The high-precision math (no rounding) ensures Fills stay
    -- aligned with the Orbs.
    
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
    -- SHIELD ORB OVERLAY (Position relative to Health Orb)
    -- The shield displays as a RING around the health orb, so we make it slightly larger
    -- ========================================
    local shieldOrb = FindControl(m_rootFrame, 'OrbShield')
    if shieldOrb and healthOrb then
        -- Make shield 20% larger than health orb to create ring effect
        local shieldSize = leftBorderSize * 1.2
        shieldOrb:SetDimensions(shieldSize, shieldSize)
        shieldOrb:ClearAnchors()
        shieldOrb:SetAnchor(CENTER, healthOrb, CENTER, 0, 0)
        
        -- Position shield label below health label using config offset
        local shieldLabel = FindControl(shieldOrb, 'Label')
        if shieldLabel then
            local labelCfg = cfg.labels.shield
            shieldLabel:ClearAnchors()
            -- Anchor to the health orb's center, offset down by the config value
            shieldLabel:SetAnchor(CENTER, healthOrb, CENTER, labelCfg.x, labelCfg.y)
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
                -- Explicitly size and position the container to match the parent OrbResource
                -- This ensures container:GetWidth() returns the correct border size for fill calculations
                container:SetDimensions(rightBorderSize, rightBorderSize)
                container:ClearAnchors()
                container:SetAnchor(CENTER, resourceOrb, CENTER, 0, 0)

                -- Show and resize Fog textures (resource fill)
                local fogElements = {'Fog', 'Fog2', 'Fog3'}
                -- For Magicka/Stamina we want to use full square fills and offset them to the left/right halves
                
                -- REMOVED rounding
                local magickaRoundedW = magickaFillWidth
                local magickaRoundedH = magickaFillHeight
                local staminaRoundedW = staminaFillWidth
                local staminaRoundedH = staminaFillHeight
                
                -- For compatibility we compute half widths for auras per-half
                local magickaHalfWidth = math.min(magickaFillWidth * 0.5, rightBorderSize * 0.5)
                local staminaHalfWidth = math.min(staminaFillWidth * 0.5, rightBorderSize * 0.5)
                
                -- Compute TOPLEFT anchors for placing a full-size square over the left and right halves
                -- No floor rounding here either to preserve relative positioning at high scales
                local leftFogAnchorX = (rightBorderSize / 4) - (magickaRoundedW / 2) + magickaFillOffsetX
                local rightFogAnchorX = (3 * rightBorderSize / 4) - (staminaRoundedW / 2) + staminaFillOffsetX
                
                if BETTERUI_ORB_DEBUG_PRINTS then
                    d(string.format("BetterUI: UpdateOrbLayout ResourceFill: magickaW=%.2f magickaH=%.2f staminaW=%.2f staminaH=%.2f leftAnchor=%.2f rightAnchor=%.2f",
                        magickaRoundedW, magickaRoundedH, staminaRoundedW, staminaRoundedH, leftFogAnchorX, rightFogAnchorX))
                end
                
                -- Update Label Positioning for split orbs (uses CONST offsets)
                local label = FindControl(container, 'Label')
                if label then
                    label:ClearAnchors()
                    local labelOffsetX, labelOffsetY = 0, 0
                    
                    if containerName == 'OrbMagicka' then
                        labelOffsetX = -(rightBorderSize * 0.25) + cfg.labels.magicka.x
                        labelOffsetY = cfg.labels.magicka.y
                    elseif containerName == 'OrbStamina' then
                        labelOffsetX = (rightBorderSize * 0.25) + cfg.labels.stamina.x
                        labelOffsetY = cfg.labels.stamina.y
                    end
                    
                    label:SetAnchor(CENTER, container, CENTER, labelOffsetX, labelOffsetY)
                end

                -- compute vertical center offsets for per-half fills
                local magickaCenterOffsetY = (rightBorderSize - magickaFillHeight) / 2
                local staminaCenterOffsetY = (rightBorderSize - staminaFillHeight) / 2
                
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
                            ctrl:SetDimensions(resourceFillWidth, resourceFillHeight)
                            ctrl:SetAnchor(CENTER, container, CENTER, cfg.fills.resource.x, cfg.fills.resource.y)
                        end
                        -- If this is the background layer (Fog2), ensure it's shown at full texture coords
                        if name == 'Fog2' then
                            -- Use the same horizontal texture coords as the foreground fog so Fog2 visually matches the same segment
                            if containerName == 'OrbMagicka' then
                                local baseLeft, baseRight = unpack(ORB_CONFIG[POWERTYPE_MAGICKA])
                                local isLeft = (baseLeft < baseRight)
                                ctrl:SetTextureCoords(baseLeft, baseRight, 0, 1)
                            elseif containerName == 'OrbStamina' then
                                local baseLeft, baseRight = unpack(ORB_CONFIG[POWERTYPE_STAMINA])
                                local isLeft = (baseLeft < baseRight)
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
                    local w = splitterWidth
                    local h = splitterHeight
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



-- Check if player has unlocked weapon swap (backup bar) - requires level 15
local function CanUseBackupBar()
    return GetUnitLevel("player") >= GetWeaponSwapUnlockedLevel()
end

local function UpdateBackBar(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    -- Hide back bar if player hasn't unlocked weapon swap yet
    if not CanUseBackupBar() then
        backBarContainer:SetHidden(true)
        return
    end
    
    local activePair = GetActiveWeaponPairInfo()
    local backBarCategory = (activePair == ACTIVE_WEAPON_PAIR_MAIN) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    
    -- Get opacity setting for back bar dimming
    local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
    local backBarOpacity = settings.backBarOpacity or 1
    
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
                    -- Apply dimming opacity to icon
                    iconControl:SetAlpha(backBarOpacity)
                else
                    iconControl:SetHidden(true)
                end
            end
            
            -- Also apply opacity to backdrop and border for consistent dimming
            local backdrop = btn:GetNamedChild("Backdrop")
            if backdrop then backdrop:SetAlpha(backBarOpacity) end
            
            local border = btn:GetNamedChild("Border")
            if border then border:SetAlpha(backBarOpacity) end
            
            -- Store slot reference for tooltips
            btn.slotIndex = slotIndex
            btn.hotbarCategory = backBarCategory
        end
    end
    
    backBarContainer:SetHidden(false)
end

-- Update back bar layout to match front bar sizing exactly
local function UpdateBackBarLayout(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    local isGamePad = IsInGamepadPreferredMode()
    local slotsConfig = isGamePad and BETTERUI_ORB_FRAMES.slots.gamepad or BETTERUI_ORB_FRAMES.slots.keyboard
    
    -- Use back bar config if available, fallback to front bar config, then slots config
    local backBarCfg = BETTERUI_ORB_FRAMES.bars.customBackBar
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    
    local backModeConfig = backBarCfg and (isGamePad and backBarCfg.gamepad or backBarCfg.keyboard)
    local frontModeConfig = frontBarCfg and (isGamePad and frontBarCfg.gamepad or frontBarCfg.keyboard)
    
    -- Sizing: back bar config -> front bar config -> slots config
    local buttonSize = (backModeConfig and backModeConfig.buttonSize) or 
                       (frontModeConfig and frontModeConfig.buttonSize) or 
                       slotsConfig.width
    local spacing = (backModeConfig and backModeConfig.spacing) or 
                    (frontModeConfig and frontModeConfig.spacing) or 
                    slotsConfig.spacing
    local ultimateSize = (backModeConfig and backModeConfig.ultimateSize) or 
                         (frontModeConfig and frontModeConfig.ultimateSize) or 
                         (buttonSize + 6)
    local ultimateGap = BETTERUI_ORB_FRAMES.bars.ultimateGap
    
    -- Icon size matches front bar (buttonSize - 3 for visual consistency)
    local iconSize = buttonSize - 3
    local ultIconSize = ultimateSize - 3
    
    -- Calculate total width: 5 skills + ultimate + gaps
    local totalWidth = (5 * buttonSize) + (4 * spacing) + ultimateGap + ultimateSize
    local halfWidth = totalWidth / 2
    
    backBarContainer:SetDimensions(totalWidth, buttonSize)
    
    -- Position and size normal skill buttons (slots 1-5 = Button1-Button5)
    for i = 1, 5 do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            btn:SetDimensions(buttonSize, buttonSize)
            btn:ClearAnchors()
            if i == 1 then
                btn:SetAnchor(LEFT, backBarContainer, CENTER, -halfWidth, 0)
            else
                local prevBtn = FindControl(backBarContainer, 'Button' .. (i-1))
                btn:SetAnchor(LEFT, prevBtn, RIGHT, spacing, 0)
            end
            
            -- Resize Icon to match front bar sizing (buttonSize - 3)
            local icon = btn:GetNamedChild("Icon")
            if icon then
                icon:ClearAnchors()
                icon:SetDimensions(iconSize, iconSize)
                icon:SetAnchor(CENTER, btn, CENTER, 0, 0)
            end

            -- Toggle Visuals (Border vs Backdrop)
            local border = btn:GetNamedChild("Border")
            local backdrop = btn:GetNamedChild("Backdrop")
            
            if isGamePad then
                if border then border:SetHidden(true) end
                if backdrop then backdrop:SetHidden(false) end
            else
                if border then border:SetHidden(false) end
                if backdrop then backdrop:SetHidden(true) end
            end
        end
    end
    
    -- Position ultimate button (Button6 = slot 8)
    local ultBtn = FindControl(backBarContainer, 'Button6')
    if ultBtn then
        local btn5 = FindControl(backBarContainer, 'Button5')
        
        -- Get ultimate offset from back bar config
        local ultOffsetX = (backBarCfg and backBarCfg.ultimate and backBarCfg.ultimate.offsetX) or 0
        local ultOffsetY = (backBarCfg and backBarCfg.ultimate and backBarCfg.ultimate.offsetY) or 0
        
        ultBtn:SetDimensions(ultimateSize, ultimateSize)
        ultBtn:ClearAnchors()
        ultBtn:SetAnchor(LEFT, btn5, RIGHT, ultimateGap + BETTERUI_ORB_FRAMES.bars.backUltimateOffsetX + ultOffsetX, ultOffsetY)
        
        -- Resize Icon to match front bar sizing (ultimateSize - 3)
        local icon = ultBtn:GetNamedChild("Icon")
        if icon then
            icon:ClearAnchors()
            icon:SetDimensions(ultIconSize, ultIconSize)
            icon:SetAnchor(CENTER, ultBtn, CENTER, 0, 0)
        end

        -- Toggle Visuals (Border vs Backdrop)
        local border = ultBtn:GetNamedChild("Border")
        local backdrop = ultBtn:GetNamedChild("Backdrop")
            
        if isGamePad then
            if border then border:SetHidden(true) end
            if backdrop then backdrop:SetHidden(false) end
        else
            if border then border:SetHidden(false) end
            if backdrop then backdrop:SetHidden(true) end
        end
    end
end

-- Setup tooltip handlers for back bar buttons
local function SetupBackBarTooltips(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    -- Slots 3-7 are skills, 8 is Ultimate
    local slots = {3, 4, 5, 6, 7, 8}
    
    for i, slotIndex in ipairs(slots) do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            btn:SetMouseEnabled(true)
            btn:SetHandler("OnMouseEnter", function(control)
                local category = control.hotbarCategory
                local slot = control.slotIndex or slotIndex
                if category then
                    -- Only show tooltip if slot has an ability
                    local slotType = GetSlotType(slot, category)
                    if slotType and slotType ~= ACTION_TYPE_NOTHING then
                        InitializeTooltip(AbilityTooltip, control, RIGHT, -5, 0)
                        AbilityTooltip:SetAction(slot, category)
                    end
                end
            end)
            btn:SetHandler("OnMouseExit", function(control)
                ClearTooltip(AbilityTooltip)
            end)
        end
    end
end

local function UpdateBackBarCooldowns(rootFrame)
    local activePair = GetActiveWeaponPairInfo()
    local backBarCategory = (activePair == ACTIVE_WEAPON_PAIR_MAIN) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    -- Slots 3-7 are skills, 8 is Ultimate
    local slots = {3, 4, 5, 6, 7, 8}
    
    for i, slotIndex in ipairs(slots) do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            -- Get the XML-defined controls
            local cooldownOverlay = btn:GetNamedChild("CooldownOverlay")
            local cooldownText = btn:GetNamedChild("CooldownText")
            local icon = btn:GetNamedChild("Icon")
            
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
            
            if cooldownOverlay and cooldownText then
                if showCooldown and remaining > 0.1 then
                    -- Show static overlay (no animation - just visibility toggle)
                    cooldownOverlay:SetHidden(false)
                    
                    -- Dim the skill icon during cooldown
                    if icon then
                        icon:SetDesaturation(1)
                    end
                    
                    cooldownText:SetHidden(false)
                                        
                    -- Always show decimal for consistency with front bar
                    cooldownText:SetText(string.format("%.1f", remaining))
                else
                    -- Hide overlay and text
                    cooldownOverlay:SetHidden(true)
                    cooldownText:SetHidden(true)
                    
                    -- Restore icon brightness when cooldown ends
                    if icon then
                        icon:SetDesaturation(0)
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------------------------
-- CUSTOM FRONT BAR FUNCTIONS
-- These functions manage the custom front bar that replaces the native ZO_ActionBar1
-------------------------------------------------------------------------------------------------

-- Hide the native action bar completely
local function HideNativeActionBar()
    if ZO_ActionBar1 and ZO_ActionBar1.SetHidden then
        ZO_ActionBar1:SetHidden(true)
        if ZO_ActionBar1.SetAlpha then
            ZO_ActionBar1:SetAlpha(0)
        end
    end
    -- Also hide the timer bar if it exists
    if ZO_ActionBarTimer and ZO_ActionBarTimer.SetHidden then
        ZO_ActionBarTimer:SetHidden(true)
    end
end

-- Show the native action bar (when custom is disabled)
local function ShowNativeActionBar()
    if ZO_ActionBar1 and ZO_ActionBar1.SetHidden then
        ZO_ActionBar1:SetHidden(false)
        if ZO_ActionBar1.SetAlpha then
            ZO_ActionBar1:SetAlpha(1)
        end
    end
    if ZO_ActionBarTimer and ZO_ActionBarTimer.SetHidden then
        ZO_ActionBarTimer:SetHidden(false)
    end
end


-- Update front bar button icons and state
local function UpdateFrontBar(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
    local activeCategory = GetActiveHotbarCategory()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    -- Slots 3-7 are skills, 8 is Ultimate
    local slotMapping = {
        {buttonName = "Button1", slot = 3},
        {buttonName = "Button2", slot = 4},
        {buttonName = "Button3", slot = 5},
        {buttonName = "Button4", slot = 6},
        {buttonName = "Button5", slot = 7},
        {buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1},
    }
    
    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            local iconControl = btn:GetNamedChild("Icon")
            local slotTexture = GetSlotTexture(mapping.slot, activeCategory)
            
            if iconControl then
                if slotTexture and slotTexture ~= "" then
                    iconControl:SetTexture(slotTexture)
                    iconControl:SetHidden(false)
                else
                    iconControl:SetHidden(true)
                end
            end
            
            -- Store slot reference for future use
            btn.slotIndex = mapping.slot
            btn.hotbarCategory = activeCategory
            
            -- Update activation highlight (procs)
            -- Check usability before showing highlight (matches native ESO behavior)
            -- This prevents skills requiring a target from highlighting when no target exists
            local highlight = btn:GetNamedChild("ActivationHighlight")
            if highlight then
                -- Skip highlight updates while player is casting/channeling
                -- This prevents the flash-then-dim behavior during abilities like Biting Jabs
                local isCasting = m_castBar and m_castBar.isCasting
                
                if not isCasting then
                    local hasHighlight = ActionSlotHasActivationHighlight(mapping.slot, activeCategory)
                    
                    -- Only show highlight if skill is usable (no cost or state failures)
                    -- State failures include: no target when target required, range checks, etc.
                    local hasCostFailure = ActionSlotHasCostFailure(mapping.slot, activeCategory)
                    local hasStateFailure = ActionSlotHasNonCostStateFailure(mapping.slot, activeCategory)
                    local isUsable = not hasCostFailure and not hasStateFailure
                    
                    local showHighlight = hasHighlight and isUsable
                    highlight:SetHidden(not showHighlight)
                end
                -- When casting, keep highlight in its current state (don't update it)
            end
        end
    end
    
    frontBarContainer:SetHidden(false)
end

-- Update front bar usability state (called periodically for smooth updates)
-- This handles cost failures, state failures, and target requirements
local function UpdateFrontBarUsability(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
    local activeCategory = GetActiveHotbarCategory()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local slotMapping = {
        {buttonName = "Button1", slot = 3},
        {buttonName = "Button2", slot = 4},
        {buttonName = "Button3", slot = 5},
        {buttonName = "Button4", slot = 6},
        {buttonName = "Button5", slot = 7},
        {buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1},
    }
    
    -- Skip usability updates while player is casting/channeling
    -- This prevents visual flickering during abilities like Biting Jabs
    local isCasting = m_castBar and m_castBar.isCasting
    if isCasting then return end
    
    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            local iconControl = btn:GetNamedChild("Icon")
            local unusableOverlay = btn:GetNamedChild("UnusableOverlay")
            
            if iconControl and not iconControl:IsHidden() then
                -- Check standard usability (cost and state failures)
                local hasCostFailure = ActionSlotHasCostFailure(mapping.slot, activeCategory)
                local hasStateFailure = ActionSlotHasNonCostStateFailure(mapping.slot, activeCategory)
                
                -- Determine if unusable
                local unusable = hasCostFailure or hasStateFailure
                
                -- Check if skill is on cooldown (cooldown function handles that overlay)
                local remainMs, durationMs = GetSlotCooldownInfo(mapping.slot, activeCategory)
                local hasActiveCooldown = remainMs and durationMs and remainMs > 0 and durationMs > 0
                
                -- Apply dark overlay for unusable skills (only if not on cooldown already)
                if unusable and not hasActiveCooldown then
                    -- Show dark overlay (no desaturation - let overlay handle the visual)
                    if unusableOverlay then
                        unusableOverlay:SetHidden(false)
                    end
                else
                    -- Hide unusable overlay
                    if unusableOverlay then
                        unusableOverlay:SetHidden(true)
                    end
                end
            end
        end
    end
end


-- Update ultimate resource meter display using native ESO sprite sheet animation
-- The gp_UltimateFill_512.dds sprite sheet has 8 columns x 4 rows = 32 frames
local function UpdateFrontBarUltimateMeter(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    -- Sprite sheet configuration: 8 columns x 4 rows = 32 frames
    local CELLS_WIDE = 8
    local CELLS_HIGH = 4
    local TOTAL_FRAMES = CELLS_WIDE * CELLS_HIGH  -- 32
    
    -- Helper function to set texture coordinates based on frame
    local function SetSpriteFrame(texture, frameIndex, mirror)
        if not texture then return end
        
        -- Calculate row and column (0-indexed)
        local col = frameIndex % CELLS_WIDE
        local row = math.floor(frameIndex / CELLS_WIDE)
        
        -- Calculate texture coordinates (0.0 to 1.0)
        local cellWidth = 1.0 / CELLS_WIDE
        local cellHeight = 1.0 / CELLS_HIGH
        
        local left = col * cellWidth
        local right = left + cellWidth
        local top = row * cellHeight
        local bottom = top + cellHeight
        
        -- Mirror for right side
        if mirror then
            local temp = left
            left = right
            right = temp
        end
        
        texture:SetTextureCoords(left, right, top, bottom)
    end
    
    -- Update player ultimate meter
    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local fillLeft = ultBtn:GetNamedChild("FillAnimationLeft")
        local fillRight = ultBtn:GetNamedChild("FillAnimationRight")
        
        if fillLeft and fillRight then
            local slotIndex = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
            local activeCategory = GetActiveHotbarCategory()
            local abilityCost = GetSlotAbilityCost(slotIndex, activeCategory)
            local currentUltimate, maxUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE)
            
            if abilityCost and abilityCost > 0 then
                -- Calculate fill percentage (capped at 100%)
                local fillPercent = math.min(1, currentUltimate / abilityCost)
                
                -- Calculate which frame to show (0 to 31)
                local frameIndex = math.floor(fillPercent * (TOTAL_FRAMES - 1))
                
                -- Set sprite coordinates for both left and right textures
                SetSpriteFrame(fillLeft, frameIndex, false)
                SetSpriteFrame(fillRight, frameIndex, true)
                
                -- Show fill textures (they animate based on fill %)
                fillLeft:SetHidden(false)
                fillRight:SetHidden(false)
            else
                -- No ability slotted or no cost - hide fill
                fillLeft:SetHidden(true)
                fillRight:SetHidden(true)
            end
        end
    end
    
    -- Update companion ultimate meter (same logic)
    local compBtn = FindControl(frontBarContainer, 'CompanionButton')
    if compBtn and not compBtn:IsHidden() then
        local fillLeft = compBtn:GetNamedChild("FillAnimationLeft")
        local fillRight = compBtn:GetNamedChild("FillAnimationRight")
        
        if fillLeft and fillRight then
            local iconControl = compBtn:GetNamedChild("Icon")
            if iconControl and not iconControl:IsHidden() then
                local slotIndex = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
                local abilityCost = GetSlotAbilityCost(slotIndex, HOTBAR_CATEGORY_COMPANION)
                local currentUltimate, maxUltimate = GetUnitPower("companion", POWERTYPE_ULTIMATE)
                
                if abilityCost and abilityCost > 0 then
                    local fillPercent = math.min(1, currentUltimate / abilityCost)
                    local frameIndex = math.floor(fillPercent * (TOTAL_FRAMES - 1))
                    
                    SetSpriteFrame(fillLeft, frameIndex, false)
                    SetSpriteFrame(fillRight, frameIndex, true)
                    
                    fillLeft:SetHidden(false)
                    fillRight:SetHidden(false)
                else
                    fillLeft:SetHidden(true)
                    fillRight:SetHidden(true)
                end
            else
                fillLeft:SetHidden(true)
                fillRight:SetHidden(true)
            end
        end
    end
end


-- Setup tooltip handlers for front bar buttons
local function SetupFrontBarTooltips(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local activeCategory = GetActiveHotbarCategory()
    
    -- Skill buttons 1-5
    local slotMapping = {
        {buttonName = "Button1", slot = 3},
        {buttonName = "Button2", slot = 4},
        {buttonName = "Button3", slot = 5},
        {buttonName = "Button4", slot = 6},
        {buttonName = "Button5", slot = 7},
        {buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1},
    }
    
    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            btn:SetMouseEnabled(true)
            btn:SetHandler("OnMouseEnter", function(control)
                local category = control.hotbarCategory or GetActiveHotbarCategory()
                local slotIndex = control.slotIndex or mapping.slot
                -- Only show tooltip if slot has an ability
                local slotType = GetSlotType(slotIndex, category)
                if slotType and slotType ~= ACTION_TYPE_NOTHING then
                    InitializeTooltip(AbilityTooltip, control, RIGHT, -5, 0)
                    AbilityTooltip:SetAction(slotIndex, category)
                end
            end)
            btn:SetHandler("OnMouseExit", function(control)
                ClearTooltip(AbilityTooltip)
            end)
        end
    end
    
    -- Quickslot tooltip
    local qsBtn = FindControl(frontBarContainer, 'QuickslotButton')
    if qsBtn then
        qsBtn:SetMouseEnabled(true)
        qsBtn:SetHandler("OnMouseEnter", function(control)
            local slotIndex = control.slotIndex or GetCurrentQuickslot()
            -- Only show tooltip if quickslot has an item/ability
            local slotType = GetSlotType(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            if slotType and slotType ~= ACTION_TYPE_NOTHING then
                InitializeTooltip(ItemTooltip, control, RIGHT, -5, 0)
                ItemTooltip:SetAction(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            end
        end)
        qsBtn:SetHandler("OnMouseExit", function(control)
            ClearTooltip(ItemTooltip)
        end)
    end
    
    -- Companion ultimate tooltip
    local compBtn = FindControl(frontBarContainer, 'CompanionButton')
    if compBtn then
        compBtn:SetMouseEnabled(true)
        compBtn:SetHandler("OnMouseEnter", function(control)
            local slotIndex = control.slotIndex or (ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)
            -- Only show tooltip if companion has ultimate assigned
            local slotType = GetSlotType(slotIndex, HOTBAR_CATEGORY_COMPANION)
            if slotType and slotType ~= ACTION_TYPE_NOTHING then
                InitializeTooltip(AbilityTooltip, control, RIGHT, -5, 0)
                AbilityTooltip:SetAction(slotIndex, HOTBAR_CATEGORY_COMPANION)
            end
        end)
        compBtn:SetHandler("OnMouseExit", function(control)
            ClearTooltip(AbilityTooltip)
        end)
    end
end


-- Update front bar cooldowns
local function UpdateFrontBarCooldowns(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
    local activeCategory = GetActiveHotbarCategory()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local isGamepad = IsInGamepadPreferredMode()
    
    local slotMapping = {
        {buttonName = "Button1", slot = 3},
        {buttonName = "Button2", slot = 4},
        {buttonName = "Button3", slot = 5},
        {buttonName = "Button4", slot = 6},
        {buttonName = "Button5", slot = 7},
        {buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1},
    }
    
    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            local remainMs, durationMs, isGlobal = GetSlotCooldownInfo(mapping.slot, activeCategory)
            local showCooldown = remainMs and remainMs > 0 and durationMs > 1000 and not isGlobal
            
            local cooldown = btn:GetNamedChild("Cooldown")
            local cooldownEdge = btn:GetNamedChild("CooldownEdge")
            local iconControl = btn:GetNamedChild("Icon")
            local timerText = btn:GetNamedChild("TimerText")
            
            if showCooldown then
                -- Desaturate icon
                if iconControl then iconControl:SetDesaturation(1) end
                
                if isGamepad then
                    -- Gamepad: Use bottom edge fill
                    if cooldown then cooldown:SetHidden(true) end
                    if cooldownEdge and iconControl then
                        local percentComplete = 1 - (remainMs / durationMs)
                        local _, iconHeight = iconControl:GetDimensions()
                        local iconWidth = iconControl:GetWidth()
                        local offsetY = (1 - percentComplete) * iconHeight
                        cooldownEdge:ClearAnchors()
                        cooldownEdge:SetAnchor(TOPLEFT, iconControl, TOPLEFT, 0, offsetY)
                        cooldownEdge:SetWidth(iconWidth)
                        cooldownEdge:SetHidden(false)
                    end
                else
                    -- Keyboard: Use radial cooldown
                    if cooldownEdge then cooldownEdge:SetHidden(true) end
                    if cooldown then
                        cooldown:StartCooldown(remainMs, durationMs, CD_TYPE_RADIAL, nil, false)
                        cooldown:SetHidden(false)
                    end
                end
                
                -- Also show timer text - always show decimal
                if timerText then
                    local remaining = remainMs / 1000
                    timerText:SetText(string.format("%.1f", remaining))
                    timerText:SetHidden(false)
                    
                    -- Apply user-configured font size and color (from settings)
                    local settings = GetModuleSettings()
                    local cooldownSize = settings.cooldownTextSize or 27
                    local cooldownColor = settings.cooldownTextColor or {0.86, 0.84, 0.13, 1}
                    timerText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", cooldownSize))
                    timerText:SetColor(unpack(cooldownColor))
                end
            else
                -- Clear cooldown display
                if iconControl then iconControl:SetDesaturation(0) end
                if cooldown then cooldown:SetHidden(true) end
                if cooldownEdge then cooldownEdge:SetHidden(true) end
                if timerText then timerText:SetHidden(true) end
            end
            
            -- Also update effect timers (buff durations)
            local effectRemaining = GetActionSlotEffectTimeRemaining(mapping.slot, activeCategory)
            if effectRemaining and effectRemaining > 1000 and not showCooldown then
                if timerText then
                    local remaining = effectRemaining / 1000
                    -- Always show decimal for consistency
                    timerText:SetText(string.format("%.1f", remaining))
                    timerText:SetHidden(false)
                    
                    -- Apply user-configured font size and color (from settings)
                    local settings = GetModuleSettings()
                    local cooldownSize = settings.cooldownTextSize or 27
                    local cooldownColor = settings.cooldownTextColor or {0.86, 0.84, 0.13, 1}
                    timerText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", cooldownSize))
                    timerText:SetColor(unpack(cooldownColor))
                end
            end
            
            -- Update stack count
            local stackCountText = btn:GetNamedChild("StackCountText")
            if stackCountText then
                local stackCount = GetActionSlotEffectStackCount(mapping.slot, activeCategory)
                if stackCount and stackCount > 0 then
                    stackCountText:SetText(stackCount)
                    stackCountText:SetHidden(false)
                else
                    stackCountText:SetHidden(true)
                end
            end
        end
    end
end

-- Update front bar layout and positioning
local function UpdateFrontBarLayout(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local isGamePad = IsInGamepadPreferredMode()
    local slotsConfig = isGamePad and BETTERUI_ORB_FRAMES.slots.gamepad or BETTERUI_ORB_FRAMES.slots.keyboard
    local modeConfig = isGamePad and frontBarCfg.gamepad or frontBarCfg.keyboard
    
    local buttonSize = modeConfig.buttonSize or slotsConfig.width
    local spacing = modeConfig.spacing or slotsConfig.spacing
    local ultimateSize = modeConfig.ultimateSize or (buttonSize + 6)
    local ultimateGap = BETTERUI_ORB_FRAMES.bars.ultimateGap
    
    -- Calculate total width: 5 skills + ultimate + gaps
    local totalWidth = (5 * buttonSize) + (4 * spacing) + ultimateGap + ultimateSize
    local halfWidth = totalWidth / 2
    
    frontBarContainer:SetDimensions(totalWidth, ultimateSize)
    
    -- Position normal skill buttons
    for i = 1, 5 do
        local btn = FindControl(frontBarContainer, 'Button' .. i)
        if btn then
            btn:SetDimensions(buttonSize, buttonSize)
            btn:ClearAnchors()
            if i == 1 then
                btn:SetAnchor(LEFT, frontBarContainer, CENTER, -halfWidth, 0)
            else
                local prevBtn = FindControl(frontBarContainer, 'Button' .. (i-1))
                btn:SetAnchor(LEFT, prevBtn, RIGHT, spacing, 0)
            end
            
            -- Also resize FlipCard and Icon
            local flipCard = btn:GetNamedChild("FlipCard")
            if flipCard then
                local innerSize = buttonSize - 3
                flipCard:SetDimensions(innerSize, innerSize)
            end
            local icon = btn:GetNamedChild("Icon")
            if icon then
                local innerSize = buttonSize - 3
                icon:SetDimensions(innerSize, innerSize)
            end
        end
    end
    
    -- Position ultimate button
    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local btn5 = FindControl(frontBarContainer, 'Button5')
        local ultOffsetX = frontBarCfg.ultimate.offsetX or 0
        local ultOffsetY = frontBarCfg.ultimate.offsetY or 0
        
        ultBtn:SetDimensions(ultimateSize, ultimateSize)
        ultBtn:ClearAnchors()
        ultBtn:SetAnchor(LEFT, btn5, RIGHT, ultimateGap + ultOffsetX, ultOffsetY)
        
        local flipCard = ultBtn:GetNamedChild("FlipCard")
        if flipCard then
            local innerSize = ultimateSize - 3
            flipCard:SetDimensions(innerSize, innerSize)
        end
        local icon = ultBtn:GetNamedChild("Icon")
        if icon then
            local innerSize = ultimateSize - 3
            icon:SetDimensions(innerSize, innerSize)
        end
    end
    
    -- Position quickslot button
    local qsBtn = FindControl(frontBarContainer, 'QuickslotButton')
    if qsBtn then
        local quickslotCfg = frontBarCfg.quickslotButton
        local baseX = BETTERUI_ORB_FRAMES.bars.quickslot.x
        local baseY = BETTERUI_ORB_FRAMES.bars.quickslot.y
        local offsetX = quickslotCfg.offsetX or 0
        local offsetY = quickslotCfg.offsetY or 0
        
        local bgMiddle = FindControl(rootFrame, 'BgMiddle')
        qsBtn:SetDimensions(buttonSize, buttonSize)
        qsBtn:ClearAnchors()
        if bgMiddle then
            qsBtn:SetAnchor(CENTER, bgMiddle, BOTTOM, baseX + offsetX, baseY + offsetY)
        end
    end
    
    -- Position companion button
    local compBtn = FindControl(frontBarContainer, 'CompanionButton')
    if compBtn then
        local companionCfg = frontBarCfg.companionButton
        local baseX = BETTERUI_ORB_FRAMES.bars.companionUltimate.x
        local baseY = BETTERUI_ORB_FRAMES.bars.companionUltimate.y
        local offsetX = companionCfg.offsetX or 0
        local offsetY = companionCfg.offsetY or 0
        
        local bgMiddle = FindControl(rootFrame, 'BgMiddle')
        compBtn:SetDimensions(ultimateSize, ultimateSize)
        compBtn:ClearAnchors()
        if bgMiddle then
            compBtn:SetAnchor(CENTER, bgMiddle, BOTTOM, baseX + offsetX, baseY + offsetY)
        end
    end
    
    -- Apply overall front bar offset
    local barOffsetX = frontBarCfg.offsetX or 0
    local barOffsetY = frontBarCfg.offsetY or 0
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    if bgMiddle then
        frontBarContainer:ClearAnchors()
        -- Position front bar below back bar: more negative Y = lower
        frontBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, barOffsetX + 10, -15 + barOffsetY)
    end
end

-- Update quickslot on front bar
local function UpdateFrontBarQuickslot(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local qsBtn = FindControl(frontBarContainer, 'QuickslotButton')
    if not qsBtn then return end
    
    local slotIndex = GetCurrentQuickslot()
    local icon = GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    local iconControl = qsBtn:GetNamedChild("Icon")
    
    if iconControl then
        if icon and icon ~= "" then
            iconControl:SetTexture(icon)
            iconControl:SetHidden(false)
        else
            iconControl:SetHidden(true)
        end
    end
    
    -- Update item count
    local countText = qsBtn:GetNamedChild("CountText")
    if countText then
        local count = GetSlotItemCount(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if count and count > 0 then
            countText:SetText(count)
            countText:SetHidden(false)
        else
            countText:SetHidden(true)
        end
    end
    
    qsBtn.slotIndex = slotIndex
    qsBtn.hotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
end

-- Update companion ultimate on front bar
local function UpdateFrontBarCompanion(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local compBtn = FindControl(frontBarContainer, 'CompanionButton')
    if not compBtn then return end
    
    local companionActive = DoesUnitExist("companion") and HasActiveCompanion()
    
    if companionActive then
        compBtn:SetHidden(false)
        
        local slotIndex = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
        local icon = GetSlotTexture(slotIndex, HOTBAR_CATEGORY_COMPANION)
        local iconControl = compBtn:GetNamedChild("Icon")
        
        -- Show icon if skill assigned, hide icon (but show frame) if not
        if iconControl then
            if icon and icon ~= "" then
                iconControl:SetTexture(icon)
                iconControl:SetHidden(false)
            else
                -- No skill - hide icon but keep frame visible (transparent inside)
                iconControl:SetHidden(true)
            end
        end
        
        compBtn.slotIndex = slotIndex
        compBtn.hotbarCategory = HOTBAR_CATEGORY_COMPANION
    else
        compBtn:SetHidden(true)
    end
end


-- Setup keybind labels for front bar buttons
local function SetupFrontBarKeybinds(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local HIDE_UNBOUND = false
    
    -- Skill buttons use ACTION_BUTTON_3 through ACTION_BUTTON_7
    local slotBindings = {
        [1] = {keyboard = "ACTION_BUTTON_3", gamepad = "GAMEPAD_ACTION_BUTTON_3"},
        [2] = {keyboard = "ACTION_BUTTON_4", gamepad = "GAMEPAD_ACTION_BUTTON_4"},
        [3] = {keyboard = "ACTION_BUTTON_5", gamepad = "GAMEPAD_ACTION_BUTTON_5"},
        [4] = {keyboard = "ACTION_BUTTON_6", gamepad = "GAMEPAD_ACTION_BUTTON_6"},
        [5] = {keyboard = "ACTION_BUTTON_7", gamepad = "GAMEPAD_ACTION_BUTTON_7"},
    }
    
    for i = 1, 5 do
        local btn = FindControl(frontBarContainer, 'Button' .. i)
        if btn then
            local buttonText = btn:GetNamedChild("ButtonText")
            if buttonText then
                local bindings = slotBindings[i]
                ZO_Keybindings_RegisterLabelForBindingUpdate(
                    buttonText, 
                    bindings.keyboard, 
                    HIDE_UNBOUND, 
                    bindings.gamepad
                )
            end
        end
    end
    
    -- Ultimate button uses ACTION_BUTTON_8 (LB+RB in gamepad)
    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local buttonText = ultBtn:GetNamedChild("ButtonText")
        if buttonText then
            ZO_Keybindings_RegisterLabelForBindingUpdate(
                buttonText, "ACTION_BUTTON_8", HIDE_UNBOUND, "GAMEPAD_ACTION_BUTTON_8"
            )
        end
        
        -- Show/hide LB+RB textures based on gamepad mode
        local isGamepad = IsInGamepadPreferredMode()
        local leftKeybind = ultBtn:GetNamedChild("LeftKeybind")
        local rightKeybind = ultBtn:GetNamedChild("RightKeybind")
        if leftKeybind then leftKeybind:SetHidden(not isGamepad) end
        if rightKeybind then rightKeybind:SetHidden(not isGamepad) end
    end
    
    -- Quickslot uses ACTION_BUTTON_9
    local qsBtn = FindControl(frontBarContainer, 'QuickslotButton')
    if qsBtn then
        local buttonText = qsBtn:GetNamedChild("ButtonText")
        if buttonText then
            ZO_Keybindings_RegisterLabelForBindingUpdate(
                buttonText, "ACTION_BUTTON_9", HIDE_UNBOUND, "GAMEPAD_ACTION_BUTTON_9"
            )
            -- Keep ButtonText (keybind LB) at default position (bottom of button)
        end
        
        -- Reposition CountText (quantity) inside the button, above keybind, centered
        local countText = qsBtn:GetNamedChild("CountText")
        if countText then
            countText:ClearAnchors()
            -- Position inside button, centered horizontally, just above keybind area (2px gap)
            countText:SetAnchor(BOTTOM, qsBtn, BOTTOM, 0, -4)
            countText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        end
    end
    
    -- Companion uses COMMAND_PET
    local compBtn = FindControl(frontBarContainer, 'CompanionButton')
    if compBtn then
        local buttonText = compBtn:GetNamedChild("ButtonText")
        if buttonText then
            ZO_Keybindings_RegisterLabelForBindingUpdate(
                buttonText, "COMMAND_PET", HIDE_UNBOUND, "COMMAND_PET"
            )
        end
        
        -- Show LB+RB for companion in gamepad mode too
        local isGamepad = IsInGamepadPreferredMode()
        local leftKeybind = compBtn:GetNamedChild("LeftKeybind")
        local rightKeybind = compBtn:GetNamedChild("RightKeybind")
        if leftKeybind then leftKeybind:SetHidden(not isGamepad) end
        if rightKeybind then rightKeybind:SetHidden(not isGamepad) end
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

-- Update quickslot and companion ultimate positioning
-- Both are positioned relative to BgMiddle (center), allowing centering between front and back bars
-- Quickslot: always visible, to the right of ultimates
-- Companion ultimate: only visible when companion is active, on the left side
local function UpdateQuickslotAndCompanionPositioning(rootFrame)
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    
    local quickSlotButton = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    local companionButton = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION)
    
    -- Use same check as native ESO code: DoesUnitExist("companion") AND HasActiveCompanion()
    local companionActive = DoesUnitExist("companion") and HasActiveCompanion()
    local cfg = BETTERUI_ORB_FRAMES.bars
    
    -- Quickslot: positioned relative to BgMiddle (centered between bars, to the right of ultimates)
    if quickSlotButton and quickSlotButton.slot and bgMiddle then
        quickSlotButton.slot:SetHidden(false)
        quickSlotButton.slot:ClearAnchors()
        quickSlotButton.slot:SetAnchor(CENTER, bgMiddle, BOTTOM,
            cfg.quickslot.x,
            cfg.quickslot.y)
    end
    
    -- Companion ultimate: positioned relative to BgMiddle (centered between bars, on the left side)
    if companionButton and companionButton.slot then
        if companionActive and bgMiddle then
            companionButton.slot:SetHidden(false)
            companionButton.slot:ClearAnchors()
            companionButton.slot:SetAnchor(CENTER, bgMiddle, BOTTOM,
                cfg.companionUltimate.x,
                cfg.companionUltimate.y)
        else
            companionButton.slot:SetHidden(true)
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
    
    -- Get the BetterUI ActionBarContainer (for our back bar positioning reference)
    local barParent = FindControl(rootFrame, 'ActionBarContainer')
    if not barParent then return end
    
    barParent:SetDimensions(totalWidth, width)
    
    -- IMPORTANT: We do NOT manipulate ZO_ActionBar1's anchors.
    -- ESO's ApplyStyle resets anchors during weapon swaps and companion changes.
    -- We only set SCALE, which ESO does not reset.
    -- The native bar will use ESO's default positioning, and we position
    -- our ResourceOrbFrames container to align with it.
    
    -- Hide weapon swap control - we don't need it for dual bar view
    if ZO_ActionBar1WeaponSwap then
        ZO_ActionBar1WeaponSwap:SetHidden(true)
    end
    
    -- Position quickslot and companion ultimate based on companion state
    UpdateQuickslotAndCompanionPositioning(rootFrame)
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
    
    -- Apply customBackBar offsets if configured
    local backBarCfg = bars.customBackBar
    local backBarOffsetX = (backBarCfg and backBarCfg.offsetX) or 0
    local backBarOffsetY = (backBarCfg and backBarCfg.offsetY) or 0
    
    actionBarContainer:ClearAnchors()
    backBarContainer:ClearAnchors()
    actionBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, bottomX, bottomY)
    backBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, topX + backBarOffsetX, topY + backBarOffsetY)
end

local function SetupNativeBackBar(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    -- Check if custom front bar is enabled
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    local useCustomFrontBar = frontBarCfg and frontBarCfg.enabled
    
    -- Unified layout update function
    local function ApplyFullLayout()
        UpdateBackBar(rootFrame)
        UpdateBackBarLayout(rootFrame)
        UpdateMainBarLayout(rootFrame)
        UpdateBarPositions(rootFrame)
        UpdateFrameDimensions() -- Keeps scale in sync
        UpdateFrontBarCooldownColors()
        
        -- Custom front bar updates
        if useCustomFrontBar then
            UpdateFrontBarLayout(rootFrame)
            UpdateFrontBar(rootFrame)
            UpdateFrontBarQuickslot(rootFrame)
            UpdateFrontBarCompanion(rootFrame)
            UpdateFrontBarUltimateMeter(rootFrame)
        end
    end

    -- Initial setup
    if useCustomFrontBar then
        HideNativeActionBar()
        SetupFrontBarKeybinds(rootFrame)
        SetupFrontBarTooltips(rootFrame)
    end
    ApplyFullLayout()
    
    -- Setup back bar tooltips (always enabled for back bar)
    SetupBackBarTooltips(rootFrame)
    
    -- ========================================
    -- SIMPLIFIED EVENT HANDLERS
    -- ========================================
    
    -- Weapon swap: Wait for animation (approx 400ms) then re-apply layout/scale
    EVENT_MANAGER:RegisterForEvent(NAME .. "BackBar", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function() 
        UpdateBackBar(rootFrame)
        if useCustomFrontBar then
            UpdateFrontBar(rootFrame)
        end
        -- Short delay to let ESO start animation, then force layout logic at end
        zo_callLater(ApplyFullLayout, 500)
    end)
    
    -- Slot updates: Immediate update
    EVENT_MANAGER:RegisterForEvent(NAME .. "BackBarSlots", EVENT_ACTION_SLOTS_FULL_UPDATE, function() 
        UpdateBackBar(rootFrame)
        if useCustomFrontBar then
            UpdateFrontBar(rootFrame)
        end
        ApplyFullLayout()
    end)
    
    EVENT_MANAGER:RegisterForEvent(NAME .. "BackBarSlot", EVENT_ACTION_SLOT_UPDATED, function() 
        UpdateBackBar(rootFrame)
        if useCustomFrontBar then
            UpdateFrontBar(rootFrame)
        end
    end)
    
    -- Companion state changes: triggers ESO SetCompanionAnchors
    -- We wait a moment for ESO to finish its anchor changes
    EVENT_MANAGER:RegisterForEvent(NAME .. "CompanionState", EVENT_ACTIVE_COMPANION_STATE_CHANGED, function()
        if useCustomFrontBar then
            UpdateFrontBarCompanion(rootFrame)
        else
            UpdateQuickslotAndCompanionPositioning(rootFrame)
        end
        zo_callLater(ApplyFullLayout, 200)
    end)
    
    -- Quickslot changed event
    EVENT_MANAGER:RegisterForEvent(NAME .. "Quickslot", EVENT_ACTIVE_QUICKSLOT_CHANGED, function()
        if useCustomFrontBar then
            UpdateFrontBarQuickslot(rootFrame)
        end
    end)
    
    -- Update cooldowns, usability, and ultimate meter periodically
    local function CooldownTick()
        UpdateBackBarCooldowns(rootFrame)
        if useCustomFrontBar then
            UpdateFrontBarCooldowns(rootFrame)
            UpdateFrontBarUsability(rootFrame)
            UpdateFrontBarUltimateMeter(rootFrame)
        end
    end
    EVENT_MANAGER:RegisterForUpdate(NAME .. "BackBarCooldown", 100, CooldownTick)
    
    -- Re-hide native action bar when HUD scene returns (fixes scene exit issue)
    if useCustomFrontBar then
        -- Register for HUD scene state changes
        local hudScene = SCENE_MANAGER:GetScene("hud")
        if hudScene then
            hudScene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    -- Re-hide native bar and re-apply layout
                    zo_callLater(function()
                        HideNativeActionBar()
                        ApplyFullLayout()
                    end, 50)
                end
            end)
        end
        
        -- Also register for HUD UI scene (gamepad mode uses this)
        local hudUIScene = SCENE_MANAGER:GetScene("hudui")
        if hudUIScene then
            hudUIScene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    zo_callLater(function()
                        HideNativeActionBar()
                        ApplyFullLayout()
                    end, 50)
                end
            end)
        end
    end
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

    -- Companion Ultimate positioning is handled by UpdateQuickslotAndCompanionPositioning
    -- which is called from UpdateMainBarLayout and on EVENT_ACTIVE_COMPANION_STATE_CHANGED

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

-- NOTE: MirrorFogToFog2 method removed - Fog2 is now handled inline in RefreshVisuals with CENTER anchoring

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
        -- Format values with k/M notation (no decimals for k values)
        if self.currentValue >= 1000000 then
            self.label:SetText(string.format("%.1fM", self.currentValue / 1000000))
        elseif self.currentValue >= 1000 then
           self.label:SetText(string.format("%.0fk", self.currentValue / 1000))
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

    -- Use configurable full fill dimensions
    local fullWidth = self.fillWidth or 150
    local fullHeight = self.fillHeight or 150

    -- Calculate the visible height based on fill percentage
    local visibleHeight = (fullHeight * percent) / 100
    local coordTop = 1 - (percent / 100)
    
    -- User-defined offsets (from config)
    local fillOffsetX = self.fillOffsetX or 0
    local fillOffsetY = self.fillOffsetY or 0
    
    -- Check if this is a half-texture (Magicka/Stamina split orb)
    local isHalfTexture = math.abs(math.abs(self.baseCoordRight - self.baseCoordLeft) - 0.5) < 0.001
    
    -- Calculate horizontal offset for half-textures (left or right side of orb)
    local halfOffsetX = 0
    if isHalfTexture then
        local isLeft = (self.baseCoordLeft < self.baseCoordRight)
        -- For half textures, offset by quarter of fullWidth to position on left or right
        halfOffsetX = isLeft and (-fullWidth / 4) or (fullWidth / 4)
    end
    
    -- The key vertical offset: CENTER anchor means we need to push DOWN by half the height difference
    -- to make the fill appear to "grow from the bottom"
    -- When percent=0, visibleHeight=0, offset = fullHeight/2 (pushed down, invisible)
    -- When percent=100, visibleHeight=fullHeight, offset = 0 (centered, fully visible)
    local verticalOffset = (fullHeight - visibleHeight) / 2

    if self.fog then
        self.fog:SetDimensions(fullWidth, visibleHeight)
        self.fog:SetTextureCoords(self.baseCoordLeft, self.baseCoordRight, coordTop, 1)
        self.fog:ClearAnchors()
        -- CRITICAL: Use CENTER anchoring like OrbBorder.dds - this scales correctly
        -- Add baseAnchorX for any base offset (usually 0) + halfOffsetX for split orbs + user offset
        self.fog:SetAnchor(CENTER, self.control, CENTER, 
            self.baseAnchorX + halfOffsetX + fillOffsetX, 
            verticalOffset + fillOffsetY)
    end

    -- Fog2 is the static background layer - always full size, centered
    if self.fog2 ~= nil then
        self.fog2:SetDimensions(fullWidth, fullHeight)
        self.fog2:SetTextureCoords(self.baseCoordLeft, self.baseCoordRight, 0, 1)
        self.fog2:ClearAnchors()
        self.fog2:SetAnchor(CENTER, self.control, CENTER, 
            self.baseAnchorX + halfOffsetX + fillOffsetX, 
            fillOffsetY)
    end
end

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
    
    -- Fill (Rectangular texture) - Create FIRST (Bottom) so it sits BEHIND the backdrop
    -- Uses ESO's built-in rectangular fill texture instead of circular OrbFill.dds
    local fill = WINDOW_MANAGER:CreateControl(name .. "Fill", control, CT_TEXTURE)
    fill:SetTexture(BETTERUI_BAR_FILL_TEXTURE or "esoui/art/miscellaneous/progressbar_genericfill_gloss.dds")
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
    label:SetFont("$(BOLD_FONT)|18|thick-outline")
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
    self.label:SetText(GetString(SI_BETTERUI_LABEL_CAST_BAR))
    
    EVENT_MANAGER:RegisterForEvent(NAME .. "CastStart", EVENT_SPELL_CASTING_START, function(_, unitTag, effectName, _, _, _, duration, startTime, endTime, isChanneled)
        return self:OnCastStart(unitTag, effectName, duration, isChanneled)
    end)

    EVENT_MANAGER:RegisterForEvent(NAME .. "CastStop", EVENT_SPELL_CASTING_STOP, function(_, unitTag, _, _, _, wasInterrupted) 
        return self:OnCastStop(unitTag, wasInterrupted) 
    end)
    
    local function HideDefaultCastBar()
        if ZO_CastingBar then ZO_CastingBar:SetHidden(true) end
        if ZO_PlayerCastingBar then ZO_PlayerCastingBar:SetHidden(true) end
        if ZO_PlayerProgressBar then ZO_PlayerProgressBar:SetHidden(true) end
        if ZO_GamepadPlayerProgressBar then ZO_GamepadPlayerProgressBar:SetHidden(true) end
        if GAMEPAD_PLAYER_PROGRESS_BAR_FRAGMENT then GAMEPAD_PLAYER_PROGRESS_BAR_FRAGMENT:SetHiddenForReason("BetterUICastBar", true) end
    end
    HideDefaultCastBar()
    EVENT_MANAGER:RegisterForEvent(NAME .. "HideDefaultCast", EVENT_PLAYER_ACTIVATED, HideDefaultCastBar)
    
    EVENT_MANAGER:RegisterForEvent(NAME .. "SlotAbilityUsed", EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotIndex)
        local hotbar = GetActiveHotbarCategory()
        local abilityId = GetSlotBoundId(slotIndex, hotbar)
        if not abilityId or abilityId == 0 then return end
        if IsSlotToggled(slotIndex) then return end
        local isChanneled, castTime, channelTime = GetAbilityCastInfo(abilityId)
        local duration = math.max(castTime or 0, channelTime or 0)
        if duration <= 0 then return end
        local name = GetAbilityName(abilityId)
        self:OnCastStart("player", name, duration, isChanneled)
    end)
    
    EVENT_MANAGER:AddFilterForEvent(NAME .. "SlotAbilityUsed", EVENT_ACTION_SLOT_ABILITY_USED, REGISTER_FILTER_UNIT_TAG, "player")

    self.control:SetHandler("OnUpdate", function() self:Update() end)
end

function CastBar:OnCastStart(unitTag, abilityName, castDuration, isChanneled)
    if unitTag ~= "player" then return end
    self.isCasting = true
    self.duration = castDuration / 1000
    self.startTime = GetFrameTimeSeconds()
    self.abilityName = abilityName
    self.isChanneled = isChanneled
    self.control:SetHidden(false)
end

function CastBar:OnCastStop(unitTag, wasInterrupted)
    if unitTag ~= "player" then return end
    self.isCasting = false
    self:Update() 
end

function CastBar:Update()
    local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
    if not settings.castBarEnabled then
        self.control:SetHidden(true)
        return
    end
    
    local w = BETTERUI_CAST_BAR_WIDTH or 250
    local h = BETTERUI_CAST_BAR_HEIGHT or 150
    self.control:SetDimensions(w, h)
    self.control:SetScale(BETTERUI_CAST_BAR_SCALE or 1.0)
    
    -- Set backdrop dimensions for static display
    if self.backdrop then
        self.backdrop:SetDimensions(w, h)
        self.backdrop:ClearAnchors()
        self.backdrop:SetAnchor(CENTER, self.control, CENTER, 0, 0)
    end

    local insetX = BETTERUI_CAST_BAR_FILL_INSET_X or 40
    local insetY = BETTERUI_CAST_BAR_FILL_INSET_Y or 55
    local current, max = 0, 1

    -- Apply text size and color from settings
    local castTextSize = settings.castBarTextSize or 16
    local castTextColor = settings.castBarTextColor or {1, 1, 1, 1}
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", castTextSize))
    self.label:SetColor(unpack(castTextColor))

    -- Apply configurable offset for label
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, 0, BETTERUI_CAST_BAR_LABEL_OFFSET_Y or 0)

    if self.isCasting then
        -- Show bar during casting
        self.control:SetHidden(false)
        if self.fill then self.fill:SetHidden(false) end
        
        local now = GetFrameTimeSeconds()
        local elapsed = now - self.startTime
        local remaining = math.max(0, self.duration - elapsed)
        
        current = remaining
        max = self.duration
        
        if current < 0 then current = 0 end
        if current > max then current = max end
        self.label:SetText(string.format("%s (%.1fs)", self.abilityName or "Casting", remaining))
        
        if elapsed > self.duration + 0.5 then
             self:OnCastStop("player", false)
        end
        
        self:UpdateVisuals(current, max, insetX, insetY, w, h)
    else
        -- Not casting - check alwaysShow setting
        if settings.castBarAlwaysShow then
            -- Show static bar frame with default text
            self.control:SetHidden(false)
            self.label:SetText(GetString(SI_BETTERUI_LABEL_CAST_BAR))
            -- Hide fill when not casting
            if self.fill then self.fill:SetHidden(true) end
        else
            -- Hide bar completely when not casting
            self.control:SetHidden(true)
        end
    end
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
    
    local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
    local isChampion = IsUnitChampion("player")
    local current, max, effectiveMax = 0, 0, 0
    local labelText = ""

    if isChampion then
        local currentCP = GetPlayerChampionPointsEarned()
        current = GetPlayerChampionXP()
        local success, size = pcall(GetNumChampionXPInChampionPoint, currentCP)
        if success and size then max = size else max = 400000 end
        if max <= 0 then max = 1 end
        effectiveMax = max
        local percent = math.floor((current / max) * 100)
        labelText = string.format("CP: %d (%d%%)", currentCP, percent)
    else
        current = GetUnitXP("player")
        max = GetUnitXPMax("player")
        labelText = string.format("XP: %d / %d", current, max)
        effectiveMax = max
    end
    
    -- Apply text size and color from settings
    local xpTextSize = settings.xpBarTextSize or 16
    local xpTextColor = settings.xpBarTextColor or {1, 1, 1, 1}
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", xpTextSize))
    self.label:SetColor(unpack(xpTextColor))
    
    self.label:SetText(labelText)
    
    -- Apply configurable offset
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, 0, BETTERUI_XP_BAR_LABEL_OFFSET_Y or 0)
    
    local insetX = BETTERUI_XP_BAR_FILL_INSET_X or 8
    local insetY = BETTERUI_XP_BAR_FILL_INSET_Y or 4
    local w = BETTERUI_XP_BAR_WIDTH or 250
    local h = BETTERUI_XP_BAR_HEIGHT or 150
    
    self.control:SetDimensions(w, h)
    self.control:SetScale(BETTERUI_XP_BAR_SCALE or 1.0)
    
    self:UpdateVisuals(current, effectiveMax, insetX, insetY, w, h)
end

-------------------------------------------------------------------------------------------------
-- MountStaminaBar Class
-------------------------------------------------------------------------------------------------

local MountStaminaBar = BetterUIBarFrame:Subclass()

function MountStaminaBar:New(parent)
    local obj = ZO_Object.New(self)
    obj:Initialize(parent)
    return obj
end

function MountStaminaBar:Initialize(parent)
    BetterUIBarFrame.Initialize(self, "BetterUIMountStaminaBar", parent)
    self:SetColor(0, 0.8, 0.2, 1) -- Green color matching stamina orb
    self.label:SetText(GetString(SI_BETTERUI_LABEL_MOUNT_STAMINA))
    
    -- Initialize with current mount state (handles reload while mounted)
    if IsMounted() then
        local current, max = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
        self.currentValue = current
        self.maxValue = max
    end
    
    -- Register for mount state changes
    EVENT_MANAGER:RegisterForEvent(NAME .. "MountStaminaMount", EVENT_MOUNTED_STATE_CHANGED, function(_, isMounted)
        self:OnMountedStateChanged(isMounted)
    end)
    
    -- Register for power updates (mount stamina)
    EVENT_MANAGER:RegisterForEvent(NAME .. "MountStaminaPower", EVENT_POWER_UPDATE, function(_, unitTag, powerPoolIndex, powerType, powerValue, powerMax)
        if unitTag == "player" and powerType == COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA then
            self:OnPowerUpdate(powerValue, powerMax)
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(NAME .. "MountStaminaPower", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
    
    self.control:SetHandler("OnUpdate", function() self:Update() end)
end

function MountStaminaBar:OnMountedStateChanged(isMounted)
    -- Just update values when mounting - Update() handles visibility
    if isMounted then
        local current, max = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
        self:OnPowerUpdate(current, max)
    end
    -- Note: We don't hide the bar here - Update() handles that based on settings
end

function MountStaminaBar:OnPowerUpdate(current, max)
    self.currentValue = current
    self.maxValue = max
end

function MountStaminaBar:Update()
    local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
    if not settings.mountStaminaBarEnabled then
        self.control:SetHidden(true)
        return
    end
    
    -- Always show the bar frame when enabled
    local w = BETTERUI_MOUNT_STAMINA_BAR_WIDTH or 250
    local h = BETTERUI_MOUNT_STAMINA_BAR_HEIGHT or 150
    self.control:SetDimensions(w, h)
    self.control:SetScale(BETTERUI_MOUNT_STAMINA_BAR_SCALE or 1.0)
    self.control:SetHidden(false)
    
    -- CRITICAL: Set backdrop dimensions directly so Bar.dds is visible
    if self.backdrop then
        self.backdrop:SetDimensions(w, h)
        self.backdrop:ClearAnchors()
        self.backdrop:SetAnchor(CENTER, self.control, CENTER, 0, 0)
    end
    
    local insetX = BETTERUI_MOUNT_STAMINA_BAR_FILL_INSET_X or 35
    local insetY = BETTERUI_MOUNT_STAMINA_BAR_FILL_INSET_Y or 55
    
    -- Apply text size and color from settings
    local mountTextSize = settings.mountStaminaBarTextSize or 16
    local mountTextColor = settings.mountStaminaBarTextColor or {1, 1, 1, 1}
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", mountTextSize))
    self.label:SetColor(unpack(mountTextColor))
    
    -- Apply configurable offset
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, 0, BETTERUI_MOUNT_STAMINA_BAR_LABEL_OFFSET_Y or 0)
    
    -- Only show fill and percentage when mounted
    if IsMounted() then
        local current = self.currentValue or 0
        local max = self.maxValue or 1
        if max <= 0 then max = 1 end
        
        local percent = math.floor((current / max) * 100)
        self.label:SetText(string.format("Mount: %d%%", percent))
        
        -- Show fill when mounted
        if self.fill then self.fill:SetHidden(false) end
        self:UpdateVisuals(current, max, insetX, insetY, w, h)
    else
        -- Show placeholder text when not mounted
        self.label:SetText(GetString(SI_BETTERUI_LABEL_MOUNT_STAMINA))
        
        -- Hide fill when not mounted (show empty bar frame)
        if self.fill then self.fill:SetHidden(true) end
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
    -- Use structured config table
    local cfg = BETTERUI_ORB_FRAMES
    local leftBorderSize = cfg.orbs.left.borderSize
    local rightBorderSize = cfg.orbs.right.borderSize
    
    -- Compute fill sizes from config scales (NO ROUNDING - Matches UpdateOrbLayout)
    local healthFillWidth =  math.min(leftBorderSize * cfg.fills.health.scaleW, leftBorderSize)
    local healthFillHeight = math.min(leftBorderSize * cfg.fills.health.scaleH, leftBorderSize)
    local magickaFillWidth = math.min(rightBorderSize * cfg.fills.magicka.scaleW, rightBorderSize)
    local magickaFillHeight = math.min(rightBorderSize * cfg.fills.magicka.scaleH, rightBorderSize)
    local staminaFillWidth = math.min(rightBorderSize * cfg.fills.stamina.scaleW, rightBorderSize)
    local staminaFillHeight = math.min(rightBorderSize * cfg.fills.stamina.scaleH, rightBorderSize)
    local resourceFillWidth = math.min(rightBorderSize * cfg.fills.resource.scaleW, rightBorderSize)
    local resourceFillHeight = math.min(rightBorderSize * cfg.fills.resource.scaleH, rightBorderSize)

    m_pools = {
        [POWERTYPE_HEALTH] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbHealth'), POWERTYPE_HEALTH),
        [POWERTYPE_MAGICKA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbMagicka'), POWERTYPE_MAGICKA),
        [POWERTYPE_STAMINA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbStamina'), POWERTYPE_STAMINA),
    }

    -- Add Tooltips using HitBoxes to solve split-orb overlap issues
    local function AddOrbTooltip(control, powerType) 
        if not control then return end
        control:SetMouseEnabled(true)
        control:SetHandler("OnMouseEnter", function(self)
            InitializeTooltip(InformationTooltip, self, RIGHT, -5, 0)
            local current, max = GetUnitPower("player", powerType)
            SetTooltipText(InformationTooltip, string.format("%d / %d", current, max))
        end)
        control:SetHandler("OnMouseExit", function()
             ClearTooltip(InformationTooltip)
        end)
    end
    
    AddOrbTooltip(FindControl(rootFrame, 'OrbHealth'), POWERTYPE_HEALTH)
    
    -- Create distinct hitboxes for Magicka (Left) and Stamina (Right)
    -- because the original controls overlap or are full size
    local magickaOrb = FindControl(rootFrame, 'OrbMagicka')
    local staminaOrb = FindControl(rootFrame, 'OrbStamina')
    
    if magickaOrb and staminaOrb then
        local magickaHitBox = WINDOW_MANAGER:CreateControl("BetterUIEndsOrbMagickaHitBox", magickaOrb, CT_CONTROL)
        magickaHitBox:ClearAnchors()
        -- Anchor TopLeft to TopLeft of parent
        magickaHitBox:SetAnchor(TOPLEFT, magickaOrb, TOPLEFT, 0, 0)
        -- Anchor BottomRight to Bottom Center of parent (splitting it vertically)
        magickaHitBox:SetAnchor(BOTTOMRIGHT, magickaOrb, BOTTOM, 0, 0)
        
        local staminaHitBox = WINDOW_MANAGER:CreateControl("BetterUIEndsOrbStaminaHitBox", staminaOrb, CT_CONTROL)
        staminaHitBox:ClearAnchors()
        staminaHitBox:SetAnchor(TOPLEFT, staminaOrb, TOP, 0, 0) -- Left edge at Center Top
        staminaHitBox:SetAnchor(BOTTOMRIGHT, staminaOrb, BOTTOMRIGHT, 0, 0)
        
        AddOrbTooltip(magickaHitBox, POWERTYPE_MAGICKA)
        AddOrbTooltip(staminaHitBox, POWERTYPE_STAMINA)

        -- Ensure original containers don't steal mouse
        magickaOrb:SetMouseEnabled(false)
        staminaOrb:SetMouseEnabled(false)
    else
        -- Fallback if controls missing (shouldn't happen)
        AddOrbTooltip(magickaOrb, POWERTYPE_MAGICKA)
        AddOrbTooltip(staminaOrb, POWERTYPE_STAMINA)
    end
    
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

-------------------------------------------------------------------------------------------------
-- BetterUIShieldBar Class (Full Ring Overlay)
-------------------------------------------------------------------------------------------------

local BetterUIShieldBar = BetterUIOrbBar:Subclass()

function BetterUIShieldBar:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function BetterUIShieldBar:RefreshVisuals()
    -- Shield Graphic Overlay Issue Fix:
    -- The base class slices the texture vertically based on percentage.
    -- For the shield ring, we want to show the FULL ring if the shield > 0.
    
    if not self.fog then return end

    if self.currentValue <= 0 then
        self.fog:SetHidden(true)
        return
    end
    self.fog:SetHidden(false)

    -- Dimensions from config
    local fullWidth = self.fillWidth or 150
    local fullHeight = self.fillHeight or 150
    local fillOffsetX = self.fillOffsetX or 0
    local fillOffsetY = self.fillOffsetY or 0
    
    -- Always set full dimensions and full texture coords for the shield ring
    self.fog:SetDimensions(fullWidth, fullHeight)
    self.fog:SetTextureCoords(0, 1, 0, 1) -- Full texture
    
    self.fog:ClearAnchors()
    -- Center anchor, applying offsets
    self.fog:SetAnchor(CENTER, self.control, CENTER, 
        self.baseAnchorX + fillOffsetX, 
        fillOffsetY)
end


local function SetupShieldBar(rootFrame)
    m_shieldBar = BetterUIShieldBar:New(FindControl(rootFrame, 'OrbShield'), ATTRIBUTE_VISUAL_POWER_SHIELDING)
    
    -- DEBUG MODE: Set BETTERUI_SHIELD_DEBUG = true to always show shield for visual testing
    local debugShield = BETTERUI_SHIELD_DEBUG or false
    
    if debugShield then
        -- Debug: Show shield with a test value
        if m_shieldBar.control then m_shieldBar.control:SetHidden(false) end
        if m_shieldBar.fog then m_shieldBar.fog:SetHidden(false) end
        m_shieldBar.label:GetParent():SetHidden(false)
    else
        -- Normal: Hide until shield is applied
        if m_shieldBar.control then m_shieldBar.control:SetHidden(true) end
        m_shieldBar.label:GetParent():SetHidden(true)
    end
    
    -- Apply shield text settings from user configuration
    if m_shieldBar.label then
        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
        local shieldTextSize = settings.shieldTextSize or 20
        local shieldTextColor = settings.shieldTextColor or {0, 1, 1, 1}
        m_shieldBar.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", shieldTextSize))
        m_shieldBar.label:SetColor(unpack(shieldTextColor))
        
        -- Scale shield icon to match text size (icon is ~1.6x the font size for visual balance)
        local shieldIcon = FindControl(m_shieldBar.control, 'ShieldIcon')
        if shieldIcon then
            local iconSize = math.floor(shieldTextSize * 1.25)
            shieldIcon:SetDimensions(iconSize, iconSize)
        end
    end

    -- Apply Shield Config
    local cfg = BETTERUI_ORB_FRAMES
    local leftBorderSize = cfg.orbs.left.borderSize
    
    local shieldFillWidth = math.min(leftBorderSize * cfg.fills.shield.scaleW, leftBorderSize)
    local shieldFillHeight = math.min(leftBorderSize * cfg.fills.shield.scaleH, leftBorderSize)
    
    m_shieldBar.fillWidth = shieldFillWidth
    m_shieldBar.fillHeight = shieldFillHeight
    m_shieldBar.fillOffsetX = cfg.fills.shield.x
    m_shieldBar.fillOffsetY = cfg.fills.shield.y
    
    -- Debug: Set a test shield value
    if debugShield then
        zo_callLater(function()
            if m_shieldBar and m_pools[POWERTYPE_HEALTH] then
                m_shieldBar:SetRange(0, m_pools[POWERTYPE_HEALTH]:GetMax())
                m_shieldBar:UpdateValue(5000) -- Test shield value
            end
        end, 500)
    end

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function(_, _, unitAttributeVisual, _, _, _, value)
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
            if m_shieldBar.fog then m_shieldBar.fog:SetHidden(false) end
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
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING and not debugShield then
            ZO_StatusBar_SmoothTransition(m_shieldBar, 0, m_pools[POWERTYPE_HEALTH]:GetMax())
            m_shieldBar.label:GetParent():SetHidden(true)
             if m_shieldBar.fog then m_shieldBar.fog:SetHidden(true) end
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

local function SetupMountStaminaBar(rootFrame)
    m_mountStaminaBar = MountStaminaBar:New(rootFrame)
end

-- Centralized function to enforce hiding of default UI elements
-- This is called from multiple event and scene handlers to ensure
-- the native health/stamina/magicka bars stay hidden when orb frames are enabled
local function EnforceDefaultUIHidden()
    local settings = GetModuleSettings()
    if not settings.enabled then return end
    
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
    end
    HideNativeActionBar()
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
    
    -- Re-enforce hiding after death/alive state changes (delay to run after ESO's internal handlers)
    EVENT_MANAGER:RegisterForEvent(NAME .. "_DeathEnforce", EVENT_PLAYER_DEAD, function()
        zo_callLater(EnforceDefaultUIHidden, 100)
    end)
    EVENT_MANAGER:RegisterForEvent(NAME .. "_AliveEnforce", EVENT_PLAYER_ALIVE, function()
        zo_callLater(EnforceDefaultUIHidden, 100)
    end)
    
    -- Handle resurrection complete event
    EVENT_MANAGER:RegisterForEvent(NAME .. "_Reincarnated", EVENT_PLAYER_REINCARNATED, function()
        zo_callLater(EnforceDefaultUIHidden, 100)
    end)
    
    -- Handle end of siege control (restores HUD scene)
    EVENT_MANAGER:RegisterForEvent(NAME .. "_EndSiege", EVENT_END_SIEGE_CONTROL, function()
        zo_callLater(EnforceDefaultUIHidden, 100)
    end)
    
    -- Hook RestoreHUDScene to catch ALL cases where HUD is restored
    -- (siege exit, housing editor exit, battleground end, screenshot mode exit, etc.)
    if SCENE_MANAGER and SCENE_MANAGER.RestoreHUDScene then
        local originalRestoreHUDScene = SCENE_MANAGER.RestoreHUDScene
        SCENE_MANAGER.RestoreHUDScene = function(self, ...)
            local result = originalRestoreHUDScene(self, ...)
            zo_callLater(EnforceDefaultUIHidden, 50)
            return result
        end
    end
    
    -- Also hook RestoreHUDUIScene for UI mode transitions
    if SCENE_MANAGER and SCENE_MANAGER.RestoreHUDUIScene then
        local originalRestoreHUDUIScene = SCENE_MANAGER.RestoreHUDUIScene
        SCENE_MANAGER.RestoreHUDUIScene = function(self, ...)
            local result = originalRestoreHUDUIScene(self, ...)
            zo_callLater(EnforceDefaultUIHidden, 50)
            return result
        end
    end
    
    -- Register for loot scene state changes
    local lootScene = SCENE_MANAGER:GetScene("loot")
    if lootScene then
        lootScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                zo_callLater(EnforceDefaultUIHidden, 50)
            end
        end)
    end
    
    -- Register for gamepad loot scene
    local lootGamepadScene = SCENE_MANAGER:GetScene("lootGamepad")
    if lootGamepadScene then
        lootGamepadScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                zo_callLater(EnforceDefaultUIHidden, 50)
            end
        end)
    end
    
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
    if m_mountStaminaBar then m_mountStaminaBar:Update() end

end



local function UpdateDynamicLayout()
    if not m_rootFrame then return end
    
    local ornamentLeft = FindControl(m_rootFrame, "OrnamentLeft")
    local ornamentRight = FindControl(m_rootFrame, "OrnamentRight")
    local bgMiddle = FindControl(m_rootFrame, "BgMiddle")
    local backBarContainer = FindControl(m_rootFrame, "BackBarContainer")
    local xpBar = FindControl(m_rootFrame, "BetterUIXPBar")
    local castBar = FindControl(m_rootFrame, "BetterUICastBar")
    local mountStaminaBar = FindControl(m_rootFrame, "BetterUIMountStaminaBar")
    
    if not ornamentLeft or not ornamentRight or not bgMiddle then return end
    
    local settings = GetModuleSettings()
    local cfg = BETTERUI_ORB_FRAMES
    local leftX = cfg.ornaments.left.x
    local leftY = cfg.ornaments.left.y
    local rightX = cfg.ornaments.right.x
    local rightY = cfg.ornaments.right.y
    
    -- ========================================
    -- LEFT SIDE: XP/CP Bar (moved from right)
    -- ========================================
    ornamentLeft:ClearAnchors()
    if settings.xpBarEnabled then
        -- Shift Ornament UP when XP bar is enabled
        ornamentLeft:SetAnchor(CENTER, bgMiddle, CENTER, leftX, leftY - 45)
        
        if xpBar then
            xpBar:ClearAnchors()
            xpBar:SetAnchor(TOP, ornamentLeft, BOTTOM, BETTERUI_XP_BAR_OFFSET_X or 0, BETTERUI_XP_BAR_OFFSET_Y or -97)
            xpBar:SetHidden(false)  -- Ensure bar is visible when enabled
        end
    else
        -- Reset Ornament to default position
        ornamentLeft:SetAnchor(CENTER, bgMiddle, CENTER, leftX, leftY)
        
        if xpBar then
            xpBar:ClearAnchors()
            xpBar:SetHidden(true)
        end
    end
    
    -- ========================================
    -- CENTER: Cast Bar (above back bar)
    -- ========================================
    if castBar then
        castBar:ClearAnchors()
        if settings.castBarEnabled and backBarContainer then
            -- Center cast bar above the back bar container (closer to back bar, shifted left)
            local castOffsetX = BETTERUI_CAST_BAR_OFFSET_X or -20
            local castOffsetY = BETTERUI_CAST_BAR_OFFSET_Y or 15
            castBar:SetAnchor(BOTTOM, backBarContainer, TOP, castOffsetX, castOffsetY)
        else
            -- Position off-screen when disabled
            castBar:SetAnchor(BOTTOM, bgMiddle, BOTTOM, 0, -160)
        end
    end
    
    -- ========================================
    -- RIGHT SIDE: Mount Stamina Bar (new)
    -- ========================================
    ornamentRight:ClearAnchors()
    if settings.mountStaminaBarEnabled then
        -- Shift Ornament UP when mount stamina bar is enabled
        ornamentRight:SetAnchor(CENTER, bgMiddle, CENTER, rightX, rightY - 45)
        
        if mountStaminaBar then
            mountStaminaBar:ClearAnchors()
            mountStaminaBar:SetAnchor(TOP, ornamentRight, BOTTOM, BETTERUI_MOUNT_STAMINA_BAR_OFFSET_X or 0, BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y or -97)
            -- Visibility is controlled by MountStaminaBar:Update() based on IsMounted()
        end
    else
        -- Reset Ornament to default position
        ornamentRight:SetAnchor(CENTER, bgMiddle, CENTER, rightX, rightY)
        
        if mountStaminaBar then
            mountStaminaBar:ClearAnchors()
            mountStaminaBar:SetAnchor(TOP, ornamentRight, BOTTOM, 0, 0)
        end
    end
end

local function SetupModule(control)
    m_isInitialized = true
    
    SetupPowerPools(control)
    SetupShieldBar(control)
    SetupStateHandlers()
    SetupFoodTracker(control)
    SetupExperienceBar(control)
    SetupCastBar(control)
    SetupMountStaminaBar(control)
    
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

local function ApplySkillBarVisuals()
    local settings = GetModuleSettings()
    local cooldownSize = settings.cooldownTextSize or 27
    local cooldownColor = settings.cooldownTextColor or {0.86, 0.84, 0.13, 1}
    local quickslotSize = settings.quickslotTextSize or 27
    local quickslotColor = settings.quickslotTextColor or {1, 1, 1, 1}
    
    local cooldownFont = string.format("$(BOLD_FONT)|%d|thick-outline", cooldownSize)
    local quickslotFont = string.format("$(BOLD_FONT)|%d|thick-outline", quickslotSize)

    -- Helper to update button visuals
    local function UpdateButtonVisuals(btn)
        if not btn then return end
        
        -- Cooldown/Timer Text
        local textControls = {
            btn:GetNamedChild("CooldownText"),
            btn:GetNamedChild("TimerText")
        }
        for _, lbl in ipairs(textControls) do
            if lbl then
                lbl:SetFont(cooldownFont)
                lbl:SetColor(unpack(cooldownColor))
            end
        end
        
        -- Quickslot Count Text
        local countText = btn:GetNamedChild("CountText")
        if countText then
            countText:SetFont(quickslotFont)
            countText:SetColor(unpack(quickslotColor))
        end
    end
    
    -- Update Back Bar Buttons
    if m_rootFrame then
        local backBarContainer = FindControl(m_rootFrame, 'BackBarContainer')
        if backBarContainer then
            for i = 1, 8 do 
                 local btn = FindControl(backBarContainer, 'Button' .. i)
                 UpdateButtonVisuals(btn)
            end
        end
        
        -- Update Front Bar Buttons (font is also set in UpdateFrontBarCooldowns for reliability)
        local frontBarContainer = FindControl(m_rootFrame, 'FrontBarContainer')
        if frontBarContainer then
             for i = 1, 5 do
                local btn = FindControl(frontBarContainer, 'Button' .. i)
                if not btn then
                     btn = frontBarContainer:GetNamedChild("Button" .. i)
                end
                UpdateButtonVisuals(btn)
             end
             
             local ultimateBtn = FindControl(frontBarContainer, 'UltimateButton') or frontBarContainer:GetNamedChild("UltimateButton")
             UpdateButtonVisuals(ultimateBtn)

             local quickslotBtn = FindControl(frontBarContainer, 'QuickslotButton') or frontBarContainer:GetNamedChild("QuickslotButton")
             UpdateButtonVisuals(quickslotBtn)
             
             local companionBtn = FindControl(frontBarContainer, 'CompanionButton') or frontBarContainer:GetNamedChild("CompanionButton")
             UpdateButtonVisuals(companionBtn)
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
        
        -- Apply text settings (Health/Magicka/Stamina)
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
        
        -- Apply shield text settings separately (shield is not in m_pools)
        if m_shieldBar and m_shieldBar.label then
            local currentSettings = GetModuleSettings()
            local shieldTextSize = currentSettings.shieldTextSize or 20
            local shieldTextColor = currentSettings.shieldTextColor or {1, 1, 1, 1}
            m_shieldBar.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", shieldTextSize))
            m_shieldBar.label:SetColor(unpack(shieldTextColor))
            
            -- Scale shield icon to match text size (icon is ~1.6x the font size for visual balance)
            local shieldIcon = FindControl(m_shieldBar.control, 'ShieldIcon')
            if shieldIcon then
                local iconSize = math.floor(shieldTextSize * 1.25)
                shieldIcon:SetDimensions(iconSize, iconSize)
            end
        end

        UpdateOrbLayout()  -- Apply layout constants for orbs and ornaments
        UpdateDynamicLayout() -- Apply relative positioning of bars and ornaments
        -- Apply font/color settings to skill bars (deferred to ensure template children are ready)
        zo_callLater(function()
            ApplySkillBarVisuals()
        end, 200)
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
    
    -- Handle zone transitions - triggers enforcement through ApplySettings
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function() 
        ResourceOrbFrames.ApplySettings()
    end)
    
    -- Handle level-up: when player reaches weapon swap unlock level, refresh UI to show back bar
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_LEVEL_UPDATE, function(_, unitTag, level)
        if unitTag == "player" and level >= GetWeaponSwapUnlockedLevel() then
            ResourceOrbFrames.ApplySettings()
        end
    end)
    
    ResourceOrbFrames.ApplySettings()
end
