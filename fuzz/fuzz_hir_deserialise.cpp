/*
 * OSS-Fuzz Target for mrustc HIR Deserializer
 *
 * Fuzzes the HIR binary format deserializer which parses .hir files.
 * This is CRITICAL for security as it processes untrusted binary data
 * from external crates (supply chain attack vector).
 *
 * Attack Surface:
 * - Buffer overruns when reading length-prefixed data
 * - Integer overflow in size calculations (read_count)
 * - Out-of-bounds reads on invalid indices
 * - Type confusion in tagged union deserialization
 */

#include <cstdint>
#include <cstddef>
#include <string>
#include <cstring>
#include <stdexcept>

// Include mrustc headers
#include "hir/serialise_lowlevel.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    // Reject empty or overly large inputs
    if (Size == 0 || Size > 10000000) {
        return 0;
    }

    // Create a temporary file since HIR::serialise::Reader expects a file path
    char temp_filename[] = "/tmp/mrustc_fuzz_hir_XXXXXX";
    int fd = mkstemp(temp_filename);
    if (fd == -1) {
        return 0;
    }

    // Write fuzzer input to temp file
    ssize_t written = write(fd, Data, Size);
    close(fd);

    if (written != static_cast<ssize_t>(Size)) {
        unlink(temp_filename);
        return 0;
    }

    try {
        // Create HIR deserializer reader
        HIR::serialise::Reader reader(temp_filename);

        // Try to deserialize various primitive types that exercise
        // the most vulnerable code paths

        // Test 1: read_u8 (basic byte read)
        try {
            reader.read_u8();
        } catch (...) {}

        // Test 2: read_u16 (multi-byte read with endianness)
        try {
            reader.read_u16();
        } catch (...) {}

        // Test 3: read_u64c (variable-length encoding - complex logic)
        try {
            reader.read_u64c();
        } catch (...) {}

        // Test 4: read_count (CRITICAL - used for allocation sizes)
        // This is a prime target for integer overflow bugs
        try {
            size_t count = reader.read_count();
            // Don't actually allocate based on count - just test parsing
            (void)count;
        } catch (...) {}

        // Test 5: read_string (length-prefixed - buffer overrun risk)
        try {
            std::string s = reader.read_string();
            (void)s;
        } catch (...) {}

        // Test 6: read_istring (interned string with index lookup)
        // Can cause out-of-bounds if index is invalid
        try {
            // This will likely fail but tests the code path
            reader.read_istring();
        } catch (...) {}

        // Test 7: read_i64c (signed variable-length with 2's complement)
        try {
            reader.read_i64c();
        } catch (...) {}

        // Test 8: read_u128 (multi-part read)
        try {
            reader.read_u128();
        } catch (...) {}

        // Test 9: read_bool (validation logic)
        try {
            reader.read_bool();
        } catch (...) {}

        // Test 10: raw_read_uint (core protocol primitive)
        try {
            reader.raw_read_uint();
        } catch (...) {}

        // Test 11: raw_read_len (used for data structures)
        try {
            reader.raw_read_len();
        } catch (...) {}

        // Test 12: raw_read_bytes_stdstring (combined len + data read)
        try {
            std::string bytes = reader.raw_read_bytes_stdstring();
            (void)bytes;
        } catch (...) {}

        // Note: We intentionally catch all exceptions and continue
        // because we're fuzzing for crashes (which ASan/UBSan will catch),
        // not for thrown exceptions. Malformed input should throw, and
        // that's expected behavior.

    } catch (const std::exception& e) {
        // Expected for malformed input
    } catch (...) {
        // Catch all
    }

    // Clean up
    unlink(temp_filename);

    return 0;
}
