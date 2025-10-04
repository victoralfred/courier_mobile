#!/bin/bash

# Code Documentation Helper Script
# This script helps identify files that need documentation and tracks progress

COURIER_APP_DIR="/home/voseghale/projects/mobile/courier_app"
DOCS_PROGRESS="$COURIER_APP_DIR/DOCUMENTATION_PROGRESS.md"
OUTPUT_DIR="$COURIER_APP_DIR/documentation_output"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Code Documentation Helper ===${NC}\n"

# Function to count total lines of documentation in a file
count_doc_lines() {
    local file=$1
    grep -c "^\s*///" "$file" 2>/dev/null || echo "0"
}

# Function to check if file has IMPROVEMENT flags
has_improvements() {
    local file=$1
    grep -q "IMPROVEMENT:" "$file" 2>/dev/null && echo "yes" || echo "no"
}

# Function to extract IMPROVEMENT flags
extract_improvements() {
    local file=$1
    echo -e "${YELLOW}IMPROVEMENT Flags in $file:${NC}"
    grep -A 3 "IMPROVEMENT:" "$file" | sed 's/^/  /' || echo "  None found"
    echo ""
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate documentation report
generate_report() {
    echo -e "${GREEN}Generating documentation report...${NC}\n"

    local report_file="$OUTPUT_DIR/documentation_report_$(date +%Y%m%d_%H%M%S).md"

    {
        echo "# Documentation Report"
        echo "Generated: $(date)"
        echo ""
        echo "## Files by Documentation Level"
        echo ""

        # Well documented (>50 doc lines)
        echo "### ✅ Well Documented (>50 doc lines)"
        echo ""
        find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | while read file; do
            doc_lines=$(count_doc_lines "$file")
            if [ "$doc_lines" -gt 50 ]; then
                rel_path=${file#$COURIER_APP_DIR/}
                echo "- $rel_path ($doc_lines lines)"
            fi
        done
        echo ""

        # Partially documented (10-50 doc lines)
        echo "### ⚠️ Partially Documented (10-50 doc lines)"
        echo ""
        find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | while read file; do
            doc_lines=$(count_doc_lines "$file")
            if [ "$doc_lines" -ge 10 ] && [ "$doc_lines" -le 50 ]; then
                rel_path=${file#$COURIER_APP_DIR/}
                echo "- $rel_path ($doc_lines lines)"
            fi
        done
        echo ""

        # Poorly documented (<10 doc lines)
        echo "### ❌ Poorly Documented (<10 doc lines)"
        echo ""
        find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | while read file; do
            doc_lines=$(count_doc_lines "$file")
            if [ "$doc_lines" -lt 10 ]; then
                rel_path=${file#$COURIER_APP_DIR/}
                echo "- $rel_path ($doc_lines lines)"
            fi
        done
        echo ""

        # Files with IMPROVEMENT flags
        echo "## Files with IMPROVEMENT Flags"
        echo ""
        find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | while read file; do
            if [ "$(has_improvements "$file")" = "yes" ]; then
                rel_path=${file#$COURIER_APP_DIR/}
                echo "### $rel_path"
                echo ""
                grep -B 2 -A 3 "IMPROVEMENT:" "$file" | sed 's/^/    /'
                echo ""
            fi
        done

    } > "$report_file"

    echo -e "${GREEN}Report generated: $report_file${NC}"
    echo ""
}

# List files needing documentation
list_undocumented() {
    echo -e "${YELLOW}Files with <10 documentation lines:${NC}\n"

    find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | while read file; do
        doc_lines=$(count_doc_lines "$file")
        if [ "$doc_lines" -lt 10 ]; then
            rel_path=${file#$COURIER_APP_DIR/}
            echo -e "  ${RED}❌${NC} $rel_path (${doc_lines} lines)"
        fi
    done
}

# Show files with IMPROVEMENT flags
list_improvements() {
    echo -e "${YELLOW}Files with IMPROVEMENT flags:${NC}\n"

    find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | while read file; do
        if [ "$(has_improvements "$file")" = "yes" ]; then
            rel_path=${file#$COURIER_APP_DIR/}
            echo -e "  ${YELLOW}⚠️${NC} $rel_path"
            extract_improvements "$file"
        fi
    done
}

# Show statistics
show_stats() {
    echo -e "${BLUE}Documentation Statistics:${NC}\n"

    total_files=$(find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | wc -l)
    well_documented=$(find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | while read file; do
        [ $(count_doc_lines "$file") -gt 50 ] && echo "1"
    done | wc -l)
    partial=$(find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | while read file; do
        doc_lines=$(count_doc_lines "$file")
        [ "$doc_lines" -ge 10 ] && [ "$doc_lines" -le 50 ] && echo "1"
    done | wc -l)
    poor=$(find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | while read file; do
        [ $(count_doc_lines "$file") -lt 10 ] && echo "1"
    done | wc -l)

    with_improvements=$(find "$COURIER_APP_DIR/lib" -name "*.dart" -type f | while read file; do
        [ "$(has_improvements "$file")" = "yes" ] && echo "1"
    done | wc -l)

    echo "Total Dart files: $total_files"
    echo ""
    echo -e "${GREEN}✅ Well documented (>50 lines): $well_documented${NC}"
    echo -e "${YELLOW}⚠️ Partially documented (10-50 lines): $partial${NC}"
    echo -e "${RED}❌ Poorly documented (<10 lines): $poor${NC}"
    echo ""
    echo -e "${YELLOW}Files with IMPROVEMENT flags: $with_improvements${NC}"
    echo ""
}

# Main menu
case "${1:-menu}" in
    stats)
        show_stats
        ;;
    undocumented)
        list_undocumented
        ;;
    improvements)
        list_improvements
        ;;
    report)
        generate_report
        ;;
    menu)
        echo "Usage: $0 {stats|undocumented|improvements|report}"
        echo ""
        echo "Commands:"
        echo "  stats         - Show documentation statistics"
        echo "  undocumented  - List files needing documentation"
        echo "  improvements  - List all IMPROVEMENT flags"
        echo "  report        - Generate full documentation report"
        echo ""
        show_stats
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Use: $0 menu"
        exit 1
        ;;
esac
