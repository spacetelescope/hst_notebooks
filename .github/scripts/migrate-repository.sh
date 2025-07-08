#!/bin/bash
# Migration automation script for notebook repositories
# Usage: ./migrate-repository.sh <repository_name> <org_name>

set -e

# Configuration
REPO_NAME="$1"
ORG_NAME="${2:-spacetelescope}"
ACTIONS_REPO="notebook-ci-actions"
BRANCH_NAME="migrate-to-centralized-actions"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validation
if [ -z "$REPO_NAME" ]; then
    log_error "Usage: $0 <repository_name> [org_name]"
    log_error "Example: $0 jdat_notebooks spacetelescope"
    exit 1
fi

log_info "Starting migration for $ORG_NAME/$REPO_NAME"

# Repository-specific configurations
declare -A REPO_CONFIGS
REPO_CONFIGS[jdat_notebooks]="python-version:3.11,execution-mode:full,special:crds"
REPO_CONFIGS[mast_notebooks]="python-version:3.11,execution-mode:full,special:mast-api"
REPO_CONFIGS[hst_notebooks]="python-version:3.11,execution-mode:full,special:hstcal"
REPO_CONFIGS[hello_universe]="python-version:3.11,execution-mode:validation-only,special:educational"
REPO_CONFIGS[jwst-pipeline-notebooks]="python-version:3.11,execution-mode:full,special:jwst-pipeline,post-script:scripts/jdaviz_image_replacement.sh"

# Check if we're in the right directory
if [ ! -d ".git" ]; then
    log_error "This script must be run from the root of a git repository"
    exit 1
fi

# Verify we're in the expected repository
current_repo=$(basename "$(git remote get-url origin)" .git)
if [ "$current_repo" != "$REPO_NAME" ]; then
    log_warning "Current directory appears to be '$current_repo', expected '$REPO_NAME'"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 1: Create migration branch
log_info "Step 1: Creating migration branch..."
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    log_warning "Branch $BRANCH_NAME already exists"
    git checkout "$BRANCH_NAME"
else
    git checkout -b "$BRANCH_NAME"
    log_success "Created branch $BRANCH_NAME"
fi

# Step 2: Backup existing workflows
log_info "Step 2: Backing up existing workflows..."
if [ -d ".github/workflows" ]; then
    mkdir -p .github/workflows-backup
    cp .github/workflows/*.yml .github/workflows-backup/ 2>/dev/null || log_warning "No .yml files to backup"
    cp .github/workflows/*.yaml .github/workflows-backup/ 2>/dev/null || log_warning "No .yaml files to backup"
    log_success "Workflows backed up to .github/workflows-backup/"
else
    log_warning "No .github/workflows directory found"
    mkdir -p .github/workflows
fi

# Step 3: Download example workflows
log_info "Step 3: Downloading example workflows..."
EXAMPLES_BASE_URL="https://raw.githubusercontent.com/$ORG_NAME/$ACTIONS_REPO/main/examples/workflows"

workflows=(
    "notebook-ci-pr.yml"
    "notebook-ci-main.yml"
    "notebook-ci-on-demand.yml"
    "docs-only.yml"
)

for workflow in "${workflows[@]}"; do
    log_info "Downloading $workflow..."
    if curl -sSL "$EXAMPLES_BASE_URL/$workflow" -o ".github/workflows/$workflow"; then
        log_success "Downloaded $workflow"
    else
        log_error "Failed to download $workflow"
        exit 1
    fi
done

# Step 4: Update workflow references
log_info "Step 4: Updating workflow references..."
for workflow_file in .github/workflows/*.yml; do
    if [ -f "$workflow_file" ]; then
        # Update organization and repository references
        sed -i "s/your-org/$ORG_NAME/g" "$workflow_file"
        sed -i "s/dev-actions/$ACTIONS_REPO/g" "$workflow_file"
        log_success "Updated references in $(basename "$workflow_file")"
    fi
done

# Step 5: Apply repository-specific configurations
log_info "Step 5: Applying repository-specific configurations..."
if [ -n "${REPO_CONFIGS[$REPO_NAME]}" ]; then
    config="${REPO_CONFIGS[$REPO_NAME]}"
    log_info "Applying configuration for $REPO_NAME: $config"
    
    # Parse configuration
    IFS=',' read -ra CONFIG_ITEMS <<< "$config"
    for item in "${CONFIG_ITEMS[@]}"; do
        IFS=':' read -ra KV <<< "$item"
        key="${KV[0]}"
        value="${KV[1]}"
        
        case "$key" in
            "python-version")
                # Update Python version in all workflows
                sed -i "s/python-version: \"3.11\"/python-version: \"$value\"/g" .github/workflows/*.yml
                log_success "Set Python version to $value"
                ;;
            "execution-mode")
                # Update execution mode in main CI workflow
                sed -i "s/execution-mode: \"full\"/execution-mode: \"$value\"/g" .github/workflows/notebook-ci-main.yml
                log_success "Set execution mode to $value"
                ;;
            "post-script")
                # Add post-processing script to HTML builder
                if [ -f ".github/workflows/notebook-ci-main.yml" ]; then
                    # Add post-run-script parameter
                    sed -i "/python-version:/a\\      post-run-script: \"$value\"" .github/workflows/notebook-ci-main.yml
                    log_success "Added post-processing script: $value"
                fi
                ;;
            "special")
                log_info "Special configuration noted: $value"
                ;;
        esac
    done
else
    log_warning "No specific configuration found for $REPO_NAME, using defaults"
fi

# Step 6: Create migration status file
log_info "Step 6: Creating migration status file..."
cat > migration-status.md << EOF
# Migration Status for $REPO_NAME

## Migration Details
- **Repository**: $ORG_NAME/$REPO_NAME
- **Migration Date**: $(date)
- **Actions Repository**: $ORG_NAME/$ACTIONS_REPO
- **Branch**: $BRANCH_NAME

## Pre-Migration Workflows
$(find .github/workflows-backup -name "*.yml" -o -name "*.yaml" 2>/dev/null | sed 's/^/- /' || echo "- No previous workflows found")

## New Workflows
$(find .github/workflows -name "*.yml" | sed 's/^/- /')

## Configuration Applied
$([ -n "${REPO_CONFIGS[$REPO_NAME]}" ] && echo "- ${REPO_CONFIGS[$REPO_NAME]}" || echo "- Default configuration")

## Testing Checklist
- [ ] Manual workflow dispatch test
- [ ] Pull request workflow test  
- [ ] Documentation build test
- [ ] Repository-specific features test

## Migration Notes
- Created by migration script on $(date)
- Review and customize workflows as needed
- Test thoroughly before merging to main

## Next Steps
1. Review generated workflows
2. Test with workflow_dispatch
3. Create test PR to verify triggers
4. Update repository secrets if needed
5. Merge after successful testing
EOF

log_success "Created migration-status.md"

# Step 7: Repository-specific adjustments
log_info "Step 7: Applying repository-specific adjustments..."
case "$REPO_NAME" in
    "hello_universe")
        # Simplify workflows for educational repository
        sed -i 's/security-scan: true/security-scan: false/g' .github/workflows/notebook-ci-*.yml
        log_success "Disabled security scanning for educational repository"
        ;;
    "jwst-pipeline-notebooks")
        # Ensure jdaviz post-processing is enabled
        if [ ! -f "scripts/jdaviz_image_replacement.sh" ]; then
            log_warning "jdaviz_image_replacement.sh script not found"
            log_info "Creating placeholder script..."
            mkdir -p scripts
            cat > scripts/jdaviz_image_replacement.sh << 'EOF'
#!/bin/bash
# Placeholder jdaviz image replacement script
# Replace jdaviz widgets with static images in HTML output

echo "Running jdaviz image replacement..."
find _build/html -name "*.html" -type f -exec echo "Processing {}" \;
echo "jdaviz image replacement completed"
EOF
            chmod +x scripts/jdaviz_image_replacement.sh
            log_success "Created placeholder jdaviz script"
        fi
        ;;
    "hst_notebooks")
        log_info "HST repository detected - workflows will automatically use hstcal environment"
        ;;
esac

# Step 8: Commit changes
log_info "Step 8: Committing migration changes..."
git add .
git commit -m "Migrate to centralized GitHub Actions workflows

- Backup existing workflows to .github/workflows-backup/
- Add centralized workflows from $ORG_NAME/$ACTIONS_REPO
- Configure repository-specific parameters
- Add migration tracking file

Repository: $REPO_NAME
Configuration: ${REPO_CONFIGS[$REPO_NAME]:-"default"}
Migration date: $(date)"

log_success "Migration changes committed"

# Step 9: Generate summary report
log_info "Step 9: Generating migration summary..."
echo
echo "=================================="
echo "Migration Summary for $REPO_NAME"
echo "=================================="
echo
echo "✅ Migration branch created: $BRANCH_NAME"
echo "✅ Workflows backed up to: .github/workflows-backup/"
echo "✅ New workflows installed:"
for workflow in "${workflows[@]}"; do
    echo "   - $workflow"
done
echo "✅ Configuration applied: ${REPO_CONFIGS[$REPO_NAME]:-"default"}"
echo "✅ Migration status file created: migration-status.md"
echo
echo "Next Steps:"
echo "1. Review the generated workflows in .github/workflows/"
echo "2. Test workflows with manual dispatch:"
echo "   - Go to Actions tab in GitHub"
echo "   - Run 'Notebook CI - On Demand' workflow"
echo "3. Create a test PR to verify automatic triggers"
echo "4. Check repository secrets are configured:"
echo "   - GITHUB_TOKEN (usually automatic)"
echo "   - CASJOBS_USERID (if needed)"
echo "   - CASJOBS_PW (if needed)"
echo "5. Merge branch after successful testing"
echo
echo "🔗 Useful links:"
echo "   - Workflows documentation: https://github.com/$ORG_NAME/$ACTIONS_REPO"
echo "   - Migration checklist: https://github.com/$ORG_NAME/$ACTIONS_REPO/blob/main/docs/repository-migration-checklist.md"
echo
log_success "Migration script completed!"

# Optional: Push branch
read -p "Push migration branch to origin? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push origin "$BRANCH_NAME"
    log_success "Migration branch pushed to origin"
    echo
    echo "🔗 Create pull request at:"
    echo "   https://github.com/$ORG_NAME/$REPO_NAME/compare/$BRANCH_NAME"
else
    log_info "Branch not pushed. Push manually when ready:"
    log_info "   git push origin $BRANCH_NAME"
fi
