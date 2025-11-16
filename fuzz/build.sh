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

# OSS-Fuzz build script for mrustc lexer fuzzer
#
# Environment variables provided by OSS-Fuzz:
# - $CXX: C++ compiler with instrumentation
# - $CXXFLAGS: Compiler flags including sanitizers
# - $LIB_FUZZING_ENGINE: Fuzzing engine (libFuzzer, AFL, etc.)
# - $OUT: Output directory for fuzzers
# - $SRC: Source directory
# - $WORK: Temporary work directory

cd $SRC/mrustc

# Create object directory
mkdir -p $WORK/obj

echo "[*] Building mrustc components for lexer fuzzer..."

# Compiler flags for mrustc code
MRUSTC_CXXFLAGS="$CXXFLAGS -std=c++14 -Isrc/include -Isrc -Itools/common -DFUZZER_BUILD=1"

# Build common utility objects
echo "[+] Compiling common utilities..."
COMMON_OBJS=""
for src in src/span.cpp src/rc_string.cpp src/debug.cpp src/ident.cpp; do
    obj_name=$(basename $src .cpp).o
    echo "    - $src"
    $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK/obj/$obj_name
    COMMON_OBJS="$COMMON_OBJS $WORK/obj/$obj_name"
done

# Build parse/lexer components
echo "[+] Compiling lexer components..."
PARSE_OBJS=""
for src in src/parse/lex.cpp src/parse/parseerror.cpp src/parse/token.cpp \
           src/parse/tokentree.cpp src/parse/interpolated_fragment.cpp \
           src/parse/tokenstream.cpp src/parse/ttstream.cpp; do
    obj_name=$(basename $src .cpp).o
    echo "    - $src"
    $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK/obj/$obj_name
    PARSE_OBJS="$PARSE_OBJS $WORK/obj/$obj_name"
done

# Build AST components (required by token.cpp for interpolated fragments)
echo "[+] Compiling AST components..."
AST_OBJS=""
for src in src/ast/ast.cpp src/ast/crate.cpp src/ast/path.cpp \
           src/ast/expr.cpp src/ast/pattern.cpp src/ast/types.cpp; do
    obj_name=$(basename $src .cpp).o
    echo "    - $src"
    $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK/obj/$obj_name
    AST_OBJS="$AST_OBJS $WORK/obj/$obj_name"
done

# Build macro_rules components (required by AST)
echo "[+] Compiling macro_rules components..."
MACRO_OBJS=""
for src in src/macro_rules/mod.cpp src/macro_rules/parse.cpp \
           src/macro_rules/eval.cpp src/macro_rules/macro_rules.cpp; do
    obj_name=$(basename $src .cpp).o
    echo "    - $src"
    $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK/obj/$obj_name || true
    if [ -f $WORK/obj/$obj_name ]; then
        MACRO_OBJS="$MACRO_OBJS $WORK/obj/$obj_name"
    fi
done

# Build expand components (dependency of macro_rules)
echo "[+] Compiling expand components..."
EXPAND_OBJS=""
for src in src/expand/cfg.cpp src/expand/crate_tags.cpp; do
    obj_name=$(basename $src .cpp).o
    echo "    - $src"
    $CXX $MRUSTC_CXXFLAGS -c $src -o $WORK/obj/$obj_name || true
    if [ -f $WORK/obj/$obj_name ]; then
        EXPAND_OBJS="$EXPAND_OBJS $WORK/obj/$obj_name"
    fi
done

# Compile fuzzer stub functions
echo "[+] Compiling fuzzer stubs..."
$CXX $MRUSTC_CXXFLAGS -c $SRC/fuzzer_stubs.cpp -o $WORK/obj/fuzzer_stubs.o

# Build the lexer fuzzer
echo "[*] Building fuzz_lexer..."
$CXX $MRUSTC_CXXFLAGS \
    $SRC/fuzz_lexer.cpp \
    $COMMON_OBJS \
    $PARSE_OBJS \
    $AST_OBJS \
    $MACRO_OBJS \
    $EXPAND_OBJS \
    $WORK/obj/fuzzer_stubs.o \
    $LIB_FUZZING_ENGINE \
    -o $OUT/fuzz_lexer

# Copy seed corpus
if [ -f $SRC/fuzz_lexer_seed_corpus.zip ]; then
    echo "[*] Copying seed corpus..."
    cp $SRC/fuzz_lexer_seed_corpus.zip $OUT/
fi

# Create dictionary for better fuzzing
echo "[*] Creating fuzzing dictionary..."
cat > $OUT/fuzz_lexer.dict << 'EOF'
# Rust keywords
"fn"
"let"
"mut"
"pub"
"struct"
"enum"
"impl"
"trait"
"use"
"mod"
"crate"
"super"
"self"
"if"
"else"
"match"
"while"
"for"
"loop"
"break"
"continue"
"return"
"const"
"static"
"unsafe"
"async"
"await"
"dyn"
"move"

# Operators and delimiters
"->"
"=>"
"::"
"&&"
"||"
"=="
"!="
"<="
">="
"<<"
">>"

# Common patterns
"'static"
"'_"
"r#"
"b'"
"b\""
"0x"
"0o"
"0b"
"_"
"__"

# String escape sequences
"\\n"
"\\r"
"\\t"
"\\\\"
"\\'"
"\\\""
"\\x"
"\\u"

# UTF-8 sequences (potential bugs)
"\xC0\x80"
"\xE0\x80\x80"
"\xF0\x80\x80\x80"
"\xFF"
"\xFE"
EOF

echo "[*] Build complete!"
echo "[*] Fuzzer output:"
ls -lh $OUT/fuzz_lexer
