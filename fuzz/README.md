# mrustc Fuzzing with OSS-Fuzz

This directory contains fuzzing harnesses for mrustc components using libFuzzer/OSS-Fuzz.

## Fuzzers

### 1. `fuzz_hir_deserialise` - HIR Binary Deserializer (CRITICAL)
**Priority**: 🔴 CRITICAL
**File**: `fuzz_hir_deserialise.cpp`

Tests the HIR binary format deserializer that parses `.hir` files from external crates.

**Attack Surface**:
- Buffer overruns in length-prefixed data reads
- Integer overflow in `read_count()` used for allocations
- Out-of-bounds access on invalid type references
- Memory corruption from malformed binary structures

**Why Critical**: Supply chain attack vector - malicious crates could exploit this.

---

### 2. `fuzz_lexer` - Lexer/Tokenizer
**Priority**: 🔴 CRITICAL
**File**: `fuzz_lexer.cpp`

Tests the lexer that converts UTF-8 Rust source code into tokens.

**Attack Surface**:
- Integer overflow in number parsing (`parseInt`, `parseFloat`)
- UTF-8 validation bugs
- Buffer overruns in string/char literal parsing
- Infinite loops in raw string delimiter matching
- Escape sequence handling bugs

**Why Important**: First stage of compilation, fast fuzzing, high bug potential.

---

### 3. `fuzz_expr_parser` - Expression Parser
**Priority**: 🟡 HIGH
**File**: `fuzz_expr_parser.cpp`

Tests the recursive descent expression parser.

**Attack Surface**:
- Stack overflow from deeply nested expressions
- Infinite recursion in malformed recursive constructs
- Memory exhaustion from large expression trees
- Parser state bugs in complex lookahead scenarios

**Why Important**: 54K lines of complex parsing logic.

---

### 4. `fuzz_target_spec` - Target Specification Parser
**Priority**: 🟢 MEDIUM
**File**: `fuzz_target_spec.cpp`

Tests the TOML parser for custom target specifications.

**Attack Surface**:
- TOML parsing bugs
- Type confusion (invalid arch/ABI combinations)
- Integer overflow in alignment values
- Config injection risks

---

## Building and Running Locally

### Prerequisites

```bash
# Install dependencies
sudo apt-get install -y clang libz-dev

# Build libFuzzer (if not using OSS-Fuzz infrastructure)
git clone https://github.com/llvm/llvm-project.git
cd llvm-project/compiler-rt/lib/fuzzer
./build.sh
```

### Manual Build (Standalone)

```bash
cd /path/to/mrustc

# Use the standalone build script (simplest method)
bash fuzz/standalone_build.sh

# Verify sanitizers are enabled (optional)
bash fuzz/verify_sanitizers.sh

# Run the fuzzer (coverage mode - finds buffer overflows, use-after-free)
ASAN_OPTIONS=detect_leaks=0 ./fuzz_lexer -max_total_time=60 fuzz/corpus/lexer

# Run in leak detection mode (finds memory leaks, but crashes on BUG())
FUZZER_NO_RECOVER=1 ./fuzz_lexer -max_total_time=300 fuzz/corpus/lexer

# Save crash files to specific directory
mkdir -p fuzz/findings
ASAN_OPTIONS=detect_leaks=0 ./fuzz_lexer \
    -artifact_prefix=fuzz/findings/ \
    -max_total_time=3600 \
    fuzz/corpus/lexer
```

**Fuzzer modes:**
- **Coverage mode** (default): Skips BUG() assertions, finds buffer overflows/use-after-free
- **Leak mode** (`FUZZER_NO_RECOVER=1`): Crashes on BUG(), finds real memory leaks

**Fuzzer options:**
- `FUZZER_NO_RECOVER=1` - Enable leak detection mode (will crash on BUG() assertions)
- `ASAN_OPTIONS=detect_leaks=0` - Disable leak detection in coverage mode
- `-artifact_prefix=DIR/` - Save crashes to directory (must end with `/`)
- `-max_total_time=SEC` - Fuzz for SEC seconds
- `-workers=N -jobs=N` - Parallel fuzzing with N workers

**Note**: The lexer fuzzer has complex dependencies due to token interpolation support. The standalone build script (`fuzz/standalone_build.sh`) includes all necessary source files and stub implementations.

**Sanitizers**: The fuzzer is built with:
- **AddressSanitizer (ASan)**: Detects memory errors (buffer overflows, use-after-free, etc.)
- **UndefinedBehaviorSanitizer (UBSan)**: Detects undefined behavior (integer overflow, null dereference, etc.)
- **libFuzzer**: Coverage-guided fuzzing engine

To verify sanitizers are active, run: `bash fuzz/verify_sanitizers.sh`

### OSS-Fuzz Build (Recommended)

```bash
# Clone OSS-Fuzz
git clone https://github.com/google/oss-fuzz.git
cd oss-fuzz

# Create project directory
mkdir -p projects/mrustc

# Copy fuzzing files
cp /path/to/mrustc/fuzz/build.sh projects/mrustc/
cp /path/to/mrustc/fuzz/project.yaml projects/mrustc/

# Build Docker image
python3 infra/helper.py build_image mrustc

# Build fuzzers
python3 infra/helper.py build_fuzzers --sanitizer address mrustc

# Run a fuzzer
python3 infra/helper.py run_fuzzer mrustc fuzz_lexer -- -max_total_time=300
```

---

## Corpus Generation

### For HIR Deserializer

```bash
# Build mrustc and compile libstd to generate .hir files
make -f minicargo.mk LIBS

# Copy .hir files as corpus seeds
mkdir -p corpus/fuzz_hir_deserialise
cp output/*.hir corpus/fuzz_hir_deserialise/
```

### For Lexer and Parser

```bash
# Download rustc test suite
git clone --depth 1 https://github.com/rust-lang/rust.git
mkdir -p corpus/fuzz_lexer corpus/fuzz_expr_parser

# Copy Rust source files
find rust/tests -name "*.rs" | head -1000 | xargs -I{} cp {} corpus/fuzz_lexer/
cp -r corpus/fuzz_lexer/* corpus/fuzz_expr_parser/

# Also add simple seeds
echo 'fn main() {}' > corpus/fuzz_lexer/simple.rs
echo '1 + 1' > corpus/fuzz_expr_parser/expr.rs
```

### For Target Spec Parser

```bash
# Extract target specs from rustc
git clone --depth 1 https://github.com/rust-lang/rust.git
mkdir -p corpus/fuzz_target_spec

# Copy .toml target spec files
find rust/compiler/rustc_target/spec -name "*.toml" -exec cp {} corpus/fuzz_target_spec/ \;
```

---

## Running Fuzzers

### Quick Test (1 minute each)

```bash
./fuzz_hir_deserialise -max_total_time=60 corpus/fuzz_hir_deserialise
./fuzz_lexer -max_total_time=60 corpus/fuzz_lexer
./fuzz_expr_parser -max_total_time=60 corpus/fuzz_expr_parser
./fuzz_target_spec -max_total_time=60 corpus/fuzz_target_spec
```

### Long-Running Fuzzing

```bash
# Run each fuzzer for 24 hours
./fuzz_hir_deserialise -max_total_time=86400 \
    -workers=4 -jobs=4 \
    -timeout=25 \
    corpus/fuzz_hir_deserialise

./fuzz_lexer -max_total_time=86400 \
    -workers=8 -jobs=8 \
    corpus/fuzz_lexer

./fuzz_expr_parser -max_total_time=86400 \
    -workers=4 -jobs=4 \
    -timeout=30 \
    corpus/fuzz_expr_parser
```

### Useful Options

```bash
-max_total_time=SECONDS  # Stop after N seconds
-workers=N               # Number of parallel workers
-jobs=N                  # Number of jobs per worker
-timeout=SECONDS         # Timeout for single input
-max_len=BYTES          # Maximum input length
-dict=DICT_FILE         # Use dictionary for mutations
-only_ascii=1           # Only ASCII mutations (for lexer)
```

---

## Interpreting Results

### Crashes

If a fuzzer finds a crash, it will save it to:
- `crash-<hash>` - The input that caused the crash
- `leak-<hash>` - Memory leak
- `timeout-<hash>` - Input that timed out

### Reproducing Crashes

```bash
# Run fuzzer with specific input
./fuzz_lexer crash-abc123

# Run under debugger
gdb --args ./fuzz_lexer crash-abc123

# Get stack trace
./fuzz_lexer crash-abc123 2>&1 | grep -A 20 "ERROR: AddressSanitizer"
```

### Minimizing Crashes

```bash
# Minimize crashing input
./fuzz_lexer -minimize_crash=1 \
    -exact_artifact_path=minimized_crash \
    crash-abc123
```

---

## Expected Bugs

### HIR Deserializer
- ✅ Buffer overruns
- ✅ Integer overflow
- ✅ Out-of-bounds reads
- ✅ Type confusion

### Lexer
- ✅ Integer overflow in number parsing
- ✅ UTF-8 bugs
- ✅ Infinite loops (caught by timeout)

### Expression Parser
- ✅ Stack overflow (deeply nested expressions)
- ✅ Infinite recursion

### Target Spec Parser
- ✅ TOML parsing bugs
- ✅ Config validation issues

---

## Performance

Typical fuzzing throughput:

- **HIR Deserializer**: ~50,000 exec/sec (very fast, small inputs)
- **Lexer**: ~20,000 exec/sec (fast)
- **Expression Parser**: ~5,000 exec/sec (moderate, tree construction)
- **Target Spec Parser**: ~10,000 exec/sec (moderate, TOML parsing)

---

## Continuous Fuzzing

For continuous fuzzing, consider using:

1. **OSS-Fuzz** (Google's continuous fuzzing service)
2. **ClusterFuzz** (Google's distributed fuzzing infrastructure)
3. **Local continuous fuzzing** (run fuzzers in tmux/screen sessions)

---

## Troubleshooting

### Build Errors

```bash
# Missing headers
export CXXFLAGS="-Isrc/include -Isrc -Itools/common"

# Linker errors
# Add missing .o files to the link command

# zlib errors
sudo apt-get install libz-dev
```

### Runtime Errors

```bash
# Out of memory
# Reduce -workers or -jobs

# Too slow
# Increase -timeout
# Reduce -max_len

# No interesting inputs
# Check corpus seeds
# Verify fuzzer is exercising code paths
```

---

## Contributing

Found a bug? Please report it:

1. Save the crashing input: `crash-<hash>`
2. Minimize it: `./fuzzer -minimize_crash=1 crash-<hash>`
3. Create a GitHub issue with:
   - Fuzzer name
   - Minimized input (or attach file)
   - Stack trace
   - mrustc commit hash

---

## References

- [libFuzzer Documentation](https://llvm.org/docs/LibFuzzer.html)
- [OSS-Fuzz](https://github.com/google/oss-fuzz)
- [mrustc Repository](https://github.com/thepowersgang/mrustc)
- [FUZZING_TARGETS.md](../FUZZING_TARGETS.md) - Detailed target analysis
