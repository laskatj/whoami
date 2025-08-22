#!/bin/bash

# Build script with automatic versioning for whoami

set -e

# Function to get the latest version from local registry
get_latest_version() {
    echo "🔍 Checking local registry for latest version..."
    
    # Query local registry for existing tags
    if command -v curl &> /dev/null; then
        # Try to get tags from local registry
        REGISTRY_TAGS=$(curl -s http://localhost:5003/v2/whoami/tags/list 2>/dev/null || echo "")
        
        if [ -n "$REGISTRY_TAGS" ]; then
            # Extract version tags and find the highest (without jq dependency)
            VERSIONS=$(echo "$REGISTRY_TAGS" | grep -o '"tags":\[[^]]*\]' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | sort -V | tail -1)
            
            if [ -n "$VERSIONS" ]; then
                echo "📋 Found latest version in registry: $VERSIONS"
                LATEST_VERSION=$VERSIONS
            else
                echo "📋 No version tags found in registry, starting with 1.0.0"
                LATEST_VERSION="0.0.0"
            fi
        else
            echo "📋 Registry not accessible, starting with 1.0.0"
            LATEST_VERSION="0.0.0"
        fi
    else
        echo "📋 curl not available, starting with 1.0.0"
        LATEST_VERSION="0.0.0"
    fi
}

# Function to increment patch version
increment_patch_version() {
    if [ -n "$1" ]; then
        VERSION=$1
    else
        # Auto-increment patch version
        if [ "$LATEST_VERSION" = "0.0.0" ]; then
            VERSION="1.0.0"
        else
            # Split version into parts
            IFS='.' read -r MAJOR MINOR PATCH <<< "$LATEST_VERSION"
            NEW_PATCH=$((PATCH + 1))
            VERSION="$MAJOR.$MINOR.$NEW_PATCH"
        fi
    fi
    
    echo "🚀 Next version will be: $VERSION"
}

# Function to get build date
get_build_date() {
    BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
}

# Function to display build info
display_build_info() {
    echo "🪏  Building whoami with version: $VERSION"
    echo "    Previous version: $LATEST_VERSION"
    echo "    Build Date: $BUILD_DATE"
    echo ""
}

# Function to build Go binary
build_binary() {
    echo "🔨 Building Go binary..."
    
    # Run make build to compile the Go binary
    make build
    
    if [ -f "whoami" ]; then
        echo "✅ Go binary built successfully: whoami"
    else
        echo "❌ Failed to build Go binary"
        exit 1
    fi
}

# Function to build Docker image
build_docker() {
    echo "🐳 Building Docker image..."
    
    docker build \
        --build-arg VERSION=$VERSION \
        --build-arg BUILD_DATE=$BUILD_DATE \
        -t whoami:$VERSION \
        -t whoami:latest \
        .
    
    echo "✅ Docker build complete"
}

# Function to save image
save_image() {
    echo "💾 Saving Docker image..."
    mkdir -p IMAGES
    docker save whoami:$VERSION | gzip > IMAGES/whoami-$VERSION.tar.gz
    echo "✅ Image saved as IMAGES/whoami-$VERSION.tar.gz"
}

# Function to push to local registry
push_to_registry() {
    echo "📤 Pushing to local registry..."
    
    # Tag for local registry
    docker tag whoami:$VERSION localhost:5003/whoami:$VERSION
    docker tag whoami:$VERSION localhost:5003/whoami:latest
    
    # Push to local registry
    docker push localhost:5003/whoami:$VERSION
    docker push localhost:5003/whoami:latest
    
    echo "✅ Pushed to local registry: localhost:5003/whoami:$VERSION"
}

# Main execution
main() {
    echo "🔧 whoami Auto-Version Build Script"
    echo "===================================="
    
    # Get version information
    get_latest_version
    increment_patch_version "$1"
    get_build_date
    
    # Display build info
    display_build_info
    
    # Build Go binary
    build_binary
    
    # Build Docker image
    build_docker
    
    # Save image
    save_image
     
    # Push to registry (if registry is available)
    if curl -s http://localhost:5003/v2/ >/dev/null 2>&1; then
        push_to_registry
    else
        echo "⚠️  Local registry not available, skipping push"
        echo "   To push manually:"
        echo "   docker tag whoami:$VERSION localhost:5003/whoami:$VERSION"
        echo "   docker push localhost:5003/whoami:$VERSION"
    fi
    
    echo ""
    echo "🎉 Build completed successfully!"
    echo "   Image: whoami:$VERSION"
    echo "   Image file: IMAGES/whoami-$VERSION.tar.gz"
    echo ""
    echo "To run the container:"
    echo "   docker run -p 80:80 whoami:$VERSION"
    echo ""
    echo "Version $VERSION will be available in the container"
}

# Run main function
main "$@"
