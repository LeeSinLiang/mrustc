# Fuzzer Build Notes

## Quick Reference

### Build
```bash
bash fuzz/standalone_build.sh
```

### Run Coverage Mode (Default)
**Purpose**: Find buffer overflows, use-after-free, undefined behavior
**Detects**: ✅ Buffer overflows ✅ Use-after-free ✅ Double-free ✅ Undefined behavior ❌ Memory leaks

```bash
ASAN_OPTIONS=detect_leaks=0 ./fuzz_lexer -max_total_time=3600 fuzz/corpus/lexer
```

### Run Leak Detection Mode
**Purpose**: Find real memory leaks
**Detects**: ✅ All coverage mode bugs ✅ **Real memory leaks** ⚠️ Will crash on BUG()

```bash
FUZZER_NO_RECOVER=1 ./fuzz_lexer -max_total_time=300 fuzz/corpus/lexer
```

### Why Two Modes?

| Feature | Coverage Mode | Leak Detection Mode |
|---------|--------------|---------------------|
| **Buffer Overflows** | ✅ Detected | ✅ Detected |
| **Use-After-Free** | ✅ Detected | ✅ Detected |
| **Double-Free** | ✅ Detected | ✅ Detected |
| **Undefined Behavior** | ✅ Detected | ✅ Detected |
| **Memory Leaks** | ❌ Disabled (false positives) | ✅ **Detected** |
| **BUG() Handling** | ✅ Recovered (continues fuzzing) | ⚠️ Crashes (to enable leak detection) |
| **Code Coverage** | ✅ Maximum | ⚠️ Limited (stops at BUG()) |
| **Best Use** | Continuous fuzzing | Periodic leak checks |

**Coverage Mode** uses `longjmp()` to recover from `BUG()` assertions:
- Explores more code paths past TODO/unimplemented features
- `longjmp()` skips cleanup code → false positive leak reports

**Leak Detection Mode** disables `longjmp()` recovery:
- Normal execution paths preserved → real leak detection
- Will crash on `BUG()` assertions (expected - these are TODOs)

**Recommendation**: Run coverage mode continuously (daily/CI), leak detection mode periodically (weekly)

---

## Problem

The original README.md contained an incomplete build command for `fuzz_lexer` that resulted in linker errors. The command was missing many required source files.

## Root Cause

The lexer fuzzer has complex dependencies because:
1. It includes `parse/token.hpp` which contains interpolated fragments
2. Interpolated fragments reference AST types (Path, Pattern, Expr, etc.)
3. AST types pull in macro expansion and other compiler components
4. One function (`Expand_ParseAndExpand_ExprVal`) is referenced but not needed by the fuzzer

## Solution

Created three components to fix the build:

### 1. `fuzzer_stubs.cpp`
Provides stub implementations for compiler functions that are linked but never called during fuzzing:
- `Expand_ParseAndExpand_ExprVal` - macro expansion function

### 2. `standalone_build.sh`
Complete build script that includes all necessary source files:
- Core utilities: span, rc_string, debug, ident, version
- Parse components: lex, token, tokentree, tokenstream, ttstream, interpolated_fragment
- AST components: ast, path, types, pattern, expr
- Macro support: macro_rules/mod
- Stub implementations: fuzzer_stubs

### 3. Updated README.md
Simplified build instructions that reference the working build script.

## Complete Dependency Chain

```
fuzz_lexer.cpp
  └─ parse/lex.hpp
      └─ parse/token.hpp
          └─ parse/interpolated_fragment.hpp
              ├─ ast/path.hpp → ast/path.cpp
              ├─ ast/pattern.hpp → ast/pattern.cpp
              ├─ ast/expr.hpp → ast/expr.cpp
              ├─ ast/types.hpp → ast/types.cpp
              └─ ast/ast.hpp → ast/ast.cpp
                  └─ macro_rules/macro_rules.hpp → macro_rules/mod.cpp
                      └─ [references Expand_ParseAndExpand_ExprVal]
                          └─ fuzzer_stubs.cpp (provides stub)
```

## Build Command

```bash
bash fuzz/standalone_build.sh
```

This compiles with:
- AddressSanitizer (detects memory errors)
- UndefinedBehaviorSanitizer (detects undefined behavior)
- libFuzzer (fuzzing engine)

## Running the Fuzzer

The fuzzer has **two modes**:

### Mode 1: Coverage Mode (Default)
**Purpose**: Maximum code coverage, skip BUG() assertions
**Use for**: Finding buffer overflows, use-after-free, undefined behavior
**Detects**: ✅ Buffer overflows ✅ Use-after-free ✅ Double-free ❌ Memory leaks

```bash
# Quick test (60 seconds)
ASAN_OPTIONS=detect_leaks=0 ./fuzz_lexer -max_total_time=60 fuzz/corpus/lexer

# Extended fuzzing (24 hours)
mkdir -p fuzz/findings
ASAN_OPTIONS=detect_leaks=0 ./fuzz_lexer \
    -artifact_prefix=fuzz/findings/ \
    -max_total_time=86400 -workers=8 -jobs=8 \
    fuzz/corpus/lexer
```

### Mode 2: Leak Detection Mode
**Purpose**: Find memory leaks in the lexer
**Use for**: Detecting real memory leaks
**Detects**: ✅ Buffer overflows ✅ Use-after-free ✅ Memory leaks ⚠️ Crashes on BUG()

```bash
# Run with leak detection enabled
FUZZER_NO_RECOVER=1 ./fuzz_lexer -max_total_time=300 fuzz/corpus/lexer

# Or save leak reports to directory
mkdir -p fuzz/leak_findings
FUZZER_NO_RECOVER=1 ./fuzz_lexer \
    -artifact_prefix=fuzz/leak_findings/ \
    -max_total_time=300 \
    fuzz/corpus/lexer
```

**Why two modes?**
- Coverage mode uses `longjmp()` to recover from `BUG()` assertions, allowing more exploration
- `longjmp()` skips cleanup code, causing **false positive** leak reports
- Leak mode disables `longjmp()`, crashes on `BUG()`, but finds **real memory leaks**

**Recommendation**: Run coverage mode regularly, leak mode periodically to check for leaks

**Important options:**
- `FUZZER_NO_RECOVER=1` - Disable BUG() recovery, enable leak detection
- `ASAN_OPTIONS=detect_leaks=0` - Disable leak detection (coverage mode only)
- `-artifact_prefix=DIR/` - Save crash files to DIR (must end with `/`)
- `-max_total_time=SEC` - Run for SEC seconds
- `-workers=N -jobs=N` - Parallel fuzzing

## Debug Output Suppression

**Token trace debug output has been disabled** for fuzzing to prevent obstruction of fuzzer output.

The lexer's `FULL_TRACE` debug mode (enabled by default in `src/parse/tokenstream.cpp`) produces verbose messages like:
```
- getToken: <= TOK_INTEGER:514 (new)
- getToken: <= TOK_SEMICOLON (new)
```

These messages obstructed the fuzzer's output, making it difficult to see actual errors and crashes.

**Solution**: Modified `src/parse/tokenstream.cpp` to conditionally disable `FULL_TRACE` when `FUZZER_BUILD` is defined:
```cpp
#ifndef FUZZER_BUILD
#define FULL_TRACE
#endif
// For fuzzing, FULL_TRACE is disabled to reduce debug output noise
```

The `standalone_build.sh` script adds `-DFUZZER_BUILD=1` to compiler flags, ensuring clean fuzzer output.

**Note**: Some debug messages from `parseFloat` and `getTokenInt_RawString` remain, but these are infrequent and provide useful context about edge cases the fuzzer discovers.

## Sanitizer Status - IMPORTANT

**AddressSanitizer and UndefinedBehaviorSanitizer ARE ENABLED** despite this misleading warning:

```
NOTE: libFuzzer has rudimentary signal handlers.
      Combine libFuzzer with AddressSanitizer or similar for better crash reports.
```

**This warning is WRONG.** The sanitizers are fully functional:
- ✓ Binary contains 637 ASan symbols and 114 UBSan symbols
- ✓ ASan successfully detects memory errors (verified with overflow tests)
- ✓ Fuzzer finds real bugs in the lexer (empty char literals, bad UTF-8, etc.)

**Handling BUG() and TODO assertions:**

The fuzzer now gracefully handles mrustc's intentional `BUG()` macro calls (which call `abort()`) using signal handling:

1. When a `BUG()` or `TODO` is hit, the fuzzer catches SIGABRT
2. Uses `setjmp`/`longjmp` to recover and continue fuzzing
3. The input that triggered the BUG() is silently skipped (not counted as a crash)

Example BUG message you might see in output:
```
-:1:3 BUG:src/parse/lex.cpp:728: TODO: getTokenInt - Proper error for empty char literals
```

This means the fuzzer found an edge case that hits a TODO assertion, but it **won't crash** - it will continue fuzzing other inputs.

**Focus on real bugs:** The fuzzer is now configured to focus on finding actual memory corruption and undefined behavior bugs detected by ASan/UBSan, not unimplemented code paths.

**To verify sanitizers work:** Run `bash fuzz/verify_sanitizers.sh`

## Notes

- The fuzzer binary is ~11MB due to debug symbols and sanitizers
- All dependencies are compiled with the same sanitizer flags
- Stub functions throw exceptions if called (should never happen during fuzzing)
- For OSS-Fuzz integration, use `build.sh` which has a more comprehensive build process
- Crashes from `BUG()` macros are expected - these indicate the fuzzer found edge cases
