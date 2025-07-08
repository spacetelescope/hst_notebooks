#!/bin/bash
# Workflow Validation Script
# Validates GitHub Actions workflows for syntax and common issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration
WORKFLOWS_DIR=".github/workflows"
VALIDATE_ACT=${VALIDATE_ACT:-true}
VERBOSE=${VERBOSE:-false}

echo "🔍 GitHub Actions Workflow Validation"
echo "====================================="
echo "Workflows Directory: $WORKFLOWS_DIR"
echo "Validate with Act: $VALIDATE_ACT"
echo "====================================="
echo

# Check if workflows directory exists
if [ ! -d "$WORKFLOWS_DIR" ]; then
    log_error "Workflows directory not found: $WORKFLOWS_DIR"
    exit 1
fi

# Find all workflow files
workflow_files=$(find "$WORKFLOWS_DIR" -name "*.yml" -o -name "*.yaml" 2>/dev/null)
workflow_count=$(echo "$workflow_files" | wc -w)

if [ $workflow_count -eq 0 ]; then
    log_error "No workflow files found in $WORKFLOWS_DIR"
    exit 1
fi

log_info "Found $workflow_count workflow file(s)"
echo

# Validation counters
passed_count=0
warning_count=0
error_count=0

# Function to validate YAML syntax
validate_yaml() {
    local file="$1"
    
    if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to validate workflow structure
validate_workflow_structure() {
    local file="$1"
    local errors=()
    
    # Check for required fields
    if ! grep -q "^name:" "$file"; then
        errors+=("Missing 'name' field")
    fi
    
    if ! grep -q "^on:" "$file"; then
        errors+=("Missing 'on' field")
    fi
    
    if ! grep -q "^jobs:" "$file"; then
        errors+=("Missing 'jobs' field")
    fi
    
    # Check for placeholder references
    if grep -q "your-org\|dev-actions" "$file"; then
        errors+=("Contains placeholder references (your-org, dev-actions)")
    fi
    
    # Check for common issues
    if grep -q "uses: \./\." "$file"; then
        errors+=("Uses local action reference (./.) - may not work in CI")
    fi
    
    # Return errors
    if [ ${#errors[@]} -gt 0 ]; then
        printf '%s\n' "${errors[@]}"
        return 1
    fi
    
    return 0
}

# Function to validate workflow with Act
validate_with_act() {
    local file="$1"
    
    if ! command -v act &> /dev/null; then
        return 2  # Act not available
    fi
    
    # Test with act dry run
    if act --dryrun --workflow "$file" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main validation loop
for workflow_file in $workflow_files; do
    if [ "$VERBOSE" = "true" ]; then
        echo "----------------------------------------"
    fi
    
    log_info "Validating: $(basename "$workflow_file")"
    
    file_errors=0
    
    # 1. YAML Syntax Validation
    if validate_yaml "$workflow_file"; then
        if [ "$VERBOSE" = "true" ]; then
            log_success "  YAML syntax: VALID"
        fi
    else
        log_error "  YAML syntax: INVALID"
        ((file_errors++))
    fi
    
    # 2. Workflow Structure Validation
    structure_errors=$(validate_workflow_structure "$workflow_file" 2>&1)
    if [ $? -eq 0 ]; then
        if [ "$VERBOSE" = "true" ]; then
            log_success "  Structure: VALID"
        fi
    else
        log_error "  Structure issues:"
        echo "$structure_errors" | sed 's/^/    - /'
        ((file_errors++))
    fi
    
    # 3. Act Validation (if enabled and available)
    if [ "$VALIDATE_ACT" = "true" ]; then
        act_result=$(validate_with_act "$workflow_file")
        case $act_result in
            0)
                if [ "$VERBOSE" = "true" ]; then
                    log_success "  Act validation: PASSED"
                fi
                ;;
            1)
                log_warning "  Act validation: FAILED"
                ((warning_count++))
                ;;
            2)
                if [ "$VERBOSE" = "true" ]; then
                    log_info "  Act validation: SKIPPED (act not installed)"
                fi
                ;;
        esac
    fi
    
    # Summary for this file
    if [ $file_errors -eq 0 ]; then
        log_success "$(basename "$workflow_file"): PASSED"
        ((passed_count++))
    else
        log_error "$(basename "$workflow_file"): FAILED ($file_errors error(s))"
        ((error_count++))
    fi
    
    echo
done

# Overall summary
echo "========================================"
echo "📊 Validation Summary"
echo "========================================"
echo "Total workflows: $workflow_count"
echo "✅ Passed: $passed_count"
echo "⚠️  Warnings: $warning_count"
echo "❌ Errors: $error_count"
echo "========================================"

# Additional checks and recommendations
echo
log_info "Additional Checks and Recommendations:"

# Check for common workflow patterns
if find "$WORKFLOWS_DIR" -name "*.yml" -exec grep -l "workflow_call" {} \; | wc -l | grep -q "0"; then
    log_info "  No reusable workflows detected"
else
    reusable_count=$(find "$WORKFLOWS_DIR" -name "*.yml" -exec grep -l "workflow_call" {} \; | wc -l)
    log_info "  Found $reusable_count reusable workflow(s)"
fi

# Check for secrets usage
if find "$WORKFLOWS_DIR" -name "*.yml" -exec grep -l "secrets\." {} \; | wc -l | grep -q "0"; then
    log_info "  No secrets usage detected"
else
    secrets_count=$(find "$WORKFLOWS_DIR" -name "*.yml" -exec grep -l "secrets\." {} \; | wc -l)
    log_info "  Found secrets usage in $secrets_count workflow(s)"
fi

# Check for workflow dependencies
if find "$WORKFLOWS_DIR" -name "*.yml" -exec grep -l "needs:" {} \; | wc -l | grep -q "0"; then
    log_info "  No job dependencies detected"
else
    deps_count=$(find "$WORKFLOWS_DIR" -name "*.yml" -exec grep -l "needs:" {} \; | wc -l)
    log_info "  Found job dependencies in $deps_count workflow(s)"
fi

# Recommendations
echo
log_info "💡 Recommendations:"

if [ "$error_count" -gt 0 ]; then
    echo "  1. Fix syntax and structure errors before proceeding"
fi

if [ "$warning_count" -gt 0 ]; then
    echo "  2. Address Act validation warnings if using local testing"
fi

echo "  3. Test workflows with manual dispatch before enabling automatic triggers"
echo "  4. Verify all required secrets are configured in repository settings"
echo "  5. Consider using semantic versioning for workflow references"

# Exit with appropriate code
if [ "$error_count" -gt 0 ]; then
    log_error "Validation failed with $error_count error(s)"
    exit 1
elif [ "$warning_count" -gt 0 ]; then
    log_warning "Validation passed with $warning_count warning(s)"
    exit 0
else
    log_success "All workflows validated successfully!"
    exit 0
fi
