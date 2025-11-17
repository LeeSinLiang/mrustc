/*
 * OSS-Fuzz Target for mrustc Lexer (Minimal Version)
 *
 * Simplified fuzzer that tests just the lexer without AST dependencies.
 * This version is faster and easier to build standalone.
 */

#include <cstdint>
#include <cstddef>
#include <string>
#include <sstream>

// Minimal includes
#include "parse/lex.hpp"
#include "parse/token.hpp"

// Minimal ParseState stub
class MinimalParseState : public ParseState {
public:
    MinimalParseState() {
        this->crate = nullptr;
        this->module = nullptr;
    }
};

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    if (Size > 100000) {
        return 0;
    }

    std::string input(reinterpret_cast<const char*>(Data), Size);

    try {
        std::istringstream iss(input);
        MinimalParseState ps;

        Lexer lexer(iss, AST::Edition::Rust2021, ps);

        int token_count = 0;
        const int MAX_TOKENS = 50000;

        while (token_count < MAX_TOKENS) {
            Token tok = lexer.getToken();

            if (tok.type() == TOK_EOF) {
                break;
            }

            token_count++;
        }

    } catch (const std::exception&) {
        // Expected for invalid input
    } catch (...) {
        // Catch all
    }

    return 0;
}
