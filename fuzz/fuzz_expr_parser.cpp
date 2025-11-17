/*
 * OSS-Fuzz Target for mrustc Expression Parser
 *
 * Fuzzes the Rust expression parser (AST construction from tokens).
 * Tests deeply nested expressions, complex syntax, and recursive descent logic.
 *
 * Attack Surface:
 * - Stack overflow from deeply nested expressions
 * - Infinite recursion in malformed recursive constructs
 * - Memory exhaustion from large expression trees
 * - Parser state bugs in complex lookahead scenarios
 */

#include <cstdint>
#include <cstddef>
#include <string>
#include <sstream>

// Include mrustc headers
#include "ast/ast.hpp"
#include "ast/crate.hpp"
#include "ast/expr.hpp"
#include "parse/lex.hpp"
#include "parse/common.hpp"
#include "parse/parseerror.hpp"

// Forward declare Parse_Expr (from parse/common.hpp)
extern AST::Expr Parse_Expr(TokenStream& lex);

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    // Limit input size to prevent timeouts
    // Parser is slower than lexer due to tree construction
    if (Size > 50000) {
        return 0;
    }

    // Reject tiny inputs
    if (Size < 2) {
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

        // Set up a dummy module for the parse state
        dummy_crate.root_module().m_file_info.path = "fuzz_input";
        ps.module = &dummy_crate.root_module();

        // Create lexer with Rust 2021 edition
        Lexer lexer(iss, AST::Edition::Rust2021, ps);

        try {
            // Try to parse as an expression
            // This exercises most of the parser without needing
            // a full valid Rust program
            AST::Expr expr = Parse_Expr(lexer);

            // Successfully parsed
            // The fuzzer is looking for crashes (ASan/UBSan),
            // not semantic correctness

        } catch (const ParseError&) {
            // Expected for invalid syntax
        } catch (const Lexer::EndOfFile&) {
            // Expected for incomplete input
        }

    } catch (const std::exception&) {
        // Catch other exceptions
    } catch (...) {
        // Catch all
    }

    return 0;
}
