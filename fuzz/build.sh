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

cd $SRC/mrustc

echo "[*] Building fuzz_lexer..."

# Compiler flags for mrustc code
MRUSTC_CXXFLAGS="$CXXFLAGS -std=c++14 -Isrc/include -Isrc -Itools/common -DFUZZER_BUILD=1 -DDISABLE_DEBUG"

# Build the lexer fuzzer in one command (like standalone_build.sh)
$CXX $MRUSTC_CXXFLAGS \
    fuzz/fuzz_lexer.cpp \
    fuzz/fuzzer_stubs.cpp \
    src/span.cpp src/rc_string.cpp src/debug.cpp src/ident.cpp \
    src/parse/lex.cpp src/parse/parseerror.cpp src/parse/token.cpp \
    src/parse/tokentree.cpp src/parse/tokenstream.cpp src/parse/ttstream.cpp \
    src/parse/interpolated_fragment.cpp \
    src/ast/ast.cpp src/ast/path.cpp src/ast/types.cpp src/ast/pattern.cpp src/ast/expr.cpp \
    src/macro_rules/mod.cpp \
    $LIB_FUZZING_ENGINE \
    -o $OUT/fuzz_lexer

echo "[*] Successfully built fuzz_lexer"

# Copy seed corpus
if [ -f fuzz/fuzz_lexer_seed_corpus.zip ]; then
    echo "[*] Copying seed corpus..."
    cp fuzz/fuzz_lexer_seed_corpus.zip $OUT/
fi

# Copy fuzzer options
if [ -f fuzz/fuzz_lexer.options ]; then
    echo "[*] Copying fuzzer options..."
    cp fuzz/fuzz_lexer.options $OUT/
fi

echo "[*] Build complete!"
ls -lh $OUT/fuzz_lexer
