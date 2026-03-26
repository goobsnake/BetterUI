#!/bin/bash
# validate_types.sh - Check EmmyLua annotation coverage
#
# Usage: bash tools/tests/validate_types.sh
#
# This script calculates the percentage of Lua files that have
# EmmyLua type annotations (@param, @return, @class).
#
# Exit codes:
#   0 - Coverage check completed successfully
#   1 - Error during execution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${REPO_ROOT}"

echo "=========================================="
echo "EmmyLua Type Annotation Coverage Check"
echo "=========================================="
echo ""

# Count total Lua files in Modules directory
echo "Scanning for Lua files in Modules/..."
TOTAL_FILES=$(find Modules -name "*.lua" 2>/dev/null | wc -l)

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo -e "${RED}Error: No Lua files found in Modules/ directory${NC}"
    exit 1
fi

echo "Total Lua files found: $TOTAL_FILES"
echo ""

# Count files with EmmyLua annotations
echo "Checking for EmmyLua annotations (@param, @return, @class)..."
ANNOTATED_FILES=$(grep -rl '@param\|@return\|@class' Modules/ 2>/dev/null | wc -l)

echo "Files with annotations: $ANNOTATED_FILES"
echo ""

# Calculate percentage
if [ "$TOTAL_FILES" -gt 0 ]; then
    PERCENTAGE=$((ANNOTATED_FILES * 100 / TOTAL_FILES))
else
    PERCENTAGE=0
fi

# Display results
echo "=========================================="
echo "Coverage Results"
echo "=========================================="
printf "Annotated files:  %4d / %4d\n" "$ANNOTATED_FILES" "$TOTAL_FILES"
printf "Coverage:         %4d%%\n" "$PERCENTAGE"
echo ""

# Color-code the percentage
if [ "$PERCENTAGE" -ge 90 ]; then
    echo -e "Status: ${GREEN}EXCELLENT${NC} (≥90%)"
elif [ "$PERCENTAGE" -ge 70 ]; then
    echo -e "Status: ${GREEN}GOOD${NC} (≥70%)"
elif [ "$PERCENTAGE" -ge 50 ]; then
    echo -e "Status: ${YELLOW}NEEDS IMPROVEMENT${NC} (≥50%)"
else
    echo -e "Status: ${RED}POOR${NC} (<50%)"
fi

echo ""
echo "=========================================="
echo "Files Missing Annotations"
echo "=========================================="

# List files without annotations
echo ""
if [ "$ANNOTATED_FILES" -lt "$TOTAL_FILES" ]; then
    echo "The following files have no EmmyLua annotations:"
    echo ""
    
    # Get list of all Lua files
    ALL_FILES=$(find Modules -name "*.lua" | sort)
    
    # Get list of annotated files
    ANNOTATED_LIST=$(grep -rl '@param\|@return\|@class' Modules/ | sort)
    
    # Find files in ALL_FILES but not in ANNOTATED_LIST
    comm -23 <(echo "$ALL_FILES") <(echo "$ANNOTATED_LIST") | while read -r file; do
        echo "  - $file"
    done
else
    echo -e "${GREEN}All files have EmmyLua annotations!${NC}"
fi

echo ""
echo "=========================================="
echo "Annotation Type Breakdown"
echo "=========================================="

# Count specific annotation types
PARAM_COUNT=$(grep -r '@param' Modules/ 2>/dev/null | wc -l)
RETURN_COUNT=$(grep -r '@return' Modules/ 2>/dev/null | wc -l)
CLASS_COUNT=$(grep -r '@class' Modules/ 2>/dev/null | wc -l)
TYPE_COUNT=$(grep -r '@type' Modules/ 2>/dev/null | wc -l)
FIELD_COUNT=$(grep -r '@field' Modules/ 2>/dev/null | wc -l)

echo ""
printf "  @param annotations:  %5d\n" "$PARAM_COUNT"
printf "  @return annotations: %5d\n" "$RETURN_COUNT"
printf "  @class annotations:  %5d\n" "$CLASS_COUNT"
printf "  @type annotations:   %5d\n" "$TYPE_COUNT"
printf "  @field annotations:  %5d\n" "$FIELD_COUNT"

echo ""
echo "=========================================="
echo "Recommendations"
echo "=========================================="
echo ""

if [ "$PERCENTAGE" -lt 90 ]; then
    echo "To improve coverage:"
    echo "  1. Add @param tags for all function parameters"
    echo "  2. Add @return tags for all function return values"
    echo "  3. Add @class tags for class definitions"
    echo "  4. Run this script regularly to track progress"
    echo ""
    echo "Example annotation:"
    echo "  --- @param itemLink string The item link to check"
    echo "  --- @return number total Total count of matching items"
    echo "  function Module.GetCount(itemLink)"
    echo "      -- implementation"
    echo "  end"
else
    echo -e "${GREEN}Coverage is excellent! Keep up the good work.${NC}"
    echo ""
    echo "Maintenance tips:"
    echo "  1. Add annotations for all new functions"
    echo "  2. Update annotations when changing function signatures"
    echo "  3. Review annotations during code reviews"
fi

echo ""
echo "=========================================="

# Return success
echo ""
echo "Type coverage check completed."
exit 0
