# XML Support Constants Reference

> **Purpose**: Developer reference for global constants required by XML templates  
> **Last Updated**: 2026-01-31

This document lists global constants that exist to support XML template files. These constants are **intentionally retained** because ESO XML cannot reference Lua namespace paths.

---

## Why Global Constants Are Required

XML template files cannot use Lua namespace syntax:
```xml
<!-- INVALID: XML cannot parse Lua namespaces -->
<Dimensions x="BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH" />

<!-- VALID: Global constants work in XML -->
<Dimensions x="BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH" />
```

All constants below are defined in `Modules/CIM/Constants.lua` and delegate to canonical CIM namespace paths.

---

## Panel Dimensions
| Global Constant | Canonical Path |
|-----------------|----------------|
| `BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH` |
| `BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH` |
| `BETTERUI_GAMEPAD_DEFAULT_PANEL_CONTAINER_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.PANEL.CONTAINER_WIDTH` |

## Padding
| Global Constant | Canonical Path |
|-----------------|----------------|
| `BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING` | `BETTERUI.CIM.CONST.LAYOUT.PADDING.DEFAULT` |
| `BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING_OTHER` | `BETTERUI.CIM.CONST.LAYOUT.PADDING.OTHER` |
| `BETTERUI_GAMEPAD_SCREEN_PADDING` | `BETTERUI.CIM.CONST.LAYOUT.PADDING.SCREEN` |
| `BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ` | Computed: `SCREEN + DEFAULT` |

## List Dimensions
| Global Constant | Canonical Path |
|-----------------|----------------|
| `BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET` | `BETTERUI.CIM.CONST.LAYOUT.LIST.SCREEN_X_OFFSET` |
| `BETTERUI_TABBAR_ICON_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.LIST.ICON_WIDTH` |
| `BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH` | Computed |
| `BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_HWIDTH` | Computed |
| `BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET` | Hardcoded: `-20` |
| `BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT` | Computed |
| `BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_AFTER_INDENT` | Computed |

## Header & Positioning
| Global Constant | Value/Path |
|-----------------|------------|
| `BETTERUI_SEARCH_BAR_SPACING_Y` | `8` |
| `BETTERUI_GAMEPAD_QUADRANT_1_LEFT` | Same as `DEFAULT_HORIZ_PADDING` |

## Column Definitions
| Global Constant | Canonical Path |
|-----------------|----------------|
| `BETTERUI_SUBMENU_LABEL_OFFSET_X` | `BETTERUI.CIM.CONST.LAYOUT.COLUMNS.SUBMENU.OFFSET_X` |
| `BETTERUI_SUBMENU_LABEL_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.COLUMNS.SUBMENU.WIDTH` |
| `BETTERUI_ITEM_TYPE_OFFSET_X` | `BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TYPE.OFFSET_X` |
| `BETTERUI_ITEM_TYPE_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TYPE.WIDTH` |
| `BETTERUI_TRAIT_OFFSET_X` | `BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TRAIT.OFFSET_X` |
| `BETTERUI_TRAIT_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TRAIT.WIDTH` |
| `BETTERUI_STAT_OFFSET_X` | `BETTERUI.CIM.CONST.LAYOUT.COLUMNS.STAT.OFFSET_X` |
| `BETTERUI_STAT_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.COLUMNS.STAT.WIDTH` |
| `BETTERUI_VALUE_OFFSET_X` | `BETTERUI.CIM.CONST.LAYOUT.COLUMNS.VALUE.OFFSET_X` |
| `BETTERUI_VALUE_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.COLUMNS.VALUE.WIDTH` |

## Tooltip Constants
| Global Constant | Canonical Path |
|-----------------|----------------|
| `BETTERUI_TOOLTIP_MAX_FADE_GRADIENT_SIZE` | `BETTERUI.CIM.CONST.TOOLTIP_MAX_FADE_GRADIENT_SIZE` |
| `BETTERUI_TOOLTIP_X_OFFSET` | `BETTERUI.CIM.CONST.TOOLTIP_X_OFFSET` |
| `BETTERUI_TOOLTIP_Y_OFFSET` | `BETTERUI.CIM.CONST.TOOLTIP_Y_OFFSET` |
| `BETTERUI_TOOLTIP_SCROLL_OFFSET_Y` | `BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y` |

---

## Usage in New Code

**In Lua files**: Always use the canonical CIM namespace path:
```lua
local width = BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH
```

**In XML templates**: Use the global constant:
```xml
<Dimensions x="BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH" />
```
