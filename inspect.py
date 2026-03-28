import os
import re

files = [
    "Modules/Banking/Actions/BankingActions.lua",
    "Modules/Banking/Banking.lua",
    "Modules/Banking/Core/BankingClass.lua",
    "Modules/Banking/Core/RefreshIntegration.lua",
    "Modules/Banking/Dialogs/QuantityDialog.lua",
    "Modules/Banking/Keybinds/KeybindManager.lua",
    "Modules/Banking/State/StateManager.lua",
    "Modules/Banking/UI/HeaderManager.lua",
    "Modules/Banking/Actions/TransferActions.lua",
    "Modules/Banking/Lists/BankListManager.lua",
    "Modules/Banking/Search/SearchManager.lua",
    "Modules/Banking/Settings/SettingsPanel.lua",
    "Modules/Banking/Scene/BankingSceneLifecycle.lua"
]

for filepath in files:
    if not os.path.exists(filepath):
        continue
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    for line in lines:
        if 'Rationale:' in line or 'Mechanism:' in line or 'Description:' in line:
            print(repr(line))
