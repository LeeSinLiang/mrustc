# OSS-Fuzz Integration for mrustc

This directory contains the OSS-Fuzz integration for fuzzing the mrustc compiler, focusing on the lexer component.

## Overview

This integration provides continuous fuzzing for the mrustc lexer (tokenizer), which is the first stage of compilation that processes raw Rust source code into tokens. The lexer is a critical attack surface as it:
- Processes untrusted input (source code)
- Handles complex UTF-8 encoding
- Parses numbers, strings, and escape sequences
- Must handle invalid/malformed input safely

## Files

### Required OSS-Fuzz Files

1. **`Dockerfile`** - Defines the build environment
   - Based on `gcr.io/oss-fuzz-base/base-builder`
   - Installs build dependencies (make, zlib)
   - Clones mrustc repository
   - Copies build scripts and fuzzers

2. **`build.sh`** - OSS-Fuzz build script
   - Compiles mrustc components as a library
   - Links fuzzer with sanitizers
   - Creates dictionary file for better fuzzing
   - Packages seed corpus

3. **`project.yaml`** - Project metadata
   - Contact information
   - Language: C++
   - Sanitizers: address, undefined
   - Repository URL

### Fuzzer Files

4. **`fuzz_lexer.cpp`** - Lexer fuzzing harness
   - Entry point: `LLVMFuzzerTestOneInput()`
   - Signal handling for BUG()/TODO recovery
   - Token extraction loop with limits

5. **`fuzzer_stubs.cpp`** - Stub implementations
   - Minimal stubs for unused compiler functions
   - Allows linking without full compiler

6. **`fuzz_lexer_seed_corpus.zip`** - Seed corpus
   - Sample valid Rust code
   - Helps fuzzer learn valid syntax

## Known Vulnerabilities Found

The fuzzer has already discovered a **SEGV vulnerability** in UTF-8 handling:

**Location:** `src/parse/lex.cpp:305` in `issym()`
**Cause:** Passing large codepoint values (>255) to `std::isalpha()`
**Trigger:** Invalid UTF-8 sequences like `0xe6` followed by `)` in character literals
**Impact:** Denial of service, compiler crash

See crash file: `crash-ba53db0b1e5bbed792294ccd1515f75f8a471ee1`

## Testing Locally

### Prerequisites

You need Docker installed and the OSS-Fuzz repository:

```bash
git clone https://github.com/google/oss-fuzz.git
cd oss-fuzz
```

### Setup mrustc Project

Create the project directory and copy integration files:

```bash
mkdir -p projects/mrustc
cp /path/to/mrustc/fuzz/Dockerfile projects/mrustc/
cp /path/to/mrustc/fuzz/build.sh projects/mrustc/
cp /path/to/mrustc/fuzz/project.yaml projects/mrustc/
cp /path/to/mrustc/fuzz/fuzz_lexer.cpp projects/mrustc/
cp /path/to/mrustc/fuzz/fuzzer_stubs.cpp projects/mrustc/
cp /path/to/mrustc/fuzz/fuzz_lexer_seed_corpus.zip projects/mrustc/
```

### Build Fuzzer

```bash
# Build Docker image
python3 infra/helper.py build_image mrustc

# Build fuzzers with AddressSanitizer
python3 infra/helper.py build_fuzzers --sanitizer address mrustc

# Verify build
python3 infra/helper.py check_build mrustc
```

### Run Fuzzer

```bash
# Run for 60 seconds
python3 infra/helper.py run_fuzzer mrustc fuzz_lexer -- -max_total_time=60

# Run with specific corpus
python3 infra/helper.py run_fuzzer mrustc fuzz_lexer /path/to/corpus

# Run with dictionary
python3 infra/helper.py run_fuzzer mrustc fuzz_lexer -- -dict=fuzz_lexer.dict
```

### Advanced Testing

```bash
# Test with UndefinedBehaviorSanitizer
python3 infra/helper.py build_fuzzers --sanitizer undefined mrustc
python3 infra/helper.py run_fuzzer mrustc fuzz_lexer

# Generate coverage report
python3 infra/helper.py build_fuzzers --sanitizer coverage mrustc
python3 infra/helper.py coverage mrustc fuzz_lexer

# Run in batch mode
python3 infra/helper.py run_fuzzer mrustc fuzz_lexer -- -workers=8 -jobs=8
```

## Reproducing Crashes

When OSS-Fuzz finds a crash, it creates a test case file:

```bash
# Download crash file from ClusterFuzz
# Or use local crash file

# Reproduce crash
python3 infra/helper.py reproduce mrustc fuzz_lexer /path/to/crash-file

# Debug with gdb
python3 infra/helper.py shell mrustc
gdb --args /out/fuzz_lexer /testcase/crash-file
```

## Performance Expectations

- **Execution speed:** ~20,000 executions/second
- **Coverage:** ~1,800-2,000 edges (18,931 inline counters)
- **Memory usage:** Low (<100MB per worker)

## Dictionary

The build script automatically creates a dictionary file (`fuzz_lexer.dict`) containing:
- Rust keywords (fn, let, mut, struct, etc.)
- Operators (&&, ||, ->, =>, ::, etc.)
- Common patterns ('static, r#, b", etc.)
- Escape sequences (\n, \x, \u, etc.)
- Invalid UTF-8 sequences for bug finding

This helps the fuzzer generate more meaningful test cases.

## Continuous Fuzzing

Once integrated into OSS-Fuzz:

1. **Automatic builds:** Daily builds with latest mrustc code
2. **Continuous fuzzing:** 24/7 fuzzing on Google infrastructure
3. **Bug reports:** Automatic crash reports to maintainers
4. **Coverage tracking:** Regular coverage reports via Fuzz Introspector
5. **Regression testing:** Crashes become permanent test cases

## Monitoring

After integration, monitor fuzzing at:
- **ClusterFuzz UI:** https://oss-fuzz.com/
- **Coverage reports:** https://oss-fuzz.com/coverage-report/job/libfuzzer_asan_mrustc/latest
- **Fuzz Introspector:** https://oss-fuzz-introspector.storage.googleapis.com/mrustc/inspector-report/

## Extending Fuzzing

To add more fuzzers in the future:

1. Create new fuzzer: `fuzz_<component>.cpp`
2. Add compilation to `build.sh`
3. Create seed corpus: `fuzz_<component>_seed_corpus.zip`
4. Test locally before submitting PR

See `fuzz_expr_parser.cpp`, `fuzz_hir_deserialise.cpp`, and `fuzz_target_spec.cpp` for additional fuzzers.

## Contact

For questions about this integration:
- Open an issue in the mrustc repository
- Contact OSS-Fuzz team: https://github.com/google/oss-fuzz

## License

All fuzzing infrastructure is licensed under Apache 2.0 (required by OSS-Fuzz).
The mrustc project itself retains its original license.
