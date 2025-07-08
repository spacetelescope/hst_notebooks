# Scripts Directory

This directory contains automation scripts for migrating STScI notebook repositories to use the centralized GitHub Actions workflows.

## 📋 Table of Contents

- [Overview](#overview)
- [Scripts](#scripts)
  - [validate-repository.sh](#validate-repositorysh)
  - [migrate-repository.sh](#migrate-repositorysh)
  - [test-local-ci.sh](#test-local-cish)
  - [validate-workflows.sh](#validate-workflowssh)
  - [test-with-act.sh](#test-with-actsh)
- [Usage Examples](#usage-examples)
- [Repository-Specific Configurations](#repository-specific-configurations)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## 🎯 Overview

These scripts automate the migration process for the following STScI notebook repositories:

- **`jdat_notebooks`** - JWST Data Analysis Tools
- **`mast_notebooks`** - MAST Archive Tools and Examples  
- **`hst_notebooks`** - Hubble Space Telescope Analysis Tools
- **`hello_universe`** - Educational Astronomy Content
- **`jwst-pipeline-notebooks`** - JWST Pipeline and Analysis Tools

## 🔧 Scripts

### `validate-repository.sh`

**Purpose**: Pre-migration validation and readiness assessment

**Usage**:
```bash
./validate-repository.sh <repository_name> [org_name]
```

**What it checks**:
- ✅ Repository structure and required directories
- ✅ Notebook files and formats
- ✅ Existing workflow configurations
- ✅ Dependency files and package requirements
- ✅ Repository-specific requirements (CRDS, MAST APIs, etc.)
- ✅ Git status and branch cleanliness

**Output**: 
- Detailed validation report
- Readiness score (0-100%)
- Specific recommendations for preparation

**Example**:
```bash
# Validate jdat_notebooks repository
./validate-repository.sh jdat_notebooks spacetelescope

# Expected output:
# ========================================
# Migration Readiness Check: jdat_notebooks  
# ========================================
# 
# [✓] Repository structure validated
# [✓] Notebooks directory found (45 notebooks)
# [⚠] Some notebooks may need output stripping
# [✓] CRDS-specific tools detected
# 
# Readiness Score: 85% - Ready for migration
```

### `migrate-repository.sh`

**Purpose**: Automated migration to centralized workflows

**Usage**:
```bash
./migrate-repository.sh <repository_name> [org_name]
```

**What it does**:
1. **Creates migration branch** with backup of existing workflows
2. **Installs centralized workflows** from example templates
3. **Configures repository-specific settings** automatically
4. **Updates workflow references** to use the correct organization
5. **Creates migration tracking file** for progress monitoring
6. **Generates summary report** with next steps

**Safety features**:
- ✅ Automatic backup of existing workflows
- ✅ Branch-based migration (no direct main branch changes)
- ✅ Repository-specific validation before changes
- ✅ Detailed logging and error handling
- ✅ Rollback instructions in case of issues

**Example**:
```bash
# Migrate hello_universe repository
./migrate-repository.sh hello_universe spacetelescope

# Expected output:
# [INFO] Starting migration for hello_universe...
# [SUCCESS] Migration branch created: migrate-to-centralized-actions
# [SUCCESS] Workflows backed up to: .github/workflows-backup/
# [SUCCESS] New workflows installed: notebook-ci-pr.yml, notebook-ci-main.yml
# [SUCCESS] Repository-specific configuration applied
# [SUCCESS] Migration completed successfully
```

### `test-local-ci.sh` ⚡ **NEW**

**Purpose**: Local simulation of GitHub Actions CI pipeline without requiring GitHub runners

**Usage**:
```bash
./test-local-ci.sh
```

**Environment Variables**:
```bash
# Configuration options
export PYTHON_VERSION=3.11                    # Python version to use
export EXECUTION_MODE=validation-only         # validation-only, full, quick
export SINGLE_NOTEBOOK=path/to/notebook.ipynb # Test single notebook
export RUN_SECURITY_SCAN=true                 # Enable/disable security scanning
export BUILD_DOCUMENTATION=true               # Enable/disable documentation build
```

**What it does**:
- 🐍 Sets up Python virtual environment with specified version
- 📦 Installs dependencies using uv for fast package management
- ✅ Validates notebooks using nbval
- 🏃‍♂️ Executes notebooks based on execution mode
- 🔒 Runs security scanning with bandit
- 📖 Builds JupyterBook documentation
- 🎯 Repository-specific configurations (CRDS, MAST, HST, etc.)

**Example**:
```bash
# Basic validation
./test-local-ci.sh

# Full execution test
EXECUTION_MODE=full ./test-local-ci.sh

# Test single notebook
SINGLE_NOTEBOOK=notebooks/example.ipynb ./test-local-ci.sh

# Skip security scan for faster testing
RUN_SECURITY_SCAN=false ./test-local-ci.sh
```

### `validate-workflows.sh` ⚡ **NEW**

**Purpose**: Validate GitHub Actions workflow files for syntax and common issues

**Usage**:
```bash
./validate-workflows.sh
```

**Environment Variables**:
```bash
export VALIDATE_ACT=true    # Use Act for additional validation
export VERBOSE=true         # Detailed output
```

**What it validates**:
- 📝 YAML syntax correctness
- 🏗️ Workflow structure completeness
- 🚫 Placeholder references detection
- 🎭 Act-based workflow validation (if Act is installed)
- 💡 Best practices recommendations

**Example**:
```bash
# Basic validation
./validate-workflows.sh

# Verbose output
VERBOSE=true ./validate-workflows.sh

# Skip Act validation
VALIDATE_ACT=false ./validate-workflows.sh
```

### `test-with-act.sh` ⚡ **NEW**

**Purpose**: Run GitHub Actions workflows locally using Act (Docker-based GitHub Actions runner)

**Usage**:
```bash
./test-with-act.sh [event_type] [workflow_file] [job_name]
```

**Parameters**:
- `event_type`: pull_request, push, workflow_dispatch (default: pull_request)
- `workflow_file`: Specific workflow file to test (optional)
- `job_name`: Specific job to run (optional)

**Environment Variables**:
```bash
export DRY_RUN=true     # Validate without execution
export VERBOSE=true     # Detailed Act output
```

**What it does**:
- 🎭 Runs workflows locally using Act and Docker
- 📋 Creates sample event payloads for testing
- 🔧 Sets up Act configuration (.actrc)
- 🔐 Manages environment variables and secrets
- 📊 Provides detailed execution reports

**Prerequisites**:
- Docker installed and running
- Act installed (`brew install act` or equivalent)

**Examples**:
```bash
# Test pull request workflow
./test-with-act.sh pull_request

# Test specific workflow file
./test-with-act.sh push .github/workflows/notebook-ci-main.yml

# Test workflow dispatch with specific job
./test-with-act.sh workflow_dispatch '' test-notebooks

# Dry run validation
DRY_RUN=true ./test-with-act.sh pull_request

# Verbose execution
VERBOSE=true ./test-with-act.sh push
```

## 💡 Usage Examples

### Basic Migration Workflow

```bash
# Step 1: Validate repository readiness
cd /path/to/target/repository
../notebook-ci-actions/scripts/validate-repository.sh $(basename $(pwd)) spacetelescope

# Step 2: Run migration if readiness score > 80%
../notebook-ci-actions/scripts/migrate-repository.sh $(basename $(pwd)) spacetelescope

# Step 3: Review changes and test workflows
git log --oneline -5
git diff main..migrate-to-centralized-actions

# Step 4: Create pull request when ready
git push origin migrate-to-centralized-actions
```

### Batch Migration (All Repositories)

```bash
#!/bin/bash
# Migrate all STScI notebook repositories

REPOS=("hello_universe" "mast_notebooks" "jdat_notebooks" "hst_notebooks" "jwst-pipeline-notebooks")
ORG="spacetelescope"

for repo in "${REPOS[@]}"; do
    echo "=== Processing $repo ==="
    
    # Clone if not exists
    if [ ! -d "$repo" ]; then
        git clone "https://github.com/$ORG/$repo.git"
    fi
    
    cd "$repo"
    
    # Validate first
    echo "Validating $repo..."
    ../notebook-ci-actions/scripts/validate-repository.sh "$repo" "$ORG"
    
    # Migrate if validation passes
    echo "Migrating $repo..."
    ../notebook-ci-actions/scripts/migrate-repository.sh "$repo" "$ORG"
    
    cd ..
    echo "Completed $repo"
    echo
done
```

### Dry Run Validation

```bash
# Check all repositories without making changes
for repo in jdat_notebooks mast_notebooks hst_notebooks hello_universe jwst-pipeline-notebooks; do
    echo "=== $repo ==="
    if [ -d "$repo" ]; then
        cd "$repo"
        ../notebook-ci-actions/scripts/validate-repository.sh "$repo" spacetelescope | grep -E "(Score|WARNING|ERROR)"
        cd ..
    else
        echo "Repository not found: $repo"
    fi
    echo
done
```

## 🧪 Local Testing Examples ⚡ **NEW**

### Complete Local Testing Workflow

```bash
#!/bin/bash
# Complete local testing workflow for a repository

REPO_NAME=$(basename $(pwd))
echo "🚀 Starting comprehensive local testing for $REPO_NAME"

# Step 1: Validate workflows
echo "📋 Step 1: Validating workflow files..."
../notebook-ci-actions/scripts/validate-workflows.sh

# Step 2: Run local CI simulation
echo "🔬 Step 2: Running local CI simulation..."
../notebook-ci-actions/scripts/test-local-ci.sh

# Step 3: Test workflows with Act (if available)
if command -v act &> /dev/null; then
    echo "🎭 Step 3: Testing workflows with Act..."
    ../notebook-ci-actions/scripts/test-with-act.sh pull_request
else
    echo "⚠️  Step 3: Act not available, skipping workflow simulation"
fi

echo "✅ Local testing completed for $REPO_NAME"
```

### Repository-Specific Local Testing

```bash
# JDAT Notebooks - with CRDS environment
REPO_NAME=jdat_notebooks
cd "$REPO_NAME"

# Set CRDS environment
export CRDS_SERVER_URL="https://jwst-crds.stsci.edu"
export CRDS_PATH="/tmp/crds_cache"

# Test with full execution
EXECUTION_MODE=full ../notebook-ci-actions/scripts/test-local-ci.sh
```

```bash
# HST Notebooks - with micromamba environment  
REPO_NAME=hst_notebooks
cd "$REPO_NAME"

# Note: Micromamba setup happens automatically
# Test with validation only (hstcal may not be available locally)
EXECUTION_MODE=validation-only ../notebook-ci-actions/scripts/test-local-ci.sh
```

```bash
# Hello Universe - lightweight testing
REPO_NAME=hello_universe
cd "$REPO_NAME"

# Test with security scan disabled (educational content)
RUN_SECURITY_SCAN=false ../notebook-ci-actions/scripts/test-local-ci.sh
```

### Continuous Integration Simulation

```bash
#!/bin/bash
# Simulate GitHub Actions CI/CD pipeline locally

# Configuration
PYTHON_VERSIONS=("3.10" "3.11" "3.12")
EXECUTION_MODES=("validation-only" "quick" "full")

for py_version in "${PYTHON_VERSIONS[@]}"; do
    for exec_mode in "${EXECUTION_MODES[@]}"; do
        echo "🧪 Testing Python $py_version with $exec_mode execution..."
        
        PYTHON_VERSION="$py_version" \
        EXECUTION_MODE="$exec_mode" \
        ../notebook-ci-actions/scripts/test-local-ci.sh
        
        if [ $? -ne 0 ]; then
            echo "❌ Failed: Python $py_version with $exec_mode"
            break 2
        fi
    done
done

echo "✅ All CI simulation tests passed!"
```

### Act-based Workflow Testing

```bash
#!/bin/bash
# Comprehensive Act-based workflow testing

# Test different event types
EVENTS=("pull_request" "push" "workflow_dispatch")
WORKFLOWS=(.github/workflows/*.yml)

for event in "${EVENTS[@]}"; do
    echo "🎭 Testing $event events..."
    
    for workflow in "${WORKFLOWS[@]}"; do
        workflow_name=$(basename "$workflow")
        echo "  Testing $workflow_name with $event..."
        
        DRY_RUN=true ../notebook-ci-actions/scripts/test-with-act.sh \
            "$event" "$workflow"
            
        if [ $? -ne 0 ]; then
            echo "  ❌ Failed: $workflow_name with $event"
        else
            echo "  ✅ Passed: $workflow_name with $event"
        fi
    done
done
```

### Pre-Commit Testing Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit
# Automatic local testing before commits

echo "🔍 Running pre-commit validation..."

# Validate workflows
if ! ../notebook-ci-actions/scripts/validate-workflows.sh; then
    echo "❌ Workflow validation failed"
    exit 1
fi

# Quick CI test if notebooks changed
if git diff --cached --name-only | grep -q "\.ipynb$"; then
    echo "📓 Notebooks changed, running quick validation..."
    if ! EXECUTION_MODE=validation-only ../notebook-ci-actions/scripts/test-local-ci.sh; then
        echo "❌ Notebook validation failed"
        exit 1
    fi
fi

echo "✅ Pre-commit validation passed"
```

### Development Testing Scripts

```bash
# Create a development testing script
cat > test-development.sh << 'EOF'
#!/bin/bash
# Development testing script for notebook repositories

set -euo pipefail

# Configuration
REPO_NAME=$(basename $(pwd))
BRANCH_NAME=${1:-$(git branch --show-current)}

echo "🔬 Development Testing for $REPO_NAME"
echo "Branch: $BRANCH_NAME"
echo "======================================"

# Quick validation
echo "🚀 Step 1: Quick validation..."
EXECUTION_MODE=validation-only \
BUILD_DOCUMENTATION=false \
RUN_SECURITY_SCAN=false \
../notebook-ci-actions/scripts/test-local-ci.sh

# Workflow validation
echo "📋 Step 2: Workflow validation..."
../notebook-ci-actions/scripts/validate-workflows.sh

# Single notebook test (if specified)
if [ $# -eq 2 ]; then
    NOTEBOOK_PATH=$2
    echo "📓 Step 3: Testing single notebook: $NOTEBOOK_PATH"
    SINGLE_NOTEBOOK="$NOTEBOOK_PATH" \
    EXECUTION_MODE=full \
    ../notebook-ci-actions/scripts/test-local-ci.sh
fi

echo "✅ Development testing completed successfully!"
EOF

chmod +x test-development.sh
```

### Performance Benchmarking

```bash
#!/bin/bash
# Benchmark local testing performance

echo "⏱️  Benchmarking local testing performance..."

# Benchmark CI simulation
echo "Testing CI simulation speed..."
time ../notebook-ci-actions/scripts/test-local-ci.sh > /dev/null 2>&1

# Benchmark workflow validation  
echo "Testing workflow validation speed..."
time ../notebook-ci-actions/scripts/validate-workflows.sh > /dev/null 2>&1

# Benchmark Act execution (dry run)
if command -v act &> /dev/null; then
    echo "Testing Act dry run speed..."
    time DRY_RUN=true ../notebook-ci-actions/scripts/test-with-act.sh pull_request > /dev/null 2>&1
fi

echo "📊 Benchmarking completed!"
```

### Integration Testing

```bash
#!/bin/bash
# Integration testing between local and GitHub Actions

# Step 1: Local testing
echo "🏠 Running local tests..."
../notebook-ci-actions/scripts/test-local-ci.sh

# Step 2: Push to test branch and trigger GitHub Actions
echo "☁️  Triggering GitHub Actions..."
git checkout -b integration-test-$(date +%s)
git push origin HEAD

# Step 3: Monitor GitHub Actions
if command -v gh &> /dev/null; then
    echo "👀 Monitoring GitHub Actions..."
    gh run watch
    
    # Compare results
    if gh run view --json conclusion | jq -r '.conclusion' | grep -q "success"; then
        echo "✅ Integration test passed - local and GitHub results match"
    else
        echo "❌ Integration test failed - results differ"
        exit 1
    fi
else
    echo "💡 Install GitHub CLI (gh) for automatic monitoring"
fi
```

## 🏗️ Repository-Specific Configurations

The migration script automatically applies repository-specific configurations:

### `jdat_notebooks`
- **Package Manager**: uv (primary)
- **Special Features**: CRDS cache support, CasJobs integration
- **Workflows**: Full CI pipeline with security scanning
- **Secrets**: `CASJOBS_USERID`, `CASJOBS_PW`

### `mast_notebooks`  
- **Package Manager**: uv (primary)
- **Special Features**: MAST API access, archive queries
- **Workflows**: Standard CI pipeline with API testing
- **Secrets**: Repository-specific authentication tokens

### `hst_notebooks`
- **Package Manager**: micromamba (conda environment)
- **Special Features**: Auto-detected hstcal environment setup
- **Workflows**: Conda-based CI with STScI software stack
- **Environment**: Automatic `hstcal` installation via micromamba

### `hello_universe`
- **Package Manager**: uv (lightweight)
- **Special Features**: Educational focus, simplified validation
- **Workflows**: Reduced security scanning for educational content
- **Configuration**: Optimized for beginner-friendly experience

### `jwst-pipeline-notebooks`
- **Package Manager**: uv (primary)
- **Special Features**: jdaviz image replacement, JWST pipeline
- **Workflows**: Full CI with post-processing scripts
- **Post-processing**: Automatic jdaviz widget replacement in HTML

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Issue 1: Permission Denied
```bash
# Error: Permission denied when running scripts
# Solution: Make scripts executable
chmod +x scripts/validate-repository.sh
chmod +x scripts/migrate-repository.sh
```

#### Issue 2: Repository Not Found
```bash
# Error: Repository directory not found
# Solution: Ensure you're in the correct directory
pwd  # Should show path containing target repository
ls   # Should show repository directory
```

#### Issue 3: Git Branch Already Exists
```bash
# Error: Branch 'migrate-to-centralized-actions' already exists
# Solution: Delete existing branch or use different name
git branch -D migrate-to-centralized-actions
# Then re-run migration script
```

#### Issue 4: Workflow Validation Fails
```bash
# Error: YAML syntax errors in generated workflows
# Solution: Check generated workflows and fix syntax
yamllint .github/workflows/*.yml
```

#### Issue 5: Low Readiness Score
```bash
# Error: Readiness score < 80%
# Solution: Address issues mentioned in validation output
# Common fixes:
# - Strip notebook outputs: nbstripout notebooks/*.ipynb
# - Add missing dependency files: requirements.txt or pyproject.toml
# - Clean up git status: git add .; git commit -m "Pre-migration cleanup"
```

### Emergency Rollback

If migration causes issues:

```bash
# Option 1: Rollback using backup (if migration script was used)
rm .github/workflows/*.yml
cp .github/workflows-backup/*.yml .github/workflows/
git add .github/workflows/
git commit -m "Rollback: Restore original workflows"

# Option 2: Hard reset to previous state
git checkout main
git branch -D migrate-to-centralized-actions
```

## 🚀 Advanced Usage

### Custom Organization

```bash
# Use with different organization
./migrate-repository.sh my_notebooks my-organization
```

### Custom Workflow Templates

```bash
# Use custom workflow templates (modify script)
# Edit migrate-repository.sh line ~150:
# Change: cp ../notebook-ci-actions/examples/workflows/*.yml
# To: cp /path/to/custom/workflows/*.yml
```

### Debugging Mode

```bash
# Run with verbose debugging
bash -x ./migrate-repository.sh jdat_notebooks spacetelescope
```

### Testing Mode

```bash
# Test migration without making changes (modify script)
# Add DRY_RUN=true at top of migrate-repository.sh
# All git commands will be echoed but not executed
```

## 📋 Script Exit Codes

Both scripts use standard exit codes:

- **0**: Success - operation completed without errors
- **1**: General error - invalid arguments or runtime error  
- **2**: Validation failure - repository not ready for migration
- **3**: Git error - repository state issues
- **4**: File system error - missing files or permission issues

## 📊 Validation Criteria

The validation script scores repositories based on:

| Criteria | Weight | Points | Description |
|----------|--------|--------|-------------|
| **Repository Structure** | 20% | 20 | Required directories and files |
| **Notebook Quality** | 25% | 25 | Valid notebooks, stripped outputs |
| **Dependencies** | 20% | 20 | requirements.txt or pyproject.toml |
| **Git Status** | 15% | 15 | Clean working directory |
| **Repository-Specific** | 20% | 20 | Special requirements (CRDS, APIs) |

**Minimum score for migration**: 80%

## 📝 Logging and Reports

### Validation Report Location
```
validation-report-<repository>-<timestamp>.txt
```

### Migration Log Location  
```
migration-log-<repository>-<timestamp>.txt
```

### Migration Status File
```
migration-status.md  # Created in repository root
```

---

## 🤝 Contributing

To improve these scripts:

1. **Test thoroughly** with repository forks
2. **Add error handling** for new edge cases
3. **Update repository-specific configurations** as needed
4. **Maintain backwards compatibility** with existing migrations
5. **Document new features** in this README

## 📞 Support

- **Issues**: Create issues in the `notebook-ci-actions` repository
- **Documentation**: See `docs/` folder for detailed migration guides
- **Emergency**: Contact repository maintainers directly

---

**Last Updated**: June 11, 2025  
**Script Version**: 1.0.0  
**Compatible with**: notebook-ci-actions v1.x
