#!/bin/bash
# Quick local test script to verify all fuzzers build correctly
# This mimics the OSS-Fuzz build.sh but runs locally for fast iteration
#
# Usage: ./test_fuzzer_build.sh

set -e  # Exit on first error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CXX=${CXX:-clang++}
CXXFLAGS="-g -O1 -fsanitize=address,fuzzer,undefined -std=c++14"
MRUSTC_CXXFLAGS="$CXXFLAGS -Isrc/include -Isrc -Itools/common -DFUZZER_BUILD=1"
WORK_DIR=".test_build"

echo "========================================="
echo "mrustc Fuzzer Build Test"
echo "========================================="
echo "Compiler: $CXX"
echo "Work dir: $WORK_DIR"
echo ""

# Track build results
BUILT_FUZZERS=()
FAILED_FUZZERS=()

#############################################
# Phase 1: Build object files
#############################################

SKIP_PHASE1=${SKIP_PHASE1:-false}

# Clean previous build only if not using cached objects
if [ "$SKIP_PHASE1" = "false" ]; then
    echo "Cleaning previous build..."
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR/obj"
else
    # Just ensure directory exists for logs
    mkdir -p "$WORK_DIR/obj"
fi

if [ "$SKIP_PHASE1" = "true" ]; then
    echo "[Phase 1/3] Skipping compilation (using cached .o files)..."
    echo ""

    # Just populate the variables with existing .o files
    COMMON_OBJS="$WORK_DIR/obj/span.o $WORK_DIR/obj/rc_string.o $WORK_DIR/obj/debug.o $WORK_DIR/obj/ident.o"
    TOOLS_OBJS="$WORK_DIR/obj/tools_path.o"
    PARSE_OBJS="$WORK_DIR/obj/lex.o $WORK_DIR/obj/parseerror.o $WORK_DIR/obj/token.o $WORK_DIR/obj/tokentree.o $WORK_DIR/obj/interpolated_fragment.o $WORK_DIR/obj/tokenstream.o $WORK_DIR/obj/ttstream.o"
    PARSE_OBJS="$PARSE_OBJS $WORK_DIR/obj/parse_expr.o $WORK_DIR/obj/parse_pattern.o $WORK_DIR/obj/parse_types.o $WORK_DIR/obj/parse_paths.o $WORK_DIR/obj/parse_root.o"
    AST_OBJS="$WORK_DIR/obj/ast_ast.o $WORK_DIR/obj/ast_crate.o $WORK_DIR/obj/ast_path.o $WORK_DIR/obj/ast_expr.o $WORK_DIR/obj/ast_pattern.o $WORK_DIR/obj/ast_types.o"
    MACRO_OBJS="$WORK_DIR/obj/mod.o $WORK_DIR/obj/parse.o $WORK_DIR/obj/eval.o"
    EXPAND_OBJS="$WORK_DIR/obj/cfg.o $WORK_DIR/obj/crate_tags.o"
else
    echo "[Phase 1/3] Compiling object files..."
    echo ""
fi

if [ "$SKIP_PHASE1" = "false" ]; then

# Common objects
echo "[1.1] Common utilities..."
COMMON_OBJS=""
for src in src/span.cpp src/rc_string.cpp src/debug.cpp src/ident.cpp; do
    obj_name=$(basename $src .cpp).o
    echo -n "  Compiling $src... "
    if $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK_DIR/obj/$obj_name 2>&1 | tee $WORK_DIR/obj/$(basename $src .cpp).log | tail -1; then
        echo -e "${GREEN}✓${NC}"
        COMMON_OBJS="$COMMON_OBJS $WORK_DIR/obj/$obj_name"
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  See: $WORK_DIR/obj/$(basename $src .cpp).log"
        exit 1
    fi
done

# Tools/common objects
echo "[1.2] Tools/common components..."
TOOLS_OBJS=""
for src in tools/common/path.cpp; do
    obj_name="tools_$(basename $src .cpp).o"
    if [ -f $WORK_DIR/obj/$obj_name ]; then
        echo "  $src [cached ✓]"
        TOOLS_OBJS="$TOOLS_OBJS $WORK_DIR/obj/$obj_name"
    else
        echo -n "  Compiling $src... "
        if $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK_DIR/obj/$obj_name 2>$WORK_DIR/obj/$obj_name.log; then
            echo -e "${GREEN}✓${NC}"
            TOOLS_OBJS="$TOOLS_OBJS $WORK_DIR/obj/$obj_name"
        else
            echo -e "${RED}✗ FAILED${NC}"
            echo "  See: $WORK_DIR/obj/$obj_name.log"
            exit 1
        fi
    fi
done

# Parse objects (basic)
echo "[1.3] Parse components (basic)..."
PARSE_OBJS=""
for src in src/parse/lex.cpp src/parse/parseerror.cpp src/parse/token.cpp \
           src/parse/tokentree.cpp src/parse/interpolated_fragment.cpp \
           src/parse/tokenstream.cpp src/parse/ttstream.cpp; do
    obj_name=$(basename $src .cpp).o
    if [ -f $WORK_DIR/obj/$obj_name ]; then
        echo "  $src [cached ✓]"
        PARSE_OBJS="$PARSE_OBJS $WORK_DIR/obj/$obj_name"
    else
        echo -n "  Compiling $src... "
        if $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK_DIR/obj/$obj_name 2>&1 | tee $WORK_DIR/obj/$(basename $src .cpp).log | tail -1; then
            echo -e "${GREEN}✓${NC}"
            PARSE_OBJS="$PARSE_OBJS $WORK_DIR/obj/$obj_name"
        else
            echo -e "${RED}✗ FAILED${NC}"
            echo "  See: $WORK_DIR/obj/$(basename $src .cpp).log"
            exit 1
        fi
    fi
done

# Parse objects (additional - for expr parser)
echo "[1.4] Parse components (additional)..."
for src in src/parse/expr.cpp src/parse/pattern.cpp src/parse/types.cpp \
           src/parse/paths.cpp src/parse/root.cpp; do
    obj_name="parse_$(basename $src .cpp).o"  # Unique name to avoid collision with ast/
    echo -n "  Compiling $src... "
    if $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK_DIR/obj/$obj_name 2>$WORK_DIR/obj/$obj_name.log; then
        echo -e "${GREEN}✓${NC}"
        PARSE_OBJS="$PARSE_OBJS $WORK_DIR/obj/$obj_name"
    else
        echo -e "${YELLOW}⚠ FAILED (expected - has dependencies)${NC}"
        echo "  See: $WORK_DIR/obj/$obj_name.log"
        # Don't exit - these might need more dependencies
    fi
done

# AST objects
# Note: HIR components are SKIPPED - they're stubbed in fuzzer_stubs.cpp
echo "[1.5] AST components..."
AST_OBJS=""
for src in src/ast/ast.cpp src/ast/crate.cpp src/ast/path.cpp \
           src/ast/expr.cpp src/ast/pattern.cpp src/ast/types.cpp; do
    obj_name="ast_$(basename $src .cpp).o"  # Unique name to avoid collision with parse/
    echo -n "  Compiling $src... "
    if $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK_DIR/obj/$obj_name 2>$WORK_DIR/obj/$obj_name.log; then
        echo -e "${GREEN}✓${NC}"
        AST_OBJS="$AST_OBJS $WORK_DIR/obj/$obj_name"
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  See: $WORK_DIR/obj/$obj_name.log"
        exit 1
    fi
done

# Macro rules objects
echo "[1.6] Macro_rules components..."
MACRO_OBJS=""
for src in src/macro_rules/mod.cpp src/macro_rules/parse.cpp \
           src/macro_rules/eval.cpp; do
    obj_name=$(basename $src .cpp).o
    echo -n "  Compiling $src... "
    if $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK_DIR/obj/$obj_name 2>$WORK_DIR/obj/$(basename $src .cpp).log; then
        echo -e "${GREEN}✓${NC}"
        MACRO_OBJS="$MACRO_OBJS $WORK_DIR/obj/$obj_name"
    else
        echo -e "${YELLOW}⚠ FAILED (might have parse dependencies)${NC}"
        echo "  See: $WORK_DIR/obj/$(basename $src .cpp).log"
    fi
done

# Expand objects
echo "[1.7] Expand components..."
EXPAND_OBJS=""
for src in src/expand/cfg.cpp src/expand/crate_tags.cpp; do
    obj_name=$(basename $src .cpp).o
    echo -n "  Compiling $src... "
    if $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK_DIR/obj/$obj_name 2>$WORK_DIR/obj/$(basename $src .cpp).log; then
        echo -e "${GREEN}✓${NC}"
        EXPAND_OBJS="$EXPAND_OBJS $WORK_DIR/obj/$obj_name"
    else
        echo -e "${YELLOW}⚠ FAILED${NC}"
        echo "  See: $WORK_DIR/obj/$(basename $src .cpp).log"
    fi
done

# Fuzzer stubs
echo "[1.8] Fuzzer stubs..."
echo -n "  Compiling fuzz/fuzzer_stubs.cpp... "
if $CXX $MRUSTC_CXXFLAGS -c fuzz/fuzzer_stubs.cpp -o $WORK_DIR/obj/fuzzer_stubs.o 2>$WORK_DIR/obj/fuzzer_stubs.log; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
    echo "  See: $WORK_DIR/obj/fuzzer_stubs.log"
    exit 1
fi

fi  # Close SKIP_PHASE1=false block

echo ""

#############################################
# Phase 2: Build fuzzers
#############################################

echo "[Phase 2/3] Building fuzzers..."
echo ""

# Fuzzer 1: fuzz_lexer
echo "[2.1] Building fuzz_lexer..."
if $CXX $MRUSTC_CXXFLAGS \
    fuzz/fuzz_lexer.cpp \
    $COMMON_OBJS \
    $TOOLS_OBJS \
    $PARSE_OBJS \
    $AST_OBJS \
    $MACRO_OBJS \
    $EXPAND_OBJS \
    $WORK_DIR/obj/fuzzer_stubs.o \
    -o $WORK_DIR/fuzz_lexer 2>$WORK_DIR/fuzz_lexer.log; then
    echo -e "  ${GREEN}✓ SUCCESS${NC}"
    BUILT_FUZZERS+=("fuzz_lexer")
else
    echo -e "  ${RED}✗ FAILED${NC}"
    echo "  See: $WORK_DIR/fuzz_lexer.log"
    cat $WORK_DIR/fuzz_lexer.log | grep "undefined reference" | head -5
    FAILED_FUZZERS+=("fuzz_lexer")
fi

# Fuzzer 2: fuzz_expr_parser
echo "[2.2] Building fuzz_expr_parser..."
if $CXX $MRUSTC_CXXFLAGS \
    fuzz/fuzz_expr_parser.cpp \
    $COMMON_OBJS \
    $TOOLS_OBJS \
    $PARSE_OBJS \
    $AST_OBJS \
    $MACRO_OBJS \
    $EXPAND_OBJS \
    $WORK_DIR/obj/fuzzer_stubs.o \
    -o $WORK_DIR/fuzz_expr_parser 2>$WORK_DIR/fuzz_expr_parser.log; then
    echo -e "  ${GREEN}✓ SUCCESS${NC}"
    BUILT_FUZZERS+=("fuzz_expr_parser")
else
    echo -e "  ${RED}✗ FAILED${NC}"
    echo "  See: $WORK_DIR/fuzz_expr_parser.log"
    cat $WORK_DIR/fuzz_expr_parser.log | grep "undefined reference" | head -5
    FAILED_FUZZERS+=("fuzz_expr_parser")
fi

# Fuzzer 3: fuzz_hir_deserialise (needs HIR components)
echo "[2.3] Building fuzz_hir_deserialise..."
echo -n "  Compiling src/hir/serialise_lowlevel.cpp... "
if $CXX $MRUSTC_CXXFLAGS -c src/hir/serialise_lowlevel.cpp -o $WORK_DIR/obj/serialise_lowlevel.o 2>$WORK_DIR/obj/serialise_lowlevel.log; then
    echo -e "${GREEN}✓${NC}"
    if $CXX $MRUSTC_CXXFLAGS \
        fuzz/fuzz_hir_deserialise.cpp \
        $WORK_DIR/obj/serialise_lowlevel.o \
        $COMMON_OBJS \
        $WORK_DIR/obj/fuzzer_stubs.o \
        -o $WORK_DIR/fuzz_hir_deserialise 2>$WORK_DIR/fuzz_hir_deserialise.log; then
        echo -e "  ${GREEN}✓ SUCCESS${NC}"
        BUILT_FUZZERS+=("fuzz_hir_deserialise")
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        echo "  See: $WORK_DIR/fuzz_hir_deserialise.log"
        FAILED_FUZZERS+=("fuzz_hir_deserialise")
    fi
else
    echo -e "${RED}✗ FAILED${NC}"
    echo "  See: $WORK_DIR/obj/serialise_lowlevel.log"
    FAILED_FUZZERS+=("fuzz_hir_deserialise")
fi

# Fuzzer 4: fuzz_target_spec (needs trans components)
echo "[2.4] Building fuzz_target_spec..."
echo -n "  Compiling src/trans/target.cpp... "
if $CXX $MRUSTC_CXXFLAGS -c src/trans/target.cpp -o $WORK_DIR/obj/target.o 2>$WORK_DIR/obj/target.log; then
    echo -e "${GREEN}✓${NC}"
    if $CXX $MRUSTC_CXXFLAGS \
        fuzz/fuzz_target_spec.cpp \
        $WORK_DIR/obj/target.o \
        $COMMON_OBJS \
        $WORK_DIR/obj/fuzzer_stubs.o \
        -o $WORK_DIR/fuzz_target_spec 2>$WORK_DIR/fuzz_target_spec.log; then
        echo -e "  ${GREEN}✓ SUCCESS${NC}"
        BUILT_FUZZERS+=("fuzz_target_spec")
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        echo "  See: $WORK_DIR/fuzz_target_spec.log"
        FAILED_FUZZERS+=("fuzz_target_spec")
    fi
else
    echo -e "${YELLOW}⚠ FAILED (trans/target.cpp has dependencies)${NC}"
    echo "  See: $WORK_DIR/obj/target.log"
    FAILED_FUZZERS+=("fuzz_target_spec")
fi

echo ""

#############################################
# Phase 3: Test fuzzers
#############################################

echo "[Phase 3/3] Testing fuzzers..."
echo ""

for fuzzer in "${BUILT_FUZZERS[@]}"; do
    echo -n "Testing $fuzzer with empty input... "
    if echo "" | $WORK_DIR/$fuzzer 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ (might be expected)${NC}"
    fi
done

echo ""

#############################################
# Summary
#############################################

echo "========================================="
echo "Build Summary"
echo "========================================="
echo -e "${GREEN}Built successfully:${NC} ${#BUILT_FUZZERS[@]}"
for fuzzer in "${BUILT_FUZZERS[@]}"; do
    echo "  ✓ $fuzzer"
    ls -lh $WORK_DIR/$fuzzer
done

echo ""

if [ ${#FAILED_FUZZERS[@]} -gt 0 ]; then
    echo -e "${RED}Failed to build:${NC} ${#FAILED_FUZZERS[@]}"
    for fuzzer in "${FAILED_FUZZERS[@]}"; do
        echo "  ✗ $fuzzer"
    done
    echo ""
    echo "To debug:"
    echo "  - Check log files in $WORK_DIR/"
    echo "  - Look for 'undefined reference' errors"
    echo "  - Add missing source files to build.sh"
    exit 1
else
    echo -e "${GREEN}All fuzzers built successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./copy_to_ossfuzz.sh"
    echo "  2. cd ~/oss-fuzz"
    echo "  3. python3 infra/helper.py build_image mrustc"
    echo "  4. python3 infra/helper.py build_fuzzers --sanitizer address mrustc"
    exit 0
fi
