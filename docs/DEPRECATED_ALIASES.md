# Deprecated Backward-Compatibility Aliases

> **Migration Target**: v3.0  
> **Last Updated**: 2026-01-29

This document tracks all global backward-compatibility aliases that should be migrated or removed in v3.0.

---

## XML Support Aliases (CIM/Constants.lua)

These aliases exist to support XML template files. Migration requires updating XML files to reference the CIM constant paths.

### Panel Dimensions
| Alias | Canonical Path |
|-------|----------------|
| `BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH` |
| `BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH` |
| `BETTERUI_GAMEPAD_DEFAULT_PANEL_CONTAINER_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.PANEL.CONTAINER_WIDTH` |

### Padding
| Alias | Canonical Path |
|-------|----------------|
| `BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING` | `BETTERUI.CIM.CONST.LAYOUT.PADDING.DEFAULT` |
| `BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING_OTHER` | `BETTERUI.CIM.CONST.LAYOUT.PADDING.OTHER` |
| `BETTERUI_GAMEPAD_SCREEN_PADDING` | `BETTERUI.CIM.CONST.LAYOUT.PADDING.SCREEN` |
| `BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ` | Computed: `SCREEN + DEFAULT` |

### List Dimensions
| Alias | Canonical Path |
|-------|----------------|
| `BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET` | `BETTERUI.CIM.CONST.LAYOUT.LIST.SCREEN_X_OFFSET` |
| `BETTERUI_TABBAR_ICON_WIDTH` | `BETTERUI.CIM.CONST.LAYOUT.LIST.ICON_WIDTH` |
| `BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH` | Computed |
| `BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_HWIDTH` | Computed |
| `BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET` | Hardcoded: `-20` |
| `BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT` | Computed |
| `BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_AFTER_INDENT` | Computed |

### Header
| Alias | Value |
|-------|-------|
| `BETTERUI_SEARCH_BAR_SPACING_Y` | `8` |

### Positioning
| Alias | Canonical Path |
|-------|----------------|
| `BETTERUI_GAMEPAD_QUADRANT_1_LEFT` | `BETTERUI.CIM.CONST.LAYOUT.PADDING.DEFAULT` |

### Column Definitions
| Alias | Canonical Path |
|-------|----------------|
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

---

## Other Module Aliases

### Inventory (Core/InventoryClass.lua)
- `INVENTORY_CATEGORY_LIST` - Global alias for category definitions

### Utilities (Core/Utilities.lua)
- Legacy `enabled` key support for saved variables (should use `m_enabled`)

---

## Migration Strategy

1. **XML Templates**: Migrate to use Lua-defined constants via virtual anchors
2. **Lua Code**: Replace all global alias usage with CIM namespace paths
3. **SavedVariables**: Add migration code for legacy key names
4. **Testing**: Verify all XML templates render correctly after migration
