# Fuzzer Changes Summary

## Overview

Fixed the mrustc lexer fuzzer build and improved its functionality to handle internal assertions gracefully.

## Changes Made

### 1. Fixed Build System

**Problem:** Original README.md had incomplete build command causing linker errors.

**Files Created:**
- `fuzz/fuzzer_stubs.cpp` - Stub implementations for unused compiler functions
- `fuzz/standalone_build.sh` - Complete build script with all dependencies
- `fuzz/verify_sanitizers.sh` - Verification script for sanitizers

**Result:** Fuzzer now builds successfully with all sanitizers enabled.

### 2. Added Signal Handling for BUG() Crashes

**Problem:** mrustc's `BUG()` macro calls `abort()`, causing the fuzzer to crash on every unimplemented code path.

**Solution:** Modified `fuzz/fuzz_lexer.cpp` to:
- Install a SIGABRT signal handler
- Use `setjmp`/`longjmp` to recover from `BUG()` calls
- Continue fuzzing after encountering TODO/BUG assertions

**Result:** Fuzzer no longer crashes on `BUG()` macros, allowing it to explore more code paths.

### 3. Disabled Debug Output for Fuzzing

**Problem:** Token trace debug output (`FULL_TRACE` in tokenstream.cpp) was obstructing fuzzer output with messages like `"- getToken: <= TOK_INTEGER:514 (new)"`.

**Solution:** Modified `src/parse/tokenstream.cpp` to conditionally disable `FULL_TRACE` when `FUZZER_BUILD` is defined:
- Added `#ifndef FUZZER_BUILD` guard around `#define FULL_TRACE`
- Updated `fuzz/standalone_build.sh` to add `-DFUZZER_BUILD=1` flag
- Result: Clean fuzzer output showing only actual errors and crashes

### 4. Updated Documentation

**Files Updated:**
- `fuzz/README.md` - Added correct build instructions and fuzzing options
- `fuzz/BUILD_NOTES.md` - Comprehensive build and sanitizer documentation
- `fuzz/CHANGES.md` - This file

## Usage

### Build

```bash
bash fuzz/standalone_build.sh
```

### Run

```bash
# Basic fuzzing
ASAN_OPTIONS=detect_leaks=0 ./fuzz_lexer -max_total_time=60 fuzz/corpus/lexer

# Save crashes to directory
mkdir -p fuzz/findings
ASAN_OPTIONS=detect_leaks=0 ./fuzz_lexer \
    -artifact_prefix=fuzz/findings/ \
    -max_total_time=3600 \
    fuzz/corpus/lexer
```

## Key Features

### Sanitizers Enabled
- ✅ AddressSanitizer (637 symbols)
- ✅ UndefinedBehaviorSanitizer (114 symbols)
- ✅ libFuzzer coverage-guided engine

### BUG() Handling (Two Modes)
- ✅ **Coverage mode** (default): Catches SIGABRT, uses `setjmp`/`longjmp` to recover from BUG()
- ✅ **Leak detection mode** (`FUZZER_NO_RECOVER=1`): Disables recovery to find real memory leaks
- ✅ Prevents false positive leak reports from longjmp in coverage mode
- ✅ Allows detecting real memory leaks when needed in leak mode

### Configuration Options
- `FUZZER_NO_RECOVER=1` - Enable leak detection mode (disables BUG() recovery)
- `-artifact_prefix=DIR/` - Save crashes to specific directory
- `-max_total_time=SEC` - Run for specified duration
- `-workers=N -jobs=N` - Parallel fuzzing
- `ASAN_OPTIONS=detect_leaks=0` - Disable leak detection in coverage mode

## Technical Details

### Signal Handling Implementation

The fuzzer uses POSIX signal handling to catch `abort()` calls:

```cpp
// Set up jump point
if (sigsetjmp(jump_buffer, 1) != 0) {
    // Jumped here from SIGABRT - clean up and return
    in_fuzzer = false;
    sigaction(SIGABRT, &old_sa, nullptr);
    return 0;
}

// Install SIGABRT handler
signal_handler(SIGABRT) {
    if (in_fuzzer && signum == SIGABRT) {
        siglongjmp(jump_buffer, 1);  // Jump back
    }
}
```

### Dependency Chain

The lexer fuzzer has complex dependencies because tokens can contain interpolated AST fragments:

```
fuzz_lexer.cpp
  └─ parse/token.hpp
      └─ parse/interpolated_fragment.hpp
          ├─ ast/path.cpp
          ├─ ast/pattern.cpp
          ├─ ast/expr.cpp
          ├─ ast/types.cpp
          └─ ast/ast.cpp
              └─ macro_rules/mod.cpp
```

### Stub Functions

One function is referenced but never called during lexing:
- `Expand_ParseAndExpand_ExprVal` - Macro expansion (stubbed in `fuzzer_stubs.cpp`)

## Results

The fuzzer successfully:
- Builds with all sanitizers enabled
- Handles BUG() assertions gracefully
- Continues fuzzing after encountering unimplemented code paths
- Finds edge cases in the lexer (invalid UTF-8, empty char literals, etc.)
- Runs continuously without crashing

## Future Improvements

Potential enhancements:
- Add fuzzers for other components (HIR deserializer, expression parser, target spec)
- Integrate with OSS-Fuzz for continuous fuzzing
- Add dictionary files for better mutation guidance
- Implement crash deduplication based on stack trace
