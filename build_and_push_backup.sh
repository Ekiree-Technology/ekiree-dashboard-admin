#!/bin/sh

# Set variables
IMAGE_NAME="ekiree-dashboard-admin"
GITHUB_USER="ekiree-technology"
TAG="latest"
GHCR_IMAGE="ghcr.io/$GITHUB_USER/$IMAGE_NAME:$TAG"

# Step 1: Build the Docker image
echo "🚀 Building the Docker image: $IMAGE_NAME..."
podman build -t "$IMAGE_NAME" .

if [ $? -ne 0 ]; then
    echo "❌ Docker build failed!"
    exit 1
fi

echo "✅ Build successful."

# Step 2: Tag the image for GitHub Container Registry (GHCR)
echo "🏷️  Tagging the image as $GHCR_IMAGE..."
podman tag "$IMAGE_NAME" "$GHCR_IMAGE"

# Step 3: Push the image to GitHub Container Registry over SSH
echo "📤 Pushing the image to GHCR over SSH..."
podman push "$GHCR_IMAGE"

if [ $? -ne 0 ]; then
    echo "❌ Docker push failed!"
    exit 1
fi

echo "✅ Successfully pushed $GHCR_IMAGE to GitHub Container Registry."

# Step 4: Output next steps
echo "🚀 Image is ready! Update your docker-compose.yml to use:"
echo "  image: $GHCR_IMAGE"
echo "Then deploy with:"
echo "  docker stack deploy -c docker-compose.yml wspStack"

