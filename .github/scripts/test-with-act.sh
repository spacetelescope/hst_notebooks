#!/bin/bash
# Act-based Local Testing Script
# Uses Act to run GitHub Actions workflows locally

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
EVENT_TYPE=${1:-pull_request}
WORKFLOW_FILE=${2:-}
JOB_NAME=${3:-}
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}

# Check if Act is installed
if ! command -v act &> /dev/null; then
    log_error "Act is not installed. Please install it first:"
    echo "  # macOS"
    echo "  brew install act"
    echo ""
    echo "  # Linux"
    echo "  curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"
    echo ""
    echo "  # Windows"
    echo "  choco install act-cli"
    echo ""
    echo "For more information: https://github.com/nektos/act"
    exit 1
fi

echo "🎭 Act-based Local Testing"
echo "=========================="
echo "Event Type: $EVENT_TYPE"
if [ -n "$WORKFLOW_FILE" ]; then
    echo "Workflow File: $WORKFLOW_FILE"
fi
if [ -n "$JOB_NAME" ]; then
    echo "Job Name: $JOB_NAME"
fi
echo "Dry Run: $DRY_RUN"
echo "=========================="
echo

# Create .actrc if it doesn't exist
if [ ! -f ".actrc" ]; then
    log_info "Creating .actrc configuration file..."
    cat > .actrc << 'EOF'
--container-architecture linux/amd64
--platform ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest
--artifact-server-path /tmp/act-artifacts
--env GITHUB_ACTIONS=true
--env CI=true
--reuse
EOF
    log_success "Created .actrc configuration"
fi

# Create .env file template if it doesn't exist
if [ ! -f ".env" ]; then
    log_info "Creating .env template file..."
    cat > .env << 'EOF'
# GitHub Actions Environment Variables
# Copy this file and add your actual values
# DO NOT commit real secrets to version control

# GitHub Token (for API access)
GITHUB_TOKEN=ghp_your_token_here

# Repository-specific secrets
CASJOBS_USERID=your_userid
CASJOBS_PW=your_password

# Python configuration
PYTHON_VERSION=3.11

# Debugging
ACTIONS_STEP_DEBUG=false
ACTIONS_RUNNER_DEBUG=false
EOF
    log_success "Created .env template file"
    log_warning "Please update .env with your actual values"
fi

# Create event payload files directory
mkdir -p .github/events

# Create sample event payloads if they don't exist
if [ ! -f ".github/events/pr.json" ]; then
    log_info "Creating sample pull request event payload..."
    cat > .github/events/pr.json << 'EOF'
{
  "pull_request": {
    "number": 1,
    "base": {
      "ref": "main",
      "sha": "baseline-sha"
    },
    "head": {
      "ref": "feature-branch",
      "sha": "feature-sha"
    },
    "changed_files": [
      "notebooks/example.ipynb",
      "requirements.txt"
    ]
  },
  "repository": {
    "name": "test-repository",
    "full_name": "user/test-repository",
    "default_branch": "main"
  },
  "action": "opened"
}
EOF
    log_success "Created PR event payload"
fi

if [ ! -f ".github/events/push.json" ]; then
    log_info "Creating sample push event payload..."
    cat > .github/events/push.json << 'EOF'
{
  "ref": "refs/heads/main",
  "before": "before-sha",
  "after": "after-sha",
  "commits": [
    {
      "id": "commit-sha",
      "message": "Update notebooks",
      "modified": [
        "notebooks/example.ipynb"
      ]
    }
  ],
  "repository": {
    "name": "test-repository",
    "full_name": "user/test-repository",
    "default_branch": "main"
  }
}
EOF
    log_success "Created push event payload"
fi

if [ ! -f ".github/events/dispatch.json" ]; then
    log_info "Creating sample workflow dispatch event payload..."
    cat > .github/events/dispatch.json << 'EOF'
{
  "inputs": {
    "python-version": "3.11",
    "execution-mode": "validation-only",
    "single-notebook": "",
    "run-security-scan": "true",
    "build-documentation": "true"
  },
  "repository": {
    "name": "test-repository",
    "full_name": "user/test-repository",
    "default_branch": "main"
  }
}
EOF
    log_success "Created workflow dispatch event payload"
fi

# Build Act command
act_cmd="act"

# Add event type
act_cmd="$act_cmd $EVENT_TYPE"

# Add workflow file if specified
if [ -n "$WORKFLOW_FILE" ]; then
    act_cmd="$act_cmd --workflow $WORKFLOW_FILE"
fi

# Add job name if specified
if [ -n "$JOB_NAME" ]; then
    act_cmd="$act_cmd --job $JOB_NAME"
fi

# Add event payload based on event type
case "$EVENT_TYPE" in
    "pull_request")
        act_cmd="$act_cmd --eventpath .github/events/pr.json"
        ;;
    "push")
        act_cmd="$act_cmd --eventpath .github/events/push.json"
        ;;
    "workflow_dispatch")
        act_cmd="$act_cmd --eventpath .github/events/dispatch.json"
        ;;
esac

# Add flags
if [ "$DRY_RUN" = "true" ]; then
    act_cmd="$act_cmd --dryrun"
fi

if [ "$VERBOSE" = "true" ]; then
    act_cmd="$act_cmd --verbose"
fi

# Add environment file
act_cmd="$act_cmd --env-file .env"

# Pre-flight checks
log_info "Running pre-flight checks..."

# Check if .env file has been customized
if grep -q "your_token_here\|your_userid\|your_password" .env; then
    log_warning ".env file contains placeholder values"
    log_info "Consider updating with actual values for full testing"
fi

# List available workflows
log_info "Available workflows:"
act --list 2>/dev/null | grep -E "^ID:" -A 2 | while read -r line; do
    echo "  $line"
done
echo

# Show what would run
if [ "$DRY_RUN" = "false" ]; then
    log_info "The following command will be executed:"
    echo "  $act_cmd"
    echo
    
    # Ask for confirmation unless in CI
    if [ "${CI:-false}" != "true" ]; then
        read -p "Do you want to proceed? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled by user"
            exit 0
        fi
    fi
fi

# Execute Act command
log_info "Executing Act command..."
echo "Command: $act_cmd"
echo

if eval "$act_cmd"; then
    log_success "Act execution completed successfully!"
    
    # Show artifacts if any were created
    if [ -d "/tmp/act-artifacts" ] && [ "$(ls -A /tmp/act-artifacts 2>/dev/null)" ]; then
        log_info "Artifacts created in /tmp/act-artifacts:"
        ls -la /tmp/act-artifacts
    fi
    
else
    exit_code=$?
    log_error "Act execution failed with exit code $exit_code"
    
    # Debugging tips
    echo
    log_info "💡 Debugging Tips:"
    echo "  1. Run with --verbose flag for more details:"
    echo "     VERBOSE=true $0 $EVENT_TYPE"
    echo
    echo "  2. Run with --dryrun to validate configuration:"
    echo "     DRY_RUN=true $0 $EVENT_TYPE"
    echo
    echo "  3. Check Act logs for specific error messages"
    echo
    echo "  4. Verify Docker is running and accessible"
    echo
    echo "  5. Update .env file with valid tokens and secrets"
    
    exit $exit_code
fi

# Usage examples and next steps
echo
echo "========================================"
echo "💡 Usage Examples"
echo "========================================"
echo "# Test pull request workflow"
echo "$0 pull_request"
echo
echo "# Test specific workflow file"
echo "$0 push .github/workflows/notebook-ci-main.yml"
echo
echo "# Test specific job"
echo "$0 workflow_dispatch '' test-notebooks"
echo
echo "# Dry run mode"
echo "DRY_RUN=true $0 pull_request"
echo
echo "# Verbose mode"
echo "VERBOSE=true $0 push"
echo
echo "========================================"
echo "🔗 Useful Act Commands"
echo "========================================"
echo "# List all workflows and jobs"
echo "act --list"
echo
echo "# List available Docker images"
echo "act --list --platform ubuntu-latest=ubuntu:20.04"
echo
echo "# Run with custom secrets"
echo "act -s GITHUB_TOKEN=token -s CUSTOM_SECRET=value pull_request"
echo
echo "# Use specific Docker image"
echo "act --platform ubuntu-latest=ubuntu:20.04 push"
echo
echo "========================================"

log_success "Act-based local testing completed!"
