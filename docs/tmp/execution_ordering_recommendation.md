# Desloppify Rerun Queue Analysis & Execution Ordering

## Current State Summary
- **Target**: Strict score 90.
- **Current Scores**: Overall 76.4 / Objective 79.2 / Strict 76.3 / Verified 67.0.
- **Live Queue**: `auto/initial-review` cluster + `convention_outlier`, `error_consistency`, `high_level_elegance`, `low_level_elegance`, `naming_quality`.
- **Pending Review**: 8 new review issues pending triage (including structural/holistic issues like `vendor_category_boundary_duplication` and `inventory_scene_harness_gap`).
- **SQL Board/Tracking**: 2 Vendor-tail batches (sell/fence behavior and row/setup coverage) remain pending but are no longer at the top of the live queue.

## Recommendation Strategy
**Do not continue the Vendor-tail batches or execute subjective dimensions yet.** The recent generation of holistic review issues (such as `vendor_category_boundary_duplication`) indicates that the architectural foundation under the vendor and inventory modules is flawed. Continuing to write tests or setup coverage (the Vendor tail) on top of this will lead to rework. Likewise, subjective cleanups should be deferred until the structural code settles.

### Proposed Execution Ordering
1. **Triage & Resolve the 8 Review Issues (Highest Priority)**
   These represent concrete structural, architectural, and test strategy gaps. Resolving them stabilizes the codebase for the rest of the queue.
2. **Resume Leftover Vendor Work**
   Once the `vendor_category_boundary_duplication` and `inventory_scene_harness_gap` review issues are resolved, the foundational wiring will be stable enough to support the remaining vendor sell/fence and row/setup coverage passes.
3. **Execute Subjective Dimensions**
   Run the subjective passes (`convention_outlier`, `error_consistency`, `naming_quality`, `high_level_elegance`, `low_level_elegance`) last. Addressing the structural fixes and completing the vendor tests will naturally mutate the codebase; running subjective linters/cleanup at the end prevents duplicate effort and ensures the code is polished toward the strict 90 goal.

## Concrete Execution Batches (True Dependencies)

**Batch 1: Core Architecture & Boundaries (Independent)**
*Fix these first to stabilize cross-module dependencies.*
- `review::.::holistic::cross_module_architecture::inventory_owned_bank_taxonomy`
- `review::.::holistic::cross_module_architecture::string_path_service_locator_remains_core_seam`
- `review::.::holistic::cross_module_architecture::vendor_category_boundary_duplication`
- `review::.::holistic::abstraction_fitness::search_mode_alias_surface`
- `review::.::holistic::abstraction_fitness::string_path_dispatch`

**Batch 2: Test Strategy Gaps (Depends on Batch 1)**
*Establish harnesses and tests based on the corrected boundaries.*
- `review::.::holistic::test_strategy::batch_logic_surrogate_test`
- `review::.::holistic::test_strategy::inventory_scene_harness_gap`
- `review::.::holistic::test_strategy::tooltip_settings_position_coupling`

**Batch 3: Vendor-Tail Resumption (Depends on Batch 1 & 2)**
*Complete the interrupted work on a solid foundation.*
- Vendor Pass 3: Sell/fence behavior
- Vendor Pass 4: Row/setup coverage pass

**Batch 4: Subjective Cleanup (Depends on all above)**
*Final polish pass.*
- `convention_outlier`, `error_consistency`, `naming_quality`
- `high_level_elegance`, `low_level_elegance`

## SQL Todo / Dependency Adjustments
To align the SQL/planning tracking board with the live queue realities:
1. **Block Vendor-Tail:** Update the remaining Vendor-tail tasks in the SQL board to have an explicit dependency on the completion of the `vendor_category_boundary_duplication` and `inventory_scene_harness_gap` review issues. This formally reflects why they dropped from the live top queue.
2. **Promote Review Issues:** Inject the 8 new holistic review issues into the top of the SQL board/backlog as the immediate priority.
3. **Sequence Subjective Dimensions:** Ensure all `subjective::` dimensions are pushed to the back of the SQL queue, marked as dependent on the successful completion of Batch 3 (Vendor Tail) to ensure we don't polish code that is about to be rewritten.