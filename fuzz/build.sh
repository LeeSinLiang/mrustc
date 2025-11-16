#!/bin/bash -eu
#
# OSS-Fuzz build script for mrustc
#
# This script is called by OSS-Fuzz to build the fuzzers.
# It should compile mrustc as a library and link each fuzzer against it.
#
# Environment variables set by OSS-Fuzz:
# - $CXX, $CC: Compiler with fuzzing instrumentation
# - $CXXFLAGS, $CFLAGS: Compilation flags (includes -fsanitize=...)
# - $LIB_FUZZING_ENGINE: Fuzzing engine library (libFuzzer)
# - $OUT: Directory for fuzzer binaries
# - $SRC: Source code directory

cd $SRC/mrustc

# Build mrustc object files as a library
# We need to compile all the C++ source files that the fuzzers depend on

echo "[*] Building mrustc components for fuzzing..."

# Create object directory
mkdir -p .obj-fuzz

# Compile all mrustc source files needed by the fuzzers
# We'll compile the minimal set required for each fuzzer

# Common files needed by all fuzzers
COMMON_OBJS=""
for src in span.cpp rc_string.cpp debug.cpp ident.cpp version.cpp; do
    echo "[+] Compiling src/$src"
    $CXX $CXXFLAGS -c -std=c++14 -O2 -Isrc/include -Isrc -Itools/common \
        -DMRUSTC_VERSION=\"fuzz\" \
        src/$src -o .obj-fuzz/$(basename $src .cpp).o
    COMMON_OBJS="$COMMON_OBJS .obj-fuzz/$(basename $src .cpp).o"
done

# Parse/lexer components for lexer and parser fuzzers
PARSE_OBJS=""
for src in parse/lex.cpp parse/parseerror.cpp parse/token.cpp parse/tokentree.cpp \
           parse/interpolated_fragment.cpp parse/tokenstream.cpp parse/ttstream.cpp; do
    echo "[+] Compiling src/$src"
    $CXX $CXXFLAGS -c -std=c++14 -O2 -Isrc/include -Isrc -Itools/common \
        src/$src -o .obj-fuzz/$(basename $src .cpp).o
    PARSE_OBJS="$PARSE_OBJS .obj-fuzz/$(basename $src .cpp).o"
done

# AST components for parser fuzzers
AST_OBJS=""
for src in ast/ast.cpp ast/crate.cpp ast/path.cpp ast/expr.cpp ast/pattern.cpp \
           ast/types.cpp ast/dump.cpp; do
    echo "[+] Compiling src/$src"
    $CXX $CXXFLAGS -c -std=c++14 -O2 -Isrc/include -Isrc -Itools/common \
        src/$src -o .obj-fuzz/$(basename $src .cpp).o
    AST_OBJS="$AST_OBJS .obj-fuzz/$(basename $src .cpp).o"
done

# Expression parser components
EXPR_PARSE_OBJS=""
for src in parse/expr.cpp parse/paths.cpp parse/types.cpp parse/pattern.cpp parse/root.cpp; do
    echo "[+] Compiling src/$src"
    $CXX $CXXFLAGS -c -std=c++14 -O2 -Isrc/include -Isrc -Itools/common \
        src/$src -o .obj-fuzz/$(basename $src .cpp).o || true
    if [ -f .obj-fuzz/$(basename $src .cpp).o ]; then
        EXPR_PARSE_OBJS="$EXPR_PARSE_OBJS .obj-fuzz/$(basename $src .cpp).o"
    fi
done

# HIR serialization components
HIR_OBJS=""
for src in hir/serialise_lowlevel.cpp hir/hir.cpp; do
    echo "[+] Compiling src/$src"
    $CXX $CXXFLAGS -c -std=c++14 -O2 -Isrc/include -Isrc -Itools/common \
        src/$src -o .obj-fuzz/$(basename $src .cpp).o || true
    if [ -f .obj-fuzz/$(basename $src .cpp).o ]; then
        HIR_OBJS="$HIR_OBJS .obj-fuzz/$(basename $src .cpp).o"
    fi
done

# Target spec components
TARGET_OBJS=""
for src in trans/target.cpp; do
    echo "[+] Compiling src/$src"
    $CXX $CXXFLAGS -c -std=c++14 -O2 -Isrc/include -Isrc -Itools/common \
        src/$src -o .obj-fuzz/$(basename $src .cpp).o || true
    if [ -f .obj-fuzz/$(basename $src .cpp).o ]; then
        TARGET_OBJS="$TARGET_OBJS .obj-fuzz/$(basename $src .cpp).o"
    fi
done

echo "[*] Building fuzzers..."

# Build fuzzer 1: HIR Deserializer
echo "[+] Building fuzz_hir_deserialise"
$CXX $CXXFLAGS -std=c++14 -Isrc/include -Isrc -Itools/common \
    fuzz/fuzz_hir_deserialise.cpp \
    $COMMON_OBJS $HIR_OBJS \
    $LIB_FUZZING_ENGINE -lz \
    -o $OUT/fuzz_hir_deserialise || echo "[-] Failed to build fuzz_hir_deserialise"

# Build fuzzer 2: Lexer
echo "[+] Building fuzz_lexer"
$CXX $CXXFLAGS -std=c++14 -Isrc/include -Isrc -Itools/common \
    fuzz/fuzz_lexer.cpp \
    $COMMON_OBJS $PARSE_OBJS $AST_OBJS \
    $LIB_FUZZING_ENGINE \
    -o $OUT/fuzz_lexer || echo "[-] Failed to build fuzz_lexer"

# Build fuzzer 3: Expression Parser
echo "[+] Building fuzz_expr_parser"
$CXX $CXXFLAGS -std=c++14 -Isrc/include -Isrc -Itools/common \
    fuzz/fuzz_expr_parser.cpp \
    $COMMON_OBJS $PARSE_OBJS $AST_OBJS $EXPR_PARSE_OBJS \
    $LIB_FUZZING_ENGINE \
    -o $OUT/fuzz_expr_parser || echo "[-] Failed to build fuzz_expr_parser"

# Build fuzzer 4: Target Spec Parser
echo "[+] Building fuzz_target_spec"
$CXX $CXXFLAGS -std=c++14 -Isrc/include -Isrc -Itools/common \
    fuzz/fuzz_target_spec.cpp \
    $COMMON_OBJS $TARGET_OBJS \
    $LIB_FUZZING_ENGINE \
    -o $OUT/fuzz_target_spec || echo "[-] Failed to build fuzz_target_spec"

echo "[*] Fuzzer build complete!"
echo "[*] Built fuzzers:"
ls -lh $OUT/fuzz_*
