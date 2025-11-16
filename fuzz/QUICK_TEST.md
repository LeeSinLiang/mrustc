# Quick Local Testing Guide

This guide shows how to quickly test the OSS-Fuzz integration locally using just Docker, without needing the full OSS-Fuzz repository clone.

## Method 1: Using OSS-Fuzz Helper (Recommended)

### Setup

```bash
# Clone OSS-Fuzz
git clone https://github.com/google/oss-fuzz.git
cd oss-fuzz

# Copy mrustc fuzzing files
mkdir -p projects/mrustc
cd /path/to/mrustc
cp fuzz/{Dockerfile,build.sh,project.yaml,fuzz_lexer.cpp,fuzzer_stubs.cpp,fuzz_lexer_seed_corpus.zip} \
   /path/to/oss-fuzz/projects/mrustc/
```

### Build and Test

```bash
cd /path/to/oss-fuzz

# Build the Docker image
python3 infra/helper.py build_image mrustc

# Build fuzzers
python3 infra/helper.py build_fuzzers --sanitizer address mrustc

# Check build succeeded
python3 infra/helper.py check_build mrustc

# Run fuzzer for 60 seconds
python3 infra/helper.py run_fuzzer mrustc fuzz_lexer -- -max_total_time=60
```

## Method 2: Direct Docker Build (Quick Test)

For a quick test without OSS-Fuzz infrastructure:

```bash
cd /path/to/mrustc/fuzz

# Build Docker image
docker build -t oss-fuzz-mrustc .

# Run container interactively
docker run -it --rm \
  -e FUZZING_ENGINE=libfuzzer \
  -e SANITIZER=address \
  -e ARCHITECTURE=x86_64 \
  oss-fuzz-mrustc \
  /bin/bash

# Inside container:
export CC=clang
export CXX=clang++
export CFLAGS="-fsanitize=address,fuzzer-no-link"
export CXXFLAGS="-fsanitize=address,fuzzer-no-link"
export LIB_FUZZING_ENGINE="-fsanitize=fuzzer"
export OUT=/out
export SRC=/src
export WORK=/work

mkdir -p $OUT $WORK
bash /src/build.sh

# Run fuzzer
/out/fuzz_lexer -max_total_time=60 -dict=/out/fuzz_lexer.dict
```

## Method 3: Verify Dockerfile Only

Just verify the Dockerfile builds:

```bash
cd /path/to/mrustc/fuzz
docker build -t test-mrustc-fuzz .
```

If this succeeds, the Dockerfile is valid for OSS-Fuzz.

## Expected Output

### Successful Build

```
[*] Building mrustc components for lexer fuzzer...
[+] Compiling common utilities...
    - src/span.cpp
    - src/rc_string.cpp
    ...
[+] Compiling lexer components...
    - src/parse/lex.cpp
    ...
[*] Building fuzz_lexer...
[*] Copying seed corpus...
[*] Creating fuzzing dictionary...
[*] Build complete!
[*] Fuzzer output:
-rwxr-xr-x 1 root root 10M Nov 16 23:50 /out/fuzz_lexer
```

### Successful Run

```
INFO: Running with entropic power schedule (0xFF, 100).
INFO: Seed: 1234567890
INFO: Loaded 1 modules   (18931 inline 8-bit counters): ...
INFO: -max_len is not provided; libFuzzer will not generate inputs larger than 4096 bytes
INFO: A corpus is not provided, starting from an empty corpus
#2      INITED cov: 1234 ft: 5678 corp: 1/1b exec/s: 0 rss: 45Mb
#1024   pulse  cov: 1456 ft: 7890 corp: 45/678b exec/s: 512 rss: 48Mb
...
```

### If Crash Found

```
==12345==ERROR: AddressSanitizer: SEGV on unknown address 0x7fff12345678
...
==12345==ABORTING
artifact_prefix='./'; Test unit written to ./crash-abc123...
```

## Reproducing Known Crash

Test with the known UTF-8 crash:

```bash
# Get the crash file from repository
cd /path/to/mrustc

# Run fuzzer with crash file
python3 /path/to/oss-fuzz/infra/helper.py reproduce mrustc fuzz_lexer \
  crash-ba53db0b1e5bbed792294ccd1515f75f8a471ee1
```

Expected: SEGV in `isalpha()` due to invalid UTF-8

## Verifying Sanitizers

Check that sanitizers are properly enabled:

```bash
# After building, check the binary
nm /out/fuzz_lexer | grep -i asan
# Should show many __asan_* symbols

nm /out/fuzz_lexer | grep -i ubsan
# Should show __ubsan_* symbols

nm /out/fuzz_lexer | grep LLVMFuzzer
# Should show LLVMFuzzerTestOneInput
```

## Troubleshooting

### Build Fails - Missing Headers

**Problem:** Can't find mrustc headers

**Solution:** Make sure build.sh uses correct paths:
```bash
MRUSTC_CXXFLAGS="$CXXFLAGS -std=c++14 -Isrc/include -Isrc -Itools/common"
```

### Build Fails - Linker Errors

**Problem:** Undefined references

**Solution:** Add missing object files to build.sh or add stubs to fuzzer_stubs.cpp

### Fuzzer Crashes Immediately

**Problem:** SIGABRT from BUG() macro

**Solution:** This is normal - fuzzer has signal handling to catch these. Run with:
```bash
FUZZER_NO_RECOVER=1 ./fuzz_lexer <input>  # To see actual crash
```

### No Coverage Increase

**Problem:** Coverage stays flat

**Solution:**
1. Check seed corpus is loaded: `-seed_corpus_dir=/out/fuzz_lexer_seed_corpus`
2. Use dictionary: `-dict=/out/fuzz_lexer.dict`
3. Increase max_len: `-max_len=10000`

## Performance Tuning

### Parallel Fuzzing

```bash
# 8 workers
python3 infra/helper.py run_fuzzer mrustc fuzz_lexer -- \
  -workers=8 -jobs=8 -max_total_time=3600
```

### Longer Inputs

```bash
# Allow up to 100KB inputs
python3 infra/helper.py run_fuzzer mrustc fuzz_lexer -- \
  -max_len=102400
```

### Disable Leak Detection (Coverage Mode)

```bash
# Focus on coverage, not leaks
ASAN_OPTIONS=detect_leaks=0 python3 infra/helper.py run_fuzzer mrustc fuzz_lexer
```

## Next Steps

Once local testing succeeds:

1. **Submit to OSS-Fuzz:**
   - Fork https://github.com/google/oss-fuzz
   - Add projects/mrustc/ directory
   - Update project.yaml with real contact emails
   - Submit PR

2. **Monitor Results:**
   - Check https://oss-fuzz.com/ after merge
   - Review bug reports in ClusterFuzz
   - Check coverage reports

3. **Iterate:**
   - Fix found bugs
   - Add more fuzzers for other components
   - Improve seed corpus
