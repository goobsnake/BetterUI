# Vendor.lua Subjective Code Review

## 1. SafeCall / Error Handling Consistency
- **Inconsistent use of `pcall` vs `SafeCall`**: While `SafeCall` is defined and used extensively for safe native API invocation, the `BETTERUI.Vendor.Init` function relies on raw `pcall` for initializing the Sort Controller and Header Sort Integration. Standardizing on `SafeCall` (or `ExecuteSafely`) would unify the error boundary handling.

## 2. Routing Clarity & State Management
- **Module-local State Flags**: Variables such as `isFenceInteraction`, `isStableInteraction`, `fenceEnableSell`, and `fenceEnableLaunder` are stored as file-local variables. Transitioning these to be explicit state properties on `Vendor.instance` (or a dedicated state object) would improve object-oriented encapsulation.
- **Monolithic Native Logic**: `EnsureNativeStoreComponents` is a 150+ line function that directly mutates `STORE_WINDOW_GAMEPAD` internals (e.g., masking `sceneName`, wiping `tabBar` callbacks, forcefully sweeping `DIRECTIONAL_INPUT`). Breaking this into distinct, well-named helper functions (e.g., `SweepNativeDirectionalInput`, `SuppressNativeTabBar`) would greatly enhance routing clarity.

## 3. Convention Outliers & Elegance
- **Inline Monkey-Patching**: Inside `Init()`, `Vendor.instance.list.MovePrevious` is monkey-patched inline to inject header focus behavior. Using a dedicated subclass for the vendor list or exposing a formal hook in the base list implementation would be more elegant and maintainable.
- **Bloated Keybind Configuration**: `BuildCoreKeybinds` creates a massive inline table spanning over 200 lines. Extracting the individual keybind definitions (or their callbacks) into separate, named builder functions would improve high-level elegance.
- **Raw Global Lookups**: The frequent inline use of `rawget(_G, "...")` for UI strings and constants circumvents strict global linting but creates visual clutter. Consolidating these lookups into a dedicated constants mapping table at the top of the file would clean up the logic.

## 4. Naming Quality
- **Private Variable Consistency**: The module mixes standard local variables (`fenceEnableSell`) with pseudo-private properties on the `Vendor` table (`Vendor._sessionHasBuyMode`, `Vendor._isClosing`, `Vendor._batchProcessing`). Standardizing private state naming and where it lives will improve clarity.
- **Builder Naming**: Function names like `BuildModeTabs` and `BuildFallbackVendorTabs` are acceptable, but standardizing on `Create...` or `Generate...` might better align with typical factory patterns found in Lua/ESO addons.

## Risks from Existing Workspace State
- **Unstaged Changes**: There are **92 unstaged changes** currently present in the workspace. Any surgical improvements or refactoring applied to `Vendor.lua` (or its dependencies) carry a significant risk of merge conflicts or unintended overwrites with this active work-in-progress. It is recommended to stash or commit the current state before addressing these subjective issues.