/*
 * OSS-Fuzz Target for mrustc Target Specification Parser
 *
 * Fuzzes the TOML parser that loads custom target specifications.
 * Tests malformed TOML, invalid architecture values, and type conversions.
 *
 * Attack Surface:
 * - TOML parsing bugs (malformed structure)
 * - Type confusion (invalid arch/ABI combinations)
 * - Integer overflow in alignment values
 * - String validation issues in codegen options
 */

#include <cstdint>
#include <cstddef>
#include <string>
#include <fstream>
#include <cstdio>
#include <unistd.h>

// NOTE: The actual load_spec_from_file function is in an anonymous namespace
// in target.cpp, so we can't directly call it. Instead, we'll test through
// the public API Target_SetCfg which loads target specs.

// Forward declare the public API
extern void Target_SetCfg(const ::std::string& target_name);

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    // Reject empty or overly large inputs
    if (Size == 0 || Size > 100000) {
        return 0;
    }

    try {
        // Create a temporary TOML file with the fuzzer input
        // Target spec parser expects a filename
        char temp_filename[] = "/tmp/mrustc_fuzz_target_XXXXXX.toml";
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
            // Try to load the target spec
            // This will parse the TOML and validate all the fields
            Target_SetCfg(temp_filename);

            // Successfully parsed (unlikely with random input)

        } catch (const std::exception&) {
            // Expected for malformed TOML
        } catch (...) {
            // Catch all other exceptions
        }

        // Clean up
        unlink(temp_filename);

    } catch (...) {
        // Catch any exceptions during file operations
    }

    return 0;
}
