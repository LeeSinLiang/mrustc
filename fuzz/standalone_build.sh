#!/bin/bash
# Standalone build script for mrustc fuzzers (local testing without OSS-Fuzz)

set -e

CXX=${CXX:-clang++}
CXXFLAGS="-g -O1 -fsanitize=address,fuzzer,undefined -std=c++14"
VERSION_FLAGS="-DMRUSTC_VERSION=\"fuzz\" -DVERSION_GIT_ISDIRTY=0 -DVERSION_GIT_FULLHASH=\"fuzz\" -DVERSION_GIT_SHORTHASH=\"fuzz\" -DVERSION_BUILDTIME=\"fuzz\" -DVERSION_GIT_BRANCH=\"fuzz\""
INCLUDES="-Isrc/include -Isrc -Itools/common"
# Disable debug token tracing and all DEBUG() output to clean up fuzzer output
FUZZER_FLAGS="-DFUZZER_BUILD=1 -DDISABLE_DEBUG"

echo "[*] Building fuzz_lexer (minimal dependencies)..."

# Build the lexer fuzzer
$CXX $CXXFLAGS $INCLUDES $VERSION_FLAGS $FUZZER_FLAGS \
    fuzz/fuzz_lexer.cpp \
    fuzz/fuzzer_stubs.cpp \
    src/span.cpp src/rc_string.cpp src/debug.cpp src/ident.cpp src/version.cpp \
    src/parse/lex.cpp src/parse/parseerror.cpp src/parse/token.cpp \
    src/parse/tokentree.cpp src/parse/tokenstream.cpp src/parse/ttstream.cpp \
    src/parse/interpolated_fragment.cpp \
    src/ast/ast.cpp src/ast/path.cpp src/ast/types.cpp src/ast/pattern.cpp src/ast/expr.cpp \
    src/macro_rules/mod.cpp \
    -o fuzz_lexer || {
    echo "[!] Build failed - see errors above"
    echo "[!] Note: The lexer fuzzer has complex dependencies due to token interpolation"
    echo "[!] Additional dependencies may be required from expand/, resolve/, etc."
    exit 1
}

echo "[*] Successfully built fuzz_lexer"
echo "[*] Run with: ./fuzz_lexer -max_total_time=60"
