#!/bin/bash
# Simpler test script - runs the actual build.sh
set -e

cd "$(dirname "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Simulate OSS-Fuzz environment
export CXX=${CXX:-clang++}
export CXXFLAGS="-g -O1 -fsanitize=address,fuzzer,undefined"
export LIB_FUZZING_ENGINE=""
export WORK=$(pwd)/.test_build
export OUT=$(pwd)/.test_build/out
export SRC=$(pwd)

echo "========================================="
echo "OSS-Fuzz Build Simulation"
echo "========================================="
echo "Using: fuzz/build.sh"
echo "Work: $WORK"
echo "Out:  $OUT"
echo ""

# Clean
rm -rf $WORK
mkdir -p $WORK $OUT

# Run build
echo "Running build.sh..."
echo ""
if bash fuzz/build.sh 2>&1 | tee $WORK/build.log; then
    BUILD_SUCCESS=true
else
    BUILD_SUCCESS=false
fi

echo ""
echo "========================================="
echo "Build Summary"
echo "========================================="

# Check which fuzzers were built
BUILT=()
FAILED=()

for fuzzer in fuzz_lexer fuzz_expr_parser fuzz_hir_deserialise fuzz_target_spec; do
    if [ -f "$OUT/$fuzzer" ]; then
        BUILT+=("$fuzzer")
    else
        FAILED+=("$fuzzer")
    fi
done

# Show results
if [ ${#BUILT[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Built successfully: ${#BUILT[@]}${NC}"
    for f in "${BUILT[@]}"; do
        echo "  ✓ $f"
        ls -lh "$OUT/$f"
    done
    echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed to build: ${#FAILED[@]}${NC}"
    for f in "${FAILED[@]}"; do
        echo "  ✗ $f"
    done
    echo ""

    echo "Common errors:"
    grep -h "undefined reference" $WORK/build.log 2>/dev/null | head -10 || echo "  (no linker errors found)"
    echo ""

    echo "Full build log: $WORK/build.log"
    exit 1
else
    echo -e "${GREEN}All fuzzers built successfully!${NC}"
    echo ""
    echo "Ready for OSS-Fuzz upload!"
    echo "  1. ./copy_to_ossfuzz.sh"
    echo "  2. cd ~/oss-fuzz"
    echo "  3. python3 infra/helper.py build_image mrustc"
    echo "  4. python3 infra/helper.py build_fuzzers --sanitizer address mrustc"
    exit 0
fi
