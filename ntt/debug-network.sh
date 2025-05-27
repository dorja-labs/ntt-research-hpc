#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Debugging Network Module Configuration ===${NC}"

# Check if gcluster is available
if ! command -v gcluster &> /dev/null; then
    echo -e "${RED}Error: gcluster command not found. Please run ./install.sh first.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}1. Checking gcluster version:${NC}"
gcluster --version

echo -e "\n${YELLOW}2. Expanding blueprint to see network module outputs:${NC}"
gcluster expand ntt/ntt-research.yaml

echo -e "\n${YELLOW}3. Checking network module source:${NC}"
ls -la modules/network/vpc/

echo -e "\n${YELLOW}4. Checking Filestore module source:${NC}"
ls -la modules/file-system/filestore/

echo -e "\n${YELLOW}5. Checking module metadata:${NC}"
echo "Network module metadata:"
cat modules/network/vpc/metadata.yaml
echo -e "\nFilestore module metadata:"
cat modules/file-system/filestore/metadata.yaml

echo -e "\n${BLUE}=== Debug Information Complete ===${NC}" 