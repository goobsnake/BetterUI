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
        print(f"Skipping {filepath}")
        continue
        
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    for line in lines:
        # Check if line contains Rationale: or Mechanism: and appears to be in a comment
        if 'Rationale:' in line or 'Mechanism:' in line:
            if re.search(r'--.*(?:Rationale:|Mechanism:)', line) or re.search(r'^\s*(?:Rationale:|Mechanism:)', line):
                continue
            
        line = re.sub(r'(--+)\s*Description:\s*', r'\1 ', line)
        new_lines.append(line)

    new_content = ''.join(new_lines)
    
    # Remove empty --[[ ]] blocks completely
    # Match --[[ followed by only whitespace/newlines, then ]] and optional newline
    new_content = re.sub(r'--\[\[\s*\]\]\n?', '', new_content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"Processed {filepath}")
