#!/bin/bash
# Dependency Scanner
# Checks for cryptographic libraries and their versions

set -e

SCAN_PATH="${1:-.}"
TEMP_DIR=$(mktemp -d)
OUTPUT_FILE="${TEMP_DIR}/deps_output.json"

# Color codes
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "📦 Scanning dependencies in: $SCAN_PATH"
echo "----------------------------------------"

# Initialize JSON output
echo "{" > "$OUTPUT_FILE"
echo "  \"scan_timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$OUTPUT_FILE"
echo "  \"dependencies\": {" >> "$OUTPUT_FILE"

DEP_COUNT=0

# Function to add dependency to JSON
add_dependency() {
    local lang=$1
    local package=$2
    local version=$3
    local file=$4
    local risk=$5
    local recommendation=$6
    
    if [ $DEP_COUNT -gt 0 ]; then
        echo "," >> "$OUTPUT_FILE"
    fi
    
    cat >> "$OUTPUT_FILE" << EOF
    "dep_${DEP_COUNT}": {
      "language": "$lang",
      "package": "$package",
      "version": "$version",
      "file": "$file",
      "risk_level": "$risk",
      "recommendation": "$recommendation"
    }
EOF
    DEP_COUNT=$((DEP_COUNT + 1))
    
    echo -e "${BLUE}[$lang]${NC} $package ($version) - $risk - $file"
}

# Scan Python dependencies
echo -e "\n${GREEN}Checking Python dependencies...${NC}"
if find "$SCAN_PATH" -name "requirements.txt" -o -name "Pipfile" -o -name "setup.py" | grep -q .; then
    # Check requirements.txt
    find "$SCAN_PATH" -name "requirements.txt" | while read -r req_file; do
        if [ -f "$req_file" ]; then
            # Check for pycrypto (deprecated)
            if grep -qi "pycrypto" "$req_file"; then
                version=$(grep -i "pycrypto" "$req_file" | sed 's/.*==\s*//' | sed 's/[^0-9.]//g' || echo "unknown")
                add_dependency "Python" "pycrypto" "$version" "$req_file" "HIGH" "Replace with cryptography library"
            fi
            
            # Check for cryptography
            if grep -qi "cryptography" "$req_file"; then
                version=$(grep -i "cryptography" "$req_file" | sed 's/.*==\s*//' | sed 's/[^0-9.]//g' || echo "unknown")
                add_dependency "Python" "cryptography" "$version" "$req_file" "LOW" "Keep updated to latest version"
            fi
            
            # Check for pycryptodome
            if grep -qi "pycryptodome" "$req_file"; then
                version=$(grep -i "pycryptodome" "$req_file" | sed 's/.*==\s*//' | sed 's/[^0-9.]//g' || echo "unknown")
                add_dependency "Python" "pycryptodome" "$version" "$req_file" "LOW" "Modern crypto library"
            fi
            
            # Check for hashlib (built-in, but check usage)
            if grep -rq "import hashlib" "$SCAN_PATH" 2>/dev/null; then
                add_dependency "Python" "hashlib" "built-in" "$req_file" "INFO" "Built-in library - verify secure usage"
            fi
        fi
    done
fi

# Scan JavaScript/Node.js dependencies
echo -e "\n${GREEN}Checking JavaScript/Node.js dependencies...${NC}"
if find "$SCAN_PATH" -name "package.json" | grep -q .; then
    find "$SCAN_PATH" -name "package.json" | while read -r pkg_file; do
        if [ -f "$pkg_file" ]; then
            # Check for crypto-js
            if grep -q "crypto-js" "$pkg_file"; then
                version=$(grep "crypto-js" "$pkg_file" | sed 's/.*:\s*"\^*//' | sed 's/".*$//' || echo "unknown")
                add_dependency "JavaScript" "crypto-js" "$version" "$pkg_file" "MEDIUM" "Verify secure configuration"
            fi
            
            # Check for bcrypt
            if grep -q "bcrypt" "$pkg_file"; then
                version=$(grep "bcrypt" "$pkg_file" | sed 's/.*:\s*"\^*//' | sed 's/".*$//' || echo "unknown")
                add_dependency "JavaScript" "bcrypt" "$version" "$pkg_file" "LOW" "Good for password hashing"
            fi
            
            # Check for node-forge
            if grep -q "node-forge" "$pkg_file"; then
                version=$(grep "node-forge" "$pkg_file" | sed 's/.*:\s*"\^*//' | sed 's/".*$//' || echo "unknown")
                add_dependency "JavaScript" "node-forge" "$version" "$pkg_file" "MEDIUM" "Verify secure usage"
            fi
            
            # Check for jsonwebtoken
            if grep -q "jsonwebtoken" "$pkg_file"; then
                version=$(grep "jsonwebtoken" "$pkg_file" | sed 's/.*:\s*"\^*//' | sed 's/".*$//' || echo "unknown")
                add_dependency "JavaScript" "jsonwebtoken" "$version" "$pkg_file" "MEDIUM" "Ensure strong algorithms (RS256, ES256)"
            fi
        fi
    done
fi

# Scan Java dependencies
echo -e "\n${GREEN}Checking Java dependencies...${NC}"
if find "$SCAN_PATH" -name "pom.xml" -o -name "build.gradle" | grep -q .; then
    find "$SCAN_PATH" -name "pom.xml" | while read -r pom_file; do
        if [ -f "$pom_file" ]; then
            # Check for Bouncy Castle
            if grep -q "bouncycastle" "$pom_file"; then
                version=$(grep -A 1 "bouncycastle" "$pom_file" | grep "<version>" | sed 's/.*<version>//' | sed 's/<\/version>.*//' || echo "unknown")
                add_dependency "Java" "BouncyCastle" "$version" "$pom_file" "LOW" "Widely used crypto provider"
            fi
            
            # Check for Apache Commons Codec
            if grep -q "commons-codec" "$pom_file"; then
                version=$(grep -A 1 "commons-codec" "$pom_file" | grep "<version>" | sed 's/.*<version>//' | sed 's/<\/version>.*//' || echo "unknown")
                add_dependency "Java" "commons-codec" "$version" "$pom_file" "INFO" "Verify secure usage"
            fi
        fi
    done
fi

# Scan Go dependencies
echo -e "\n${GREEN}Checking Go dependencies...${NC}"
if find "$SCAN_PATH" -name "go.mod" | grep -q .; then
    find "$SCAN_PATH" -name "go.mod" | while read -r go_file; do
        if [ -f "$go_file" ]; then
            # Check for golang.org/x/crypto
            if grep -q "golang.org/x/crypto" "$go_file"; then
                version=$(grep "golang.org/x/crypto" "$go_file" | awk '{print $2}' || echo "unknown")
                add_dependency "Go" "golang.org/x/crypto" "$version" "$go_file" "LOW" "Official Go crypto library"
            fi
        fi
    done
fi

# Close JSON
echo "" >> "$OUTPUT_FILE"
echo "  }," >> "$OUTPUT_FILE"
echo "  \"total_dependencies\": $DEP_COUNT" >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

# Output the JSON
cat "$OUTPUT_FILE"

echo "----------------------------------------"
echo "✅ Dependency scan complete: $DEP_COUNT crypto dependencies found"

# Cleanup
rm -rf "$TEMP_DIR"

exit 0