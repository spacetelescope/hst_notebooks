#!/bin/bash
# Repository validation script for migration readiness
# Usage: ./validate-repository.sh <repository_name>

set -e

REPO_NAME="$1"
ORG_NAME="${2:-spacetelescope}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

if [ -z "$REPO_NAME" ]; then
    log_error "Usage: $0 <repository_name> [org_name]"
    exit 1
fi

echo "========================================"
echo "Migration Readiness Check: $REPO_NAME"
echo "========================================"
echo

# Check 1: Repository structure
log_info "Checking repository structure..."
if [ -d ".git" ]; then
    log_success "Git repository detected"
else
    log_error "Not a git repository"
    exit 1
fi

if [ -d "notebooks" ]; then
    log_success "notebooks/ directory found"
    notebook_count=$(find notebooks -name "*.ipynb" | wc -l)
    log_info "Found $notebook_count notebook files"
else
    log_warning "No notebooks/ directory found"
fi

# Check 2: Current workflows
log_info "Analyzing current workflows..."
if [ -d ".github/workflows" ]; then
    workflow_count=$(find .github/workflows -name "*.yml" -o -name "*.yaml" | wc -l)
    if [ $workflow_count -gt 0 ]; then
        log_success "Found $workflow_count existing workflow files"
        echo "   Current workflows:"
        find .github/workflows -name "*.yml" -o -name "*.yaml" | sed 's/^/   - /'
    else
        log_warning "No workflow files found in .github/workflows/"
    fi
else
    log_warning "No .github/workflows/ directory found"
fi

# Check 3: JupyterBook configuration
log_info "Checking JupyterBook configuration..."
if [ -f "_config.yml" ]; then
    log_success "_config.yml found"
else
    log_warning "_config.yml not found (needed for documentation building)"
fi

if [ -f "_toc.yml" ]; then
    log_success "_toc.yml found"
else
    log_warning "_toc.yml not found (needed for documentation building)"
fi

# Check 4: Repository-specific requirements
log_info "Checking repository-specific requirements..."
case "$REPO_NAME" in
    "hst_notebooks")
        log_info "HST repository - checking for STScI requirements..."
        if grep -r "hstcal\|drizzle\|stsynphot" notebooks/ >/dev/null 2>&1; then
            log_success "HST-specific tools detected in notebooks"
        else
            log_warning "No HST-specific tools found in notebooks"
        fi
        ;;
    "jwst-pipeline-notebooks")
        log_info "JWST repository - checking for pipeline requirements..."
        if grep -r "jwst\|jdaviz\|stdatamodels" notebooks/ >/dev/null 2>&1; then
            log_success "JWST-specific tools detected in notebooks"
        else
            log_warning "No JWST-specific tools found in notebooks"
        fi
        if [ -f "scripts/jdaviz_image_replacement.sh" ]; then
            log_success "jdaviz image replacement script found"
        else
            log_warning "jdaviz image replacement script not found"
        fi
        ;;
    "jdat_notebooks")
        log_info "JDAT repository - checking for data analysis tools..."
        if grep -r "astropy\|photutils\|specutils" notebooks/ >/dev/null 2>&1; then
            log_success "JDAT-specific tools detected in notebooks"
        else
            log_warning "No JDAT-specific tools found in notebooks"
        fi
        ;;
    "mast_notebooks")
        log_info "MAST repository - checking for archive access..."
        if grep -r "astroquery\|mast" notebooks/ >/dev/null 2>&1; then
            log_success "MAST/astroquery tools detected in notebooks"
        else
            log_warning "No MAST-specific tools found in notebooks"
        fi
        ;;
    "hello_universe")
        log_info "Educational repository - checking for beginner content..."
        if grep -r "# Introduction\|Getting Started\|Tutorial" notebooks/ >/dev/null 2>&1; then
            log_success "Educational content patterns detected"
        else
            log_warning "No clear educational patterns found"
        fi
        ;;
esac

# Check 5: Dependencies
log_info "Checking dependency files..."
dep_files=("requirements.txt" "pyproject.toml" "setup.py")
found_deps=false
for dep_file in "${dep_files[@]}"; do
    if [ -f "$dep_file" ]; then
        log_success "Found dependency file: $dep_file"
        found_deps=true
        
        # Additional checks for specific files
        case "$dep_file" in
            "requirements.txt"|"pyproject.toml")
                log_info "Python package file detected - uv will be primary package manager"
                ;;
            "setup.py")
                log_info "Setup.py detected - repository may need modernization to pyproject.toml"
                ;;
        esac
    fi
done

# Check for Jupyter Book configuration
if [ -f "_config.yml" ] && [ -f "_toc.yml" ]; then
    log_success "Jupyter Book configuration found (_config.yml, _toc.yml)"
    found_deps=true
elif [ -f "_config.yml" ] || [ -f "_toc.yml" ]; then
    log_warning "Partial Jupyter Book configuration found - both _config.yml and _toc.yml are recommended"
    found_deps=true
fi

if [ "$found_deps" = false ]; then
    log_warning "No dependency files found (requirements.txt, pyproject.toml, etc.)"
fi

# Check 6: Git status
log_info "Checking git status..."
if [ -n "$(git status --porcelain)" ]; then
    log_warning "Repository has uncommitted changes"
    log_info "Consider committing changes before migration"
else
    log_success "Repository is clean (no uncommitted changes)"
fi

# Check 7: Remote repository
log_info "Checking remote configuration..."
if git remote get-url origin >/dev/null 2>&1; then
    remote_url=$(git remote get-url origin)
    log_success "Remote origin configured: $remote_url"
    
    if [[ "$remote_url" == *"$ORG_NAME/$REPO_NAME"* ]]; then
        log_success "Remote URL matches expected repository"
    else
        log_warning "Remote URL doesn't match expected pattern"
    fi
else
    log_warning "No remote origin configured"
fi

# Check 8: Branch information
log_info "Checking branch information..."
current_branch=$(git branch --show-current)
log_info "Current branch: $current_branch"

if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
    log_success "On main/master branch"
else
    log_warning "Not on main/master branch"
fi

# Check 9: Repository permissions (if GitHub CLI available)
if command -v gh >/dev/null 2>&1; then
    log_info "Checking GitHub repository permissions..."
    if gh repo view "$ORG_NAME/$REPO_NAME" >/dev/null 2>&1; then
        log_success "Repository accessible via GitHub CLI"
        
        # Check if Actions are enabled
        if gh api "repos/$ORG_NAME/$REPO_NAME" --jq '.has_actions' | grep -q true; then
            log_success "GitHub Actions enabled"
        else
            log_warning "GitHub Actions may not be enabled"
        fi
    else
        log_warning "Cannot access repository via GitHub CLI"
    fi
else
    log_info "GitHub CLI not available - skipping permission checks"
fi

echo
echo "========================================"
echo "Migration Readiness Summary"
echo "========================================"

# Generate readiness score
score=0
max_score=10

# Required checks
[ -d ".git" ] && ((score++))
[ -d "notebooks" ] && ((score++))
[ -f "_config.yml" ] && ((score++))
[ -f "_toc.yml" ] && ((score++))

# Workflow checks
[ -d ".github/workflows" ] && ((score++))

# Dependencies
for dep_file in "${dep_files[@]}"; do
    [ -f "$dep_file" ] && ((score++)) && break
done

# Git status
[ -z "$(git status --porcelain)" ] && ((score++))

# Remote
git remote get-url origin >/dev/null 2>&1 && ((score++))

# Branch
current_branch=$(git branch --show-current)
if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
    ((score++))
fi

# GitHub access
if command -v gh >/dev/null 2>&1 && gh repo view "$ORG_NAME/$REPO_NAME" >/dev/null 2>&1; then
    ((score++))
fi

percentage=$((score * 100 / max_score))

echo "Readiness Score: $score/$max_score ($percentage%)"
echo

if [ $percentage -ge 80 ]; then
    log_success "Repository is ready for migration!"
    echo "✅ You can proceed with migration using:"
    echo "   ./scripts/migrate-repository.sh $REPO_NAME $ORG_NAME"
elif [ $percentage -ge 60 ]; then
    log_warning "Repository is mostly ready, but has some issues"
    echo "⚠️  Address warnings above before migration"
else
    log_error "Repository needs significant preparation before migration"
    echo "❌ Address errors above before proceeding"
fi

echo
echo "📋 Migration checklist: docs/repository-migration-checklist.md"
echo "🔧 Migration script: scripts/migrate-repository.sh"
