/*
 * Stub implementations for functions needed by AST but not used by the lexer fuzzer.
 * These allow the fuzzer to link without pulling in the entire compiler.
 */

#include <stdexcept>
#include "ast/ast.hpp"
#include "ast/expr.hpp"
#include "parse/tokenstream.hpp"

// Stub for expand functionality
AST::ExprNodeP Expand_ParseAndExpand_ExprVal(const AST::Crate& crate, const AST::Module& mod, TokenStream& lex) {
    // This should never be called in the lexer fuzzer
    throw std::runtime_error("Expand_ParseAndExpand_ExprVal called in fuzzer stub");
}
