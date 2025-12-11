#!/bin/bash
set -e

echo "=========================================="
echo "Starting Local Development Environment"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 is not installed${NC}"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: node is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"

# Setup backend
echo -e "\n${YELLOW}Setting up backend...${NC}"
cd backend

if [ ! -d "venv" ]; then
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv venv
fi

echo -e "${YELLOW}Activating virtual environment...${NC}"
source venv/bin/activate

echo -e "${YELLOW}Installing dependencies...${NC}"
pip install -q -r requirements.txt

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cp .env.example .env
    echo -e "${RED}Please configure .env file with your AWS credentials${NC}"
fi

# Run migrations
echo -e "${YELLOW}Running migrations...${NC}"
python manage.py migrate

echo -e "${GREEN}✓ Backend setup complete${NC}"

# Start backend in background
echo -e "\n${YELLOW}Starting backend server...${NC}"
python manage.py runserver 8000 > /tmp/backend.log 2>&1 &
BACKEND_PID=$!
echo -e "${GREEN}✓ Backend running on http://localhost:8000 (PID: $BACKEND_PID)${NC}"

cd ..

# Setup frontend
echo -e "\n${YELLOW}Setting up frontend...${NC}"
cd frontend

if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install
fi

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    echo "VITE_API_URL=http://localhost:8000/api" > .env
fi

echo -e "${GREEN}✓ Frontend setup complete${NC}"

# Start frontend
echo -e "\n${YELLOW}Starting frontend server...${NC}"
npm run dev > /tmp/frontend.log 2>&1 &
FRONTEND_PID=$!
echo -e "${GREEN}✓ Frontend running on http://localhost:3000 (PID: $FRONTEND_PID)${NC}"

cd ..

echo -e "\n${GREEN}=========================================="
echo -e "Development environment is ready!"
echo -e "==========================================${NC}"
echo -e "\nBackend:  http://localhost:8000"
echo -e "Frontend: http://localhost:3000"
echo -e "API Docs: http://localhost:8000/api/"
echo -e "\nBackend logs:  tail -f /tmp/backend.log"
echo -e "Frontend logs: tail -f /tmp/frontend.log"
echo -e "\n${YELLOW}To stop servers:${NC}"
echo -e "kill $BACKEND_PID $FRONTEND_PID"
echo -e "\nOr run: pkill -f 'manage.py runserver' && pkill -f 'vite'"

# Save PIDs to file
echo "$BACKEND_PID" > /tmp/todo-backend.pid
echo "$FRONTEND_PID" > /tmp/todo-frontend.pid
