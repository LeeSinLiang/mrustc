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

// Include mrustc headers
#include "parse/lex.hpp"
#include "parse/parseerror.hpp"
#include "parse/token.hpp"
#include "ast/ast.hpp"
#include "ast/crate.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    // Limit input size to prevent timeouts
    // Lexer is fast, but extremely long inputs could still timeout
    if (Size > 100000) {
        return 0;
    }

    // Convert fuzzer input to string
    std::string input(reinterpret_cast<const char*>(Data), Size);

    try {
        // Create a string stream from the input
        std::istringstream iss(input);

        // Initialize parse state
        ParseState ps;
        AST::Crate dummy_crate;
        ps.crate = &dummy_crate;

        // Create lexer with Rust 2021 edition (latest)
        Lexer lexer(iss, AST::Edition::Rust2021, ps);

        // Consume all tokens until EOF or error
        int token_count = 0;
        const int MAX_TOKENS = 50000; // Prevent runaway token generation

        while (token_count < MAX_TOKENS) {
            try {
                Token tok = lexer.getToken();

                // Stop at EOF
                if (tok.type() == TOK_EOF) {
                    break;
                }

                token_count++;

                // Exercise token methods to test edge cases
                // (ASan will catch any memory issues here)
                tok.type();

            } catch (const Lexer::EndOfFile&) {
                // Normal EOF
                break;
            } catch (const ParseError&) {
                // Expected for invalid syntax - this is not a crash
                break;
            }
        }

    } catch (const std::exception&) {
        // Catch exceptions to prevent fuzzer termination
        // We're looking for crashes (ASan/UBSan), not thrown exceptions
    } catch (...) {
        // Catch all
    }

    return 0;
}
