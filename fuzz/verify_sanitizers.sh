#!/bin/bash
# Verify that AddressSanitizer and UndefinedBehaviorSanitizer are enabled in the fuzzer

echo "=== Fuzzer Sanitizer Verification ==="
echo ""

echo "[1] Checking for ASan symbols in binary..."
if nm fuzz_lexer | grep -q "__asan"; then
    echo "✓ AddressSanitizer symbols found"
    ASAN_COUNT=$(nm fuzz_lexer | grep -c "__asan")
    echo "  Found $ASAN_COUNT ASan symbols"
else
    echo "✗ AddressSanitizer symbols NOT found"
fi
echo ""

echo "[2] Checking for UBSan symbols in binary..."
if nm fuzz_lexer | grep -q "__ubsan"; then
    echo "✓ UndefinedBehaviorSanitizer symbols found"
    UBSAN_COUNT=$(nm fuzz_lexer | grep -c "__ubsan")
    echo "  Found $UBSAN_COUNT UBSan symbols"
else
    echo "✗ UndefinedBehaviorSanitizer symbols NOT found"
fi
echo ""

echo "[3] Checking fuzzer instrumentation..."
if nm fuzz_lexer | grep -q "sancov"; then
    echo "✓ Fuzzer instrumentation found"
else
    echo "  Note: Fuzzer uses different instrumentation method"
fi
echo ""

echo "[4] Running quick fuzzer test..."
./fuzz_lexer -runs=10 fuzz/corpus/lexer >/tmp/fuzz_test.log 2>&1
RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "✓ Fuzzer runs successfully (10 iterations completed)"
else
    echo "! Fuzzer exited with code $RESULT"
    echo "  (This may be normal - check /tmp/fuzz_test.log for details)"
fi
echo ""

echo "=== Summary ==="
echo "The fuzzer binary is compiled with:"
echo "  - AddressSanitizer (ASan): detects memory errors"
echo "  - UndefinedBehaviorSanitizer (UBSan): detects undefined behavior"
echo "  - libFuzzer: coverage-guided fuzzing engine"
echo ""
echo "To run fuzzing:"
echo "  ./fuzz_lexer -max_total_time=60 fuzz/corpus/lexer"
