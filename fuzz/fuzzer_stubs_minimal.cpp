/*
 * Minimal stub implementations for mrustc fuzzers
 *
 * This file provides only the absolute minimum stubs needed to link
 * the fuzzers without pulling in the entire compiler.
 */

#include <stdexcept>
#include "target_version.hpp"

// Global target version (needed by various parts)
TargetVersion gTargetVersion = TargetVersion::Rustc1_54;

// Stub for AST expansion (needed by lexer/parser but never called in fuzzing)
#ifdef NEED_AST_STUBS
#include "ast/ast.hpp"
#include "ast/expr.hpp"
#include "parse/tokenstream.hpp"

AST::ExprNodeP Expand_ParseAndExpand_ExprVal(const AST::Crate& crate, const AST::Module& mod, TokenStream& lex) {
    // This should never be called in the fuzzer
    throw std::runtime_error("Expand_ParseAndExpand_ExprVal stub called");
}
#endif

// Stubs for target spec fuzzer (needed when Target_SetCfg is unavailable)
#ifdef NEED_TARGET_STUBS
#include <string>

// If we can't link against the full target.cpp, provide a minimal stub
void Target_SetCfg(const std::string& target_name) {
    // Minimal implementation - just validate input doesn't crash
    // Real implementation is in target.cpp
    throw std::runtime_error("Target_SetCfg requires full target.cpp linking");
}
#endif
