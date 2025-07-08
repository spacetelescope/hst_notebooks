#!/bin/bash
# Quick diagnostic script for test-local-ci.sh hanging issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "🔍 Local CI Diagnostic Tool"
echo "==========================="
echo

# Check Python environment
log_info "Checking Python environment..."
python3 --version
which python3

# Check virtual environment
if [ -d "venv" ]; then
    log_info "Virtual environment exists"
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
        log_success "Activated virtual environment"
        which python
        python --version
    else
        log_warning "Virtual environment exists but activation script not found"
    fi
else
    log_warning "No virtual environment found"
fi

# Check package managers
log_info "Checking package managers..."
if command -v uv &> /dev/null; then
    log_success "uv is available: $(which uv)"
    uv --version
else
    log_warning "uv not available"
fi

if command -v pip &> /dev/null; then
    log_success "pip is available: $(which pip)"
    pip --version
else
    log_error "pip not available"
fi

# Check dependency files
log_info "Checking dependency files..."
if [ -f "requirements.txt" ]; then
    file_size=$(wc -l < requirements.txt)
    log_info "requirements.txt found ($file_size lines)"
    echo "First 10 lines:"
    head -10 requirements.txt | sed 's/^/  /'
    
    # Check for potentially problematic packages
    if grep -E "(astropy|numpy|scipy|matplotlib)" requirements.txt >/dev/null; then
        log_warning "Large scientific packages detected - may take longer to install"
    fi
    
    if grep -E "(jwst|crds|stsynphot)" requirements.txt >/dev/null; then
        log_warning "STScI-specific packages detected - may require special handling"
    fi
else
    log_info "No requirements.txt found"
fi

if [ -f "pyproject.toml" ]; then
    log_info "pyproject.toml found"
else
    log_info "No pyproject.toml found"
fi

# Check network connectivity
log_info "Checking network connectivity..."
if ping -c 1 pypi.org >/dev/null 2>&1; then
    log_success "PyPI is reachable"
else
    log_warning "PyPI may not be reachable"
fi

# Check disk space
log_info "Checking disk space..."
df -h . | tail -1

# Check for existing installations
log_info "Checking existing package installations..."
packages=("jupyter" "nbval" "nbconvert" "bandit")
for pkg in "${packages[@]}"; do
    if python -c "import $pkg" 2>/dev/null; then
        log_success "$pkg is already installed"
    else
        log_info "$pkg not installed"
    fi
done

# Test quick installation
log_info "Testing quick package installation..."
echo "Testing: pip install --dry-run requests"
if timeout 30 pip install --dry-run requests >/dev/null 2>&1; then
    log_success "Pip installation test passed"
else
    log_warning "Pip installation test failed or timed out"
fi

if command -v uv &> /dev/null; then
    echo "Testing: uv pip install --dry-run requests"
    if timeout 30 uv pip install --dry-run requests >/dev/null 2>&1; then
        log_success "UV installation test passed"
    else
        log_warning "UV installation test failed or timed out"
    fi
fi

echo
echo "🏥 Recommended Solutions:"
echo "========================"

if [ ! -d "venv" ]; then
    echo "1. Create virtual environment first:"
    echo "   python3 -m venv venv && source venv/bin/activate"
fi

if [ -f "requirements.txt" ]; then
    file_size=$(wc -l < requirements.txt)
    if [ "$file_size" -gt 50 ]; then
        echo "2. For large requirements.txt, try:"
        echo "   SKIP_DEPS=true ./scripts/test-local-ci.sh"
        echo "   # Then install deps manually in smaller chunks"
    fi
fi

echo "3. Skip dependency installation and test with existing packages:"
echo "   SKIP_DEPS=true ./scripts/test-local-ci.sh"

echo "4. Test only workflow validation (fastest):"
echo "   ./scripts/validate-workflows.sh"

echo "5. Use validation-only mode:"
echo "   EXECUTION_MODE=validation-only ./scripts/test-local-ci.sh"

echo "6. Force kill hanging processes:"
echo "   pkill -f 'test-local-ci'"

echo
log_success "Diagnostic complete!"
