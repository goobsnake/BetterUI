local function read_file(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local function assert_contains(source, needle, message)
    assert(source:find(needle, 1, true), message .. "\nMissing: " .. needle)
end

local function assert_not_contains(source, needle, message)
    assert(not source:find(needle, 1, true), message .. "\nUnexpected: " .. needle)
end

local classSource = read_file("Modules/Companions/Core/CompanionsClass.lua")
local runtimeSource = read_file("Modules/Companions/Core/CompanionsRuntime.lua")
local listSource = read_file("Modules/Companions/Core/CompanionListManager.lua")
local screenXml = read_file("Modules/CIM/Templates/ParametricScrollListTemplates.xml")
local companionXml = read_file("Modules/Companions/Templates/GamepadCompanionInventory.xml")
local headerXml = read_file("Modules/CIM/Templates/GenericHeader.xml")
local manifestSource = read_file("BetterUI.txt")

assert_contains(companionXml, '<TopLevelControl name="BUI_GpCmp"',
    "Companion owns a statically materialized top-level control")
assert_contains(companionXml, 'inherits="BETTERUI_Gamepad_ParametricList_Screen"',
    "Companion top-level control inherits the Inventory parametric screen")
assert_contains(manifestSource, "Modules\\Companions\\Templates\\GamepadCompanionInventory.xml",
    "Companion top-level XML loads before runtime initialization")
assert_contains(runtimeSource, "Companions.Class:New(\n        BUI_GpCmp,",
    "Companion runtime passes the XML-created control to the class")
assert_not_contains(classSource, '"BETTERUI_Gamepad_ParametricList_Screen")',
    "Companion must not instantiate the hidden Inventory screen template dynamically")
assert_contains(classSource, '"$(parent)Main",',
    "Companion materializes an Inventory-style Main list container")
assert_contains(classSource, '"BETTERUI_Gamepad_ParametricList_Screen_ListContainer"',
    "Companion Main list uses Inventory's list-container template")
assert_contains(classSource, "templateListContainer:SetHidden(true)",
    "Companion hides the unused list container inherited with the static shell")
assert_contains(classSource, "self.list.alignToScreenCenterExpectedEntryHalfHeight = 15",
    "Companion uses Inventory's selected-row centering hint")
assert_contains(listSource, "headerOnly = false",
    "Companion search anchors from the concrete generic header like Inventory")
assert_contains(classSource, 'container:GetNamedChild("HeaderContainer")',
    "Companion resolves the shared Inventory header container")
assert_contains(classSource, 'container:GetNamedChild("ListContainer")',
    "Companion resolves the shared Inventory list container")
assert_contains(classSource, 'container:GetNamedChild("FooterContainer")',
    "Companion resolves the shared Inventory footer container")

assert_contains(screenXml, 'relativeTo="$(grandparent)HeaderContainerHeader"',
    "Shared XML anchors the list to the Inventory header")
assert_contains(screenXml, 'relativeTo="$(grandparent)FooterContainerFooter"',
    "Shared XML anchors the list to the Inventory footer")
assert_not_contains(listSource, "AlignCompanionListToHeader",
    "Companion code does not override Inventory list anchors")
assert_not_contains(runtimeSource, "COMPANION_ROW_LABEL_OFFSET_X",
    "Companion rows do not carry scene-specific name offsets")
assert_not_contains(runtimeSource, "COMPANION_ROW_ICON_OFFSET_X",
    "Companion rows do not carry scene-specific icon offsets")
assert_contains(runtimeSource, "BETTERUI_SharedGamepadEntry_OnSetup,",
    "Companion rows use the same setup callback as Inventory")

for _, controlName in ipairs({
    "Column1Label", "Column2Label", "Column4Label", "Column6Label", "Column5Label",
}) do
    assert_contains(headerXml, '$(parent)' .. controlName,
        "Inventory XML owns Companion column placement for " .. controlName)
end
assert_not_contains(listSource, "label:ClearAnchors()",
    "Companion column refresh preserves Inventory XML anchors")
assert_contains(classSource, "BETTERUI.CIM.UnifiedFooter.MODE.CURRENCY",
    "Companion footer matches Inventory currency mode")

print("test_companion_geometry_contract.lua: OK")
