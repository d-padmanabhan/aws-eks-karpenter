#!/bin/bash
set -e

echo "=========================================="
echo "Building and Pushing Docker Images"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Get registry URL
echo -e "\n${YELLOW}Enter your Docker registry URL (e.g., docker.io/username or AWS ECR URL):${NC}"
read -r REGISTRY

if [ -z "$REGISTRY" ]; then
    echo -e "${RED}Error: Registry URL is required${NC}"
    exit 1
fi

# Get image tag
echo -e "\n${YELLOW}Enter image tag (default: latest):${NC}"
read -r TAG
TAG=${TAG:-latest}

# Build backend
echo -e "\n${YELLOW}Building backend image...${NC}"
cd backend
docker build -t "${REGISTRY}/todo-backend:${TAG}" .
echo -e "${GREEN}✓ Backend image built${NC}"

# Build frontend
echo -e "\n${YELLOW}Building frontend image...${NC}"
cd ../frontend
docker build -t "${REGISTRY}/todo-frontend:${TAG}" .
echo -e "${GREEN}✓ Frontend image built${NC}"

cd ..

# Push images
echo -e "\n${YELLOW}Do you want to push images to registry? (yes/no)${NC}"
read -r response

if [ "$response" = "yes" ]; then
    echo -e "\n${YELLOW}Pushing backend image...${NC}"
    docker push "${REGISTRY}/todo-backend:${TAG}"
    echo -e "${GREEN}✓ Backend image pushed${NC}"
    
    echo -e "\n${YELLOW}Pushing frontend image...${NC}"
    docker push "${REGISTRY}/todo-frontend:${TAG}"
    echo -e "${GREEN}✓ Frontend image pushed${NC}"
    
    echo -e "\n${GREEN}=========================================="
    echo -e "Images built and pushed successfully!"
    echo -e "==========================================${NC}"
    echo -e "\nImage URLs:"
    echo -e "Backend:  ${REGISTRY}/todo-backend:${TAG}"
    echo -e "Frontend: ${REGISTRY}/todo-frontend:${TAG}"
    echo -e "\nNext step: Update k8s deployment files with these image URLs"
else
    echo -e "\n${YELLOW}Images built but not pushed${NC}"
fi
