/*
 * Comprehensive stubs for fuzz_expr_parser
 *
 * These stubs allow the expression parser to link without pulling in
 * the entire compiler infrastructure. They handle dependencies that
 * are referenced but should never be called during expression parsing.
 */

#include <stdexcept>
#include <string>
#include "span.hpp"
#include "ast/ast.hpp"
#include "ast/path.hpp"
#include "hir/crate_ptr.hpp"

// ============================================================================
// HIR Stubs - Needed by AST::ExternCrate but never called in expr fuzzing
// ============================================================================

namespace HIR {
    // Define minimal Crate class with just what's needed
    class Crate {
    public:
        void post_load_update(const RcString& name);
    };

    // CratePtr implementation (needed by AST::ExternCrate)
    CratePtr::CratePtr(): m_ptr(nullptr) {}
    CratePtr::~CratePtr() {
        // Don't delete m_ptr as we never allocate it in fuzzer
    }

    // Crate method implementation
    void Crate::post_load_update(const RcString& name) {
        // Stub - never called in fuzzer
    }
}

// HIR deserialization entry points
HIR::CratePtr HIR_Deserialise(const std::string& filename) {
    // Should never be called in expression parsing
    throw std::runtime_error("HIR_Deserialise stub called");
}

std::string HIR_Deserialise_JustName(const std::string& filename) {
    return "";
}

// ============================================================================
// CFG Checking Stubs - Needed by item parsing but not expr parsing
// ============================================================================

bool check_cfg(const Span& sp, const AST::Attribute& attr) {
    // Expression parsing shouldn't encounter cfg attributes
    // If it does, just return true (attribute is valid)
    return true;
}

bool check_cfg_attr(const AST::Attribute& attr) {
    return true;
}

// ============================================================================
// Macro Parsing Stubs - Needed when encountering macro_rules! definitions
// ============================================================================

#include "macro_rules/macro_rules.hpp"

MacroRulesPtr Parse_MacroRules(TokenStream& lex) {
    // Expression parser might encounter macro_rules! but won't parse them
    throw std::runtime_error("Parse_MacroRules stub called - expr shouldn't parse macro definitions");
}

MacroRulesPtr Parse_MacroRulesSingleArm(TokenStream& lex) {
    throw std::runtime_error("Parse_MacroRulesSingleArm stub called");
}

// ============================================================================
// Path Helper Stubs - Needed by module parsing
// ============================================================================

namespace helpers {
    class path {
        std::string m_str;
    public:
        path();
        path(const char* p);
        path(const std::string& p);
    };

    // Implementations
    path::path() {}
    path::path(const char* p): m_str(p ? p : "") {}
    path::path(const std::string& p): path(p.c_str()) {}
}

// ============================================================================
// Target Version Stub
// ============================================================================

#include "target_version.hpp"
TargetVersion gTargetVersion = TargetVersion::Rustc1_54;

// ============================================================================
// AST Expansion Stub (already in fuzzer_stubs_minimal.cpp but included for completeness)
// ============================================================================

AST::ExprNodeP Expand_ParseAndExpand_ExprVal(const AST::Crate& crate, const AST::Module& mod, TokenStream& lex) {
    throw std::runtime_error("Expand_ParseAndExpand_ExprVal stub called");
}
