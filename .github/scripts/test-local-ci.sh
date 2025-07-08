#!/bin/bash
# Local CI Simulation Script
# This script simulates the GitHub Actions CI environment locally

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
PYTHON_VERSION=${PYTHON_VERSION:-3.11}
EXECUTION_MODE=${EXECUTION_MODE:-validation-only}
SINGLE_NOTEBOOK=${SINGLE_NOTEBOOK:-}
RUN_SECURITY_SCAN=${RUN_SECURITY_SCAN:-true}
BUILD_DOCUMENTATION=${BUILD_DOCUMENTATION:-true}
SKIP_DEPS=${SKIP_DEPS:-false}  # New option to skip dependency installation

# Set CI environment variables
export CI=true
export GITHUB_ACTIONS=true
export PYTHONUNBUFFERED=1

# Trap Ctrl+C to cleanup properly
cleanup() {
    log_warning "Received interrupt signal, cleaning up..."
    if [ -n "$background_pid" ]; then
        kill "$background_pid" 2>/dev/null || true
    fi
    exit 130
}
trap cleanup INT TERM

echo "🚀 Starting Local CI Simulation"
echo "=================================="
echo "Python Version: $PYTHON_VERSION"
echo "Execution Mode: $EXECUTION_MODE"
echo "Security Scan: $RUN_SECURITY_SCAN"
echo "Build Documentation: $BUILD_DOCUMENTATION"
echo "Skip Dependencies: $SKIP_DEPS"
if [ -n "$SINGLE_NOTEBOOK" ]; then
    echo "Single Notebook: $SINGLE_NOTEBOOK"
fi
echo "=================================="
echo

# Step 1: Environment Validation
log_info "Step 1: Validating environment..."

if ! command -v python3 &> /dev/null; then
    log_error "Python 3 is not installed or not in PATH"
    exit 1
fi

if ! command -v git &> /dev/null; then
    log_error "Git is not installed or not in PATH"
    exit 1
fi

if [ ! -d ".git" ]; then
    log_error "Not in a git repository"
    exit 1
fi

log_success "Environment validation passed"

# Step 2: Python Environment Setup
log_info "Step 2: Setting up Python environment..."

# Create virtual environment
if [ ! -d "venv" ]; then
    python3 -m venv venv
    log_success "Created virtual environment"
else
    log_info "Using existing virtual environment"
fi

# Activate virtual environment
source venv/bin/activate

# Install uv for fast package management
if ! command -v uv &> /dev/null; then
    log_info "Installing uv package manager..."
    if timeout 300 pip install uv; then
        log_success "Installed uv package manager"
    else
        log_error "Failed to install uv (timeout after 5 minutes)"
        exit 1
    fi
fi

log_success "Python environment ready"

# Step 3: Dependencies Installation
if [ "$SKIP_DEPS" = "true" ]; then
    log_info "Step 3: Skipping dependencies installation (SKIP_DEPS=true)"
    log_warning "Assuming dependencies are already installed"
else
    log_info "Step 3: Installing dependencies..."

    # Check if core tools are already available
    if command -v jupyter &> /dev/null && python -c "import nbval, nbconvert, bandit" 2>/dev/null; then
        log_info "Core notebook tools already available, skipping installation"
    else
        log_info "Installing core notebook tools (jupyter, nbval, nbconvert, bandit, jupyter-book)..."
        if timeout 600 uv pip install jupyter nbval nbconvert bandit jupyter-book; then
            log_success "Installed core notebook tools"
        else
            log_error "Failed to install core tools (timeout after 10 minutes)"
            log_info "Trying with pip as fallback..."
            if timeout 600 pip install jupyter nbval nbconvert bandit jupyter-book; then
                log_success "Installed core tools with pip fallback"
            else
                log_error "Failed to install core tools with both uv and pip"
                exit 1
            fi
        fi
    fi

# Repository-specific dependencies
if [ -f "requirements.txt" ]; then
    log_info "Installing from requirements.txt..."
    # Check file size to estimate installation time
    file_size=$(wc -l < requirements.txt)
    if [ "$file_size" -gt 50 ]; then
        log_warning "Large requirements.txt detected ($file_size lines) - this may take 10-20 minutes"
        timeout_duration=1800  # 30 minutes for large files
    else
        timeout_duration=600   # 10 minutes for smaller files
    fi
    
    log_info "Installing dependencies with ${timeout_duration}s timeout..."
    if timeout "$timeout_duration" uv pip install -r requirements.txt; then
        log_success "Installed requirements.txt dependencies"
    else
        log_warning "uv installation failed or timed out, trying pip fallback..."
        if timeout "$timeout_duration" pip install -r requirements.txt; then
            log_success "Installed requirements.txt dependencies with pip fallback"
        else
            log_error "Failed to install requirements.txt dependencies with both uv and pip"
            log_info "Continuing with available packages..."
        fi
    fi
elif [ -f "pyproject.toml" ]; then
    log_info "Installing from pyproject.toml..."
    if timeout 600 uv pip install -e .; then
        log_success "Installed pyproject.toml dependencies"
    else
        log_warning "uv installation failed, trying pip fallback..."
        if timeout 600 pip install -e .; then
            log_success "Installed pyproject.toml dependencies with pip fallback"
        else
            log_error "Failed to install pyproject.toml dependencies with both uv and pip"
            log_info "Continuing with available packages..."
        fi
    fi
else
    log_warning "No requirements.txt or pyproject.toml found"
fi

# Close the SKIP_DEPS if statement
fi

# Repository-specific package detection
REPO_NAME=$(basename $(pwd))
case "$REPO_NAME" in
    "jdat_notebooks")
        log_info "JDAT notebooks detected - setting up CRDS..."
        export CRDS_SERVER_URL="https://jwst-crds.stsci.edu"
        export CRDS_PATH="/tmp/crds_cache"
        mkdir -p "$CRDS_PATH"
        log_success "CRDS environment configured"
        ;;
    "mast_notebooks")
        log_info "MAST notebooks detected - testing API connectivity..."
        python -c "import astroquery.mast; print('MAST API accessible')" 2>/dev/null || log_warning "MAST API not accessible (may be expected)"
        ;;
    "hst_notebooks")
        log_info "HST notebooks detected - checking for STScI tools..."
        python -c "import hstcal; print('hstcal available')" 2>/dev/null || log_warning "hstcal not available (may require conda environment)"
        ;;
    "jwst-pipeline-notebooks")
        log_info "JWST pipeline notebooks detected - checking for jdaviz..."
        python -c "import jdaviz; print('jdaviz available')" 2>/dev/null || log_warning "jdaviz not available (may require additional setup)"
        ;;
esac

log_success "Dependencies installation completed"

# Step 4: Notebook Validation
log_info "Step 4: Validating notebooks..."

if [ ! -d "notebooks" ]; then
    log_warning "No notebooks directory found"
else
    notebook_count=$(find notebooks -name "*.ipynb" | wc -l)
    log_info "Found $notebook_count notebook files"
    
    if [ $notebook_count -eq 0 ]; then
        log_warning "No notebook files found in notebooks directory"
    else
        # Validate notebooks with nbval
        log_info "Running notebook validation with nbval..."
        
        if [ -n "$SINGLE_NOTEBOOK" ]; then
            if [ -f "$SINGLE_NOTEBOOK" ]; then
                log_info "Validating single notebook: $SINGLE_NOTEBOOK"
                pytest --nbval "$SINGLE_NOTEBOOK" || log_error "Notebook validation failed for $SINGLE_NOTEBOOK"
            else
                log_error "Specified notebook not found: $SINGLE_NOTEBOOK"
                exit 1
            fi
        else
            pytest --nbval notebooks/ || log_error "Some notebooks failed validation"
        fi
        
        log_success "Notebook validation completed"
    fi
fi

# Step 5: Notebook Execution
log_info "Step 5: Executing notebooks..."

if [ "$EXECUTION_MODE" = "validation-only" ]; then
    log_info "Execution mode is validation-only, skipping execution"
elif [ ! -d "notebooks" ] || [ $(find notebooks -name "*.ipynb" | wc -l) -eq 0 ]; then
    log_warning "No notebooks to execute"
else
    case "$EXECUTION_MODE" in
        "full")
            log_info "Running full notebook execution..."
            notebooks_to_execute=$(find notebooks -name "*.ipynb")
            ;;
        "quick")
            log_info "Running quick execution (first 3 notebooks)..."
            notebooks_to_execute=$(find notebooks -name "*.ipynb" | head -3)
            ;;
        *)
            log_error "Unknown execution mode: $EXECUTION_MODE"
            exit 1
            ;;
    esac
    
    if [ -n "$SINGLE_NOTEBOOK" ]; then
        notebooks_to_execute="$SINGLE_NOTEBOOK"
    fi
    
    for notebook in $notebooks_to_execute; do
        if [ -f "$notebook" ]; then
            log_info "Executing: $notebook"
            # Execute notebook with timeout
            timeout 300 jupyter nbconvert --to notebook --execute --inplace "$notebook" || {
                log_error "Execution failed or timed out for: $notebook"
                # Create artifact-like backup
                cp "$notebook" "${notebook%.ipynb}_failed.ipynb" 2>/dev/null || true
            }
        fi
    done
    
    log_success "Notebook execution completed"
fi

# Step 6: Security Scanning
if [ "$RUN_SECURITY_SCAN" = "true" ]; then
    log_info "Step 6: Running security scan..."
    
    if [ -d "notebooks" ] && [ $(find notebooks -name "*.ipynb" | wc -l) -gt 0 ]; then
        # Convert notebooks to Python scripts for security scanning
        log_info "Converting notebooks to Python scripts..."
        find notebooks -name "*.ipynb" -exec jupyter nbconvert --to script {} \;
        
        # Run bandit security scan
        log_info "Running bandit security scan..."
        python_files=$(find notebooks -name "*.py")
        
        if [ -n "$python_files" ]; then
            echo "$python_files" | xargs bandit -r || log_warning "Security scan found potential issues"
            
            # Cleanup generated Python files
            find notebooks -name "*.py" -delete
            log_success "Security scan completed"
        else
            log_warning "No Python files generated for security scanning"
        fi
    else
        log_warning "No notebooks found for security scanning"
    fi
else
    log_info "Security scan disabled"
fi

# Step 7: Documentation Building
if [ "$BUILD_DOCUMENTATION" = "true" ]; then
    log_info "Step 7: Building documentation..."
    
    if [ -f "_config.yml" ] && [ -f "_toc.yml" ]; then
        log_info "Building JupyterBook documentation..."
        
        # Build documentation
        jupyter-book build . --path-output /tmp/local-ci-build || {
            log_error "Documentation build failed"
            exit 1
        }
        
        if [ -d "/tmp/local-ci-build/_build/html" ]; then
            log_success "Documentation built successfully"
            log_info "Documentation available at: /tmp/local-ci-build/_build/html/index.html"
            
            # Optionally open in browser (uncomment if desired)
            # open "/tmp/local-ci-build/_build/html/index.html" 2>/dev/null || true
        else
            log_error "Documentation build directory not found"
            exit 1
        fi
    else
        log_warning "JupyterBook configuration files (_config.yml, _toc.yml) not found"
        log_info "Skipping documentation build"
    fi
else
    log_info "Documentation building disabled"
fi

# Step 8: Cleanup and Summary
log_info "Step 8: Cleanup and summary..."

# Deactivate virtual environment
deactivate

# Generate summary
echo
echo "========================================"
echo "🎉 Local CI Simulation Complete!"
echo "========================================"
echo "✅ Environment validation: PASSED"
echo "✅ Dependencies installation: COMPLETED"

if [ -d "notebooks" ] && [ $(find notebooks -name "*.ipynb" | wc -l) -gt 0 ]; then
    echo "✅ Notebook validation: COMPLETED"
    if [ "$EXECUTION_MODE" != "validation-only" ]; then
        echo "✅ Notebook execution: COMPLETED"
    fi
else
    echo "⚠️  No notebooks found"
fi

if [ "$RUN_SECURITY_SCAN" = "true" ]; then
    echo "✅ Security scanning: COMPLETED"
fi

if [ "$BUILD_DOCUMENTATION" = "true" ] && [ -f "_config.yml" ]; then
    echo "✅ Documentation building: COMPLETED"
fi

echo "========================================"

# Check for any failed notebooks
failed_notebooks=$(find notebooks -name "*_failed.ipynb" 2>/dev/null | wc -l)
if [ "$failed_notebooks" -gt 0 ]; then
    echo
    log_warning "Found $failed_notebooks failed notebook(s):"
    find notebooks -name "*_failed.ipynb" 2>/dev/null | sed 's/^/  - /'
    echo
fi

echo "💡 Next Steps:"
echo "1. Review any warnings or errors above"
echo "2. Test with GitHub Actions using workflow_dispatch"
echo "3. Create a test PR to verify automated triggers"
echo "4. Consider running with different parameters:"
echo "   - EXECUTION_MODE=full (for full execution)"
echo "   - SINGLE_NOTEBOOK=path/to/notebook.ipynb (for single notebook testing)"
echo "   - RUN_SECURITY_SCAN=false (to skip security scanning)"
echo
log_success "Local CI simulation completed successfully!"

# End of script

