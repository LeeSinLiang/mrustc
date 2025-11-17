/*
 * Comprehensive stub implementations for functions needed by the fuzzer.
 * These allow linking without pulling in the entire compiler.
 * EDITOR NOTES: IT DOES NOT WORK. MANY LINKING ISSUES.
 */

#include <stdexcept>
#include <iostream>
#include "ast/ast.hpp"
#include "ast/expr.hpp"
#include "parse/tokenstream.hpp"
#include "target_version.hpp"
#include "hir/hir.hpp"
#include "hir/path.hpp"
#include "hir/type.hpp"
#include "hir/expr_ptr.hpp"
#include "hir/generic_params.hpp"
#include "mir/mir.hpp"
#include "hir_typeck/monomorph.hpp"
#include "include/synext_decorator.hpp"
#include "include/synext_macro.hpp"

// Global target version
TargetVersion gTargetVersion = TargetVersion::Rustc1_54;

// ========== AST/Parse Stubs ==========

AST::ExprNodeP Expand_ParseAndExpand_ExprVal(const AST::Crate& crate, const AST::Module& mod, TokenStream& lex) {
    throw std::runtime_error("Expand_ParseAndExpand_ExprVal stub called");
}

// ========== HIR Stream Operators ==========

namespace HIR {
    std::ostream& operator<<(std::ostream& os, const SimplePath& p) {
        return os << "<SimplePath>";
    }

    std::ostream& operator<<(std::ostream& os, const Path& p) {
        return os << "<Path>";
    }

    std::ostream& operator<<(std::ostream& os, const PathParams& p) {
        return os << "<PathParams>";
    }

    std::ostream& operator<<(std::ostream& os, const TypeRef& t) {
        return os << "<TypeRef>";
    }

    std::ostream& operator<<(std::ostream& os, const GenericParams::PrintArgs& p) {
        return os << "<GenericParams>";
    }

    // ========== HIR PathParams ==========

    PathParams::PathParams() {}

    // ========== HIR TypeRef ==========

    Ordering TypeRef::ord(const TypeRef& x) const {
        return OrdEqual;
    }

    // ========== HIR GenericRef ==========

    void GenericRef::fmt(std::ostream& os) const {
        os << "<GenericRef>";
    }

    // ========== HIR SimplePath ==========

    bool SimplePath::starts_with(const SimplePath& other, bool) const {
        return false;
    }

    // ========== HIR Crate ==========

    void Crate::post_load_update(const RcString& name) {
        // Stub
    }

    // ========== HIR ExprNode ==========

    // Type info for HIR::ExprNode (needed for RTTI)
    struct ExprNode {};
    struct ExprNode_ConstParam : ExprNode {};
}

// ========== MIR Stream Operators ==========

namespace MIR {
    std::ostream& operator<<(std::ostream& os, const Statement& s) {
        return os << "<MIRStatement>";
    }

    std::ostream& operator<<(std::ostream& os, const Terminator& t) {
        return os << "<MIRTerminator>";
    }
}

// ========== HIR Dump Functions ==========

void HIR_DumpExpr(std::ostream& os, const HIR::ExprPtr& expr) {
    os << "<Expr>";
}

// ========== Monomorphiser Stubs ==========

// Note: Destructor is virtual, implemented in actual Monomorphiser class

HIR::TypeRef Monomorphiser::monomorph_type(const Span& sp, const HIR::TypeRef& ty, bool) const {
    return HIR::TypeRef(ty);  // Use explicit copy constructor
}

HIR::LifetimeRef Monomorphiser::monomorph_lifetime(const Span& sp, const HIR::LifetimeRef& lft) const {
    return lft;
}

HIR::PathParams Monomorphiser::monomorph_path_params(const Span& sp, const HIR::PathParams& params, bool) const {
    return params.clone();
}

HIR::GenericPath Monomorphiser::monomorph_genericpath(const Span& sp, const HIR::GenericPath& path, bool, bool) const {
    return HIR::GenericPath(path.m_path.clone(), path.m_params.clone());
}

// ========== EncodedLiteral Stubs ==========

Ordering EncodedLiteralSlice::ord(const EncodedLiteralSlice& x) const {
    return OrdEqual;
}

bool EncodedLiteralSlice::operator==(const EncodedLiteralSlice& x) const {
    return true;
}

EncodedLiteral EncodedLiteral::clone() const {
    return EncodedLiteral();
}

namespace HIR {
    EncodedLiteralPtr::EncodedLiteralPtr(EncodedLiteral lit) {}
    EncodedLiteralPtr::~EncodedLiteralPtr() {}
}

// ========== ExpandDecorator Stubs ==========

void ExpandDecorator::unexpected(const Span& sp, const AST::Attribute& attr, const char* msg) const {
    throw std::runtime_error(msg);
}

// ========== Synext Registration Stubs ==========

void Register_Synext_Decorator_Static(DecoratorDef* def) {
    // Stub - do nothing
}

void Register_Synext_Macro_Static(MacroDef* def) {
    // Stub - do nothing
}
