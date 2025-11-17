/*
 * Standalone fuzzer stub for local testing without libFuzzer
 *
 * This provides a simple main() function that reads a file and calls
 * the fuzzer entry point, allowing fuzzer testing without full OSS-Fuzz infrastructure.
 */

#include <cstdint>
#include <cstddef>
#include <fstream>
#include <vector>
#include <iostream>

// Forward declare the fuzzer entry point
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size);

int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <input_file>" << std::endl;
        std::cerr << "       Standalone fuzzer test mode" << std::endl;
        return 1;
    }

    const char* filename = argv[1];
    std::ifstream file(filename, std::ios::binary | std::ios::ate);

    if (!file) {
        std::cerr << "Error: Cannot open file " << filename << std::endl;
        return 1;
    }

    // Read entire file into memory
    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    std::vector<uint8_t> buffer(size);
    if (!file.read(reinterpret_cast<char*>(buffer.data()), size)) {
        std::cerr << "Error: Failed to read file " << filename << std::endl;
        return 1;
    }

    std::cout << "[*] Fuzzing with input file: " << filename << " (" << size << " bytes)" << std::endl;

    // Call the fuzzer
    int result = LLVMFuzzerTestOneInput(buffer.data(), buffer.size());

    std::cout << "[*] Fuzzing completed, result = " << result << std::endl;
    return result;
}
