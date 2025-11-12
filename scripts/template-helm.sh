#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required commands exist
check_dependencies() {
    local missing_deps=()

    if ! command -v helmfile &> /dev/null; then
        missing_deps+=("helmfile")
    fi

    if ! command -v kustomize &> /dev/null; then
        missing_deps+=("kustomize")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
}

print_status "Starting helmfile rendering process..."

# Check dependencies
check_dependencies

# Find all helmfile.yaml files
print_status "Searching for helmfile.yaml files..."

# Enable globstar for recursive globbing
shopt -s globstar
helmfiles=(**/helmfile.yaml)

# Check if any files were found (bash sets array to literal glob if no matches)
if [ ${#helmfiles[@]} -eq 1 ] && [ "${helmfiles[0]}" = "**/helmfile.yaml" ]; then
    print_warning "No helmfile.yaml files found in the current directory tree"
    exit 0
fi

print_status "Found ${#helmfiles[@]} helmfile(s):"

for helmfile in "${helmfiles[@]}"; do
    helmfile_dir="$(dirname "$helmfile")"

    print_status "Processing helmfile in: $helmfile_dir"

    # Change to the helmfile directory
    original_dir="$(pwd)"
    cd "$helmfile_dir"

    kustomize edit remove resource helm/**/*.yaml 2>/dev/null;
    rm -rf helm
    helmfile template --output-dir-template "$(pwd)/helm"
    kustomize edit add resource helm/**/*.yaml

    # Return to original directory
    cd "$original_dir"

    print_status "Completed processing $helmfile_dir"
done

print_status "Processing complete!"
print_status "Formatting..."

# format templated files for consistency
nix fmt || echo "couldn't format as nix isn't installed"
