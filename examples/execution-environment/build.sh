#!/bin/bash
#
# Build script for custom Execution Environment with kush_gupt.minimal_collection
#
# Usage:
#   ./build.sh [OPTIONS]
#
# Options:
#   -t, --tag TAG          Tag for the image (default: custom-ee-minimal:1.0.0)
#   -r, --runtime RUNTIME  Container runtime: podman or docker (default: podman)
#   -v, --verbose          Enable verbose output
#   -p, --push REGISTRY    Push to registry after build
#   -h, --help            Show this help message
#

set -e

# Default values
IMAGE_TAG="custom-ee-minimal:1.0.0"
CONTAINER_RUNTIME="podman"
VERBOSITY=1
PUSH_REGISTRY=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Build script for custom Execution Environment with kush_gupt.minimal_collection

Usage: $0 [OPTIONS]

Options:
    -t, --tag TAG          Tag for the image (default: custom-ee-minimal:1.0.0)
    -r, --runtime RUNTIME  Container runtime: podman or docker (default: podman)
    -v, --verbose          Enable verbose output
    -p, --push REGISTRY    Push to registry after build
    -h, --help            Show this help message

Examples:
    # Basic build
    $0

    # Build with custom tag
    $0 --tag my-org/custom-ee:2.0.0

    # Build with Docker
    $0 --runtime docker

    # Build and push to registry
    $0 --tag registry.example.com/my-org/custom-ee:1.0.0 --push registry.example.com

    # Verbose build
    $0 --verbose

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -r|--runtime)
            CONTAINER_RUNTIME="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSITY=3
            shift
            ;;
        -p|--push)
            PUSH_REGISTRY="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v ansible-builder &> /dev/null; then
    print_error "ansible-builder not found. Please install it:"
    echo "  pip install ansible-builder"
    exit 1
fi

if ! command -v "$CONTAINER_RUNTIME" &> /dev/null; then
    print_error "$CONTAINER_RUNTIME not found. Please install it."
    exit 1
fi

print_success "Prerequisites check passed"

# Check if we're in the right directory
if [[ ! -f "execution-environment.yml" ]]; then
    print_error "execution-environment.yml not found in current directory"
    print_info "Please run this script from the examples/execution-environment directory"
    exit 1
fi

# Check for Red Hat registry login if using RHEL base image
if grep -q "registry.redhat.io" execution-environment.yml; then
    print_info "Checking Red Hat registry authentication..."
    if ! $CONTAINER_RUNTIME login registry.redhat.io --get-login &> /dev/null; then
        print_warning "Not logged in to registry.redhat.io"
        print_info "Attempting to login..."
        $CONTAINER_RUNTIME login registry.redhat.io || {
            print_error "Failed to login to registry.redhat.io"
            print_info "Please login manually: $CONTAINER_RUNTIME login registry.redhat.io"
            exit 1
        }
    fi
    print_success "Red Hat registry authentication OK"
fi

# Build the execution environment
print_info "Building execution environment: $IMAGE_TAG"
print_info "Container runtime: $CONTAINER_RUNTIME"
print_info "Verbosity: $VERBOSITY"

ansible-builder build \
    --tag "$IMAGE_TAG" \
    --container-runtime "$CONTAINER_RUNTIME" \
    --verbosity "$VERBOSITY"

# Verify the build
print_info "Verifying the build..."
if $CONTAINER_RUNTIME images "$IMAGE_TAG" &> /dev/null; then
    print_success "Image built successfully: $IMAGE_TAG"
else
    print_error "Image build verification failed"
    exit 1
fi

# Check if collection is in the image
print_info "Checking for kush_gupt.minimal_collection in the image..."
if $CONTAINER_RUNTIME run --rm "$IMAGE_TAG" ansible-galaxy collection list | grep -q "kush_gupt.minimal_collection"; then
    print_success "Collection found in image"
else
    print_warning "Collection not found in image"
fi

# Display image info
print_info "Image information:"
$CONTAINER_RUNTIME images "$IMAGE_TAG" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Push if requested
if [[ -n "$PUSH_REGISTRY" ]]; then
    print_info "Pushing image to registry: $PUSH_REGISTRY"
    
    # Check if we need to tag for the registry
    if [[ "$IMAGE_TAG" != "$PUSH_REGISTRY"* ]]; then
        REGISTRY_TAG="$PUSH_REGISTRY/$(basename $IMAGE_TAG)"
        print_info "Tagging image: $REGISTRY_TAG"
        $CONTAINER_RUNTIME tag "$IMAGE_TAG" "$REGISTRY_TAG"
        IMAGE_TAG="$REGISTRY_TAG"
    fi
    
    # Check registry login
    REGISTRY_HOST=$(echo "$PUSH_REGISTRY" | cut -d'/' -f1)
    if ! $CONTAINER_RUNTIME login "$REGISTRY_HOST" --get-login &> /dev/null; then
        print_info "Logging in to $REGISTRY_HOST..."
        $CONTAINER_RUNTIME login "$REGISTRY_HOST" || {
            print_error "Failed to login to $REGISTRY_HOST"
            exit 1
        }
    fi
    
    # Push
    print_info "Pushing $IMAGE_TAG..."
    $CONTAINER_RUNTIME push "$IMAGE_TAG"
    print_success "Image pushed successfully"
fi

# Summary
echo ""
print_success "Build complete!"
echo ""
echo "Next steps:"
echo "  1. Test the image locally:"
echo "     ansible-navigator run test-playbook.yml --execution-environment-image $IMAGE_TAG --mode stdout"
echo ""
echo "  2. Verify the collection:"
echo "     $CONTAINER_RUNTIME run --rm $IMAGE_TAG ansible-galaxy collection list"
echo ""
echo "  3. Push to your registry (if not already done):"
echo "     $CONTAINER_RUNTIME tag $IMAGE_TAG your-registry.com/your-org/custom-ee:1.0.0"
echo "     $CONTAINER_RUNTIME push your-registry.com/your-org/custom-ee:1.0.0"
echo ""

