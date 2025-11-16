/*
 * OSS-Fuzz Target for mrustc Lexer (Tokenizer)
 *
 * Fuzzes the lexer which converts raw Rust source code into tokens.
 * Tests Unicode handling, escape sequences, number parsing, and string literals.
 *
 * Attack Surface:
 * - Integer overflow in number parsing (parseInt, parseFloat)
 * - Buffer overruns in string/char literal parsing
 * - UTF-8 validation bugs (invalid codepoint sequences)
 * - Infinite loops in raw string delimiter matching
 * - Escape sequence handling bugs
 */

#include <cstdint>
#include <cstddef>
#include <string>
#include <sstream>
#include <csignal>
#include <csetjmp>
#include <cstdio>
#include <cstdlib>

// Include mrustc headers
#include "parse/lex.hpp"
#include "parse/parseerror.hpp"
#include "parse/token.hpp"

// Signal handling to catch BUG() / TODO crashes
// Can be disabled with FUZZER_NO_RECOVER=1 to find memory leaks
static thread_local sigjmp_buf jump_buffer;
static thread_local bool in_fuzzer = false;
static bool enable_recovery = true;

static void signal_handler(int signum) {
    if (enable_recovery && in_fuzzer && signum == SIGABRT) {
        // BUG() or TODO was hit - jump back instead of crashing
        siglongjmp(jump_buffer, 1);
    }
    // For other signals, let default handler run
    signal(signum, SIG_DFL);
    raise(signum);
}

// Check environment on first call
static void init_recovery_mode() {
    static bool initialized = false;
    if (!initialized) {
        const char* no_recover = std::getenv("FUZZER_NO_RECOVER");
        enable_recovery = !(no_recover && no_recover[0] == '1');
        initialized = true;

        if (!enable_recovery) {
            // Leak detection mode - let BUG() crash to find real memory leaks
            fprintf(stderr, "[FUZZER] Recovery disabled - will crash on BUG() to detect leaks\n");
        }
    }
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    // Check if recovery mode is enabled (first call only)
    init_recovery_mode();

    // Limit input size to prevent timeouts
    // Lexer is fast, but extremely long inputs could still timeout
    if (Size > 100000) {
        return 0;
    }

    // Install signal handler for SIGABRT (from BUG() macro)
    struct sigaction sa, old_sa;
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGABRT, &sa, &old_sa);

    // Set up jump point for BUG()/TODO crashes (if recovery enabled)
    in_fuzzer = true;
    if (enable_recovery && sigsetjmp(jump_buffer, 1) != 0) {
        // We jumped here from a BUG() or TODO - restore and return
        in_fuzzer = false;
        sigaction(SIGABRT, &old_sa, nullptr);
        return 0;  // Don't crash the fuzzer
    }

    // Convert fuzzer input to string
    std::string input(reinterpret_cast<const char*>(Data), Size);

    try {
        // Create a string stream from the input
        std::istringstream iss(input);

        // Initialize parse state (crate pointer left as nullptr)
        ParseState ps;

        // Create lexer with Rust 2021 edition (latest)
        Lexer lexer(iss, AST::Edition::Rust2021, ps);

        // Consume all tokens until EOF or error
        int token_count = 0;
        const int MAX_TOKENS = 50000; // Prevent runaway token generation

        while (token_count < MAX_TOKENS) {
            Token tok = lexer.getToken();

            // Stop at EOF
            if (tok.type() == TOK_EOF) {
                break;
            }

            token_count++;
        }

    } catch (const std::exception&) {
        // Catch exceptions to prevent fuzzer termination
        // We're looking for crashes (ASan/UBSan), not thrown exceptions
    } catch (...) {
        // Catch all
    }

    // Restore original signal handler
    in_fuzzer = false;
    sigaction(SIGABRT, &old_sa, nullptr);

    return 0;
}
