#!/bin/bash -eu
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

# OSS-Fuzz build script for mrustc fuzzers
#
# Environment variables provided by OSS-Fuzz:
# - $CXX: C++ compiler with instrumentation
# - $CXXFLAGS: Compiler flags including sanitizers
# - $LIB_FUZZING_ENGINE: Fuzzing engine (libFuzzer, AFL, etc.)
# - $OUT: Output directory for fuzzers
# - $SRC: Source directory

# For local builds, set defaults
: ${CXX:=clang++}
# Check if we have fuzzer libraries available
if [ -f "/usr/lib/llvm-18/lib/clang/18/lib/linux/libclang_rt.fuzzer-x86_64.a" ]; then
    : ${CXXFLAGS:=-fsanitize=address,undefined -g}
    : ${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}
else
    echo "[!] Fuzzer sanitizer libraries not found, using standalone mode"
    echo "    Building without AddressSanitizer for local testing"
    : ${CXXFLAGS:=-g -O1}
    : ${LIB_FUZZING_ENGINE:=$(pwd)/fuzz/standalone_fuzzer_stub.o}
fi
: ${OUT:=.}
: ${SRC:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}

cd "$SRC/mrustc" || cd "$SRC"

echo "[*] Building mrustc fuzzers..."
echo "    CXX=$CXX"
echo "    CXXFLAGS=$CXXFLAGS"
echo "    OUT=$OUT"

# If using standalone mode, build the stub first
if [[ "$LIB_FUZZING_ENGINE" == *"standalone_fuzzer_stub"* ]]; then
    echo "[*] Building standalone fuzzer stub for local testing..."
    $CXX -c fuzz/standalone_fuzzer_stub.cpp -o fuzz/standalone_fuzzer_stub.o
fi

# Common compiler flags for all fuzzers
MRUSTC_CXXFLAGS="$CXXFLAGS -std=c++14 -Isrc/include -Isrc -Itools/common -DFUZZER_BUILD=1 -DDISABLE_DEBUG"

# Track build status
BUILT_FUZZERS=()
FAILED_FUZZERS=()

# ============================================================================
# 1. fuzz_lexer - Lexer/Tokenizer fuzzer (CRITICAL)
# ============================================================================
echo ""
echo "[*] Building fuzz_lexer..."
if $CXX $MRUSTC_CXXFLAGS \
    fuzz/fuzz_lexer.cpp \
    fuzz/fuzzer_stubs.cpp \
    src/span.cpp src/rc_string.cpp src/debug.cpp src/ident.cpp \
    src/parse/lex.cpp src/parse/parseerror.cpp src/parse/token.cpp \
    src/parse/tokentree.cpp src/parse/tokenstream.cpp src/parse/ttstream.cpp \
    src/parse/interpolated_fragment.cpp \
    src/ast/ast.cpp src/ast/path.cpp src/ast/types.cpp src/ast/pattern.cpp src/ast/expr.cpp \
    src/macro_rules/mod.cpp \
    $LIB_FUZZING_ENGINE \
    -o "$OUT/fuzz_lexer" 2>&1 | tee /tmp/fuzz_lexer_build.log; then

    echo "[✓] Successfully built fuzz_lexer"
    BUILT_FUZZERS+=("fuzz_lexer")

    # Copy seed corpus and options
    [ -f fuzz/fuzz_lexer_seed_corpus.zip ] && cp fuzz/fuzz_lexer_seed_corpus.zip "$OUT/"
    [ -f fuzz/fuzz_lexer.options ] && cp fuzz/fuzz_lexer.options "$OUT/"
    [ -f fuzz/fuzz_lexer.dict ] && cp fuzz/fuzz_lexer.dict "$OUT/"
else
    echo "[✗] Failed to build fuzz_lexer"
    FAILED_FUZZERS+=("fuzz_lexer")
    tail -20 /tmp/fuzz_lexer_build.log
fi

# ============================================================================
# 2. fuzz_hir_deserialise - HIR Binary Deserializer fuzzer (CRITICAL)
# ============================================================================
echo ""
echo "[*] Building fuzz_hir_deserialise..."
if $CXX $MRUSTC_CXXFLAGS \
    fuzz/fuzz_hir_deserialise.cpp \
    src/hir/serialise_lowlevel.cpp \
    src/span.cpp src/rc_string.cpp src/debug.cpp \
    $LIB_FUZZING_ENGINE \
    -lz \
    -o "$OUT/fuzz_hir_deserialise" 2>&1 | tee /tmp/fuzz_hir_build.log; then

    echo "[✓] Successfully built fuzz_hir_deserialise"
    BUILT_FUZZERS+=("fuzz_hir_deserialise")
else
    echo "[✗] Failed to build fuzz_hir_deserialise"
    FAILED_FUZZERS+=("fuzz_hir_deserialise")
    tail -20 /tmp/fuzz_hir_build.log
fi

# ============================================================================
# 3. fuzz_expr_parser - Expression Parser fuzzer (HIGH)
# ============================================================================
echo ""
echo "[*] Building fuzz_expr_parser..."
echo "    Attempting build with comprehensive stubs..."

# Try building with comprehensive stubs that provide minimal implementations
# of HIR, CFG, macro parsing, and path helpers
if $CXX $MRUSTC_CXXFLAGS \
    fuzz/fuzz_expr_parser.cpp \
    fuzz/fuzzer_stubs_expr_parser.cpp \
    src/span.cpp src/rc_string.cpp src/debug.cpp src/ident.cpp \
    src/parse/lex.cpp src/parse/parseerror.cpp src/parse/token.cpp \
    src/parse/tokentree.cpp src/parse/tokenstream.cpp src/parse/ttstream.cpp \
    src/parse/interpolated_fragment.cpp \
    src/parse/expr.cpp src/parse/pattern.cpp src/parse/types.cpp src/parse/paths.cpp \
    src/parse/root.cpp \
    src/ast/ast.cpp src/ast/path.cpp src/ast/types.cpp src/ast/pattern.cpp src/ast/expr.cpp \
    src/ast/crate.cpp \
    src/macro_rules/mod.cpp \
    $LIB_FUZZING_ENGINE \
    -o "$OUT/fuzz_expr_parser" 2>&1 | tee /tmp/fuzz_expr_build.log; then

    echo "[✓] Successfully built fuzz_expr_parser"
    BUILT_FUZZERS+=("fuzz_expr_parser")
else
    echo "[✗] Failed to build fuzz_expr_parser"
    FAILED_FUZZERS+=("fuzz_expr_parser")
    echo "    Error details:"
    tail -30 /tmp/fuzz_expr_build.log
fi

# ============================================================================
# 4. fuzz_target_spec - Target Specification Parser fuzzer (MEDIUM)
# ============================================================================
echo ""
echo "[*] Building fuzz_target_spec..."
echo "    Note: This fuzzer requires substantial compiler infrastructure"

# Target spec parser requires a LOT of dependencies - it's the most complex
# For now, we'll skip it if it causes problems
# It needs: HIR, type checking, constant evaluation, etc.

echo "[!] fuzz_target_spec requires extensive HIR/typeck infrastructure"
echo "    Skipping for now - needs custom integration approach"
FAILED_FUZZERS+=("fuzz_target_spec (requires HIR infrastructure)")

# Uncomment to attempt build (will likely fail without extensive stubs):
# if $CXX $MRUSTC_CXXFLAGS \
#     fuzz/fuzz_target_spec.cpp \
#     src/trans/target.cpp \
#     ... (many more files needed) \
#     $LIB_FUZZING_ENGINE \
#     -o "$OUT/fuzz_target_spec"; then
#     echo "[✓] Successfully built fuzz_target_spec"
#     BUILT_FUZZERS+=("fuzz_target_spec")
# fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "=========================================="
echo "Build Summary"
echo "=========================================="
echo ""
echo "Successfully built fuzzers (${#BUILT_FUZZERS[@]}):"
for fuzzer in "${BUILT_FUZZERS[@]}"; do
    echo "  ✓ $fuzzer"
    ls -lh "$OUT/$fuzzer"
done

if [ ${#FAILED_FUZZERS[@]} -gt 0 ]; then
    echo ""
    echo "Failed to build (${#FAILED_FUZZERS[@]}):"
    for fuzzer in "${FAILED_FUZZERS[@]}"; do
        echo "  ✗ $fuzzer"
    done
fi

echo ""
echo "Build complete!"

# Exit with error if no fuzzers were built
if [ ${#BUILT_FUZZERS[@]} -eq 0 ]; then
    echo "ERROR: No fuzzers were successfully built"
    exit 1
fi

# Exit successfully if at least some fuzzers built
exit 0
