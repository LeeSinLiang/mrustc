// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////

/*
 * Stub implementations for functions needed by AST but not used by the lexer fuzzer.
 * These allow the fuzzer to link without pulling in the entire compiler.
 */

#include <stdexcept>
#include "ast/ast.hpp"
#include "ast/expr.hpp"
#include "parse/tokenstream.hpp"
#include "target_version.hpp"

// Global target version (needed by macro_rules)
TargetVersion gTargetVersion = TargetVersion::Rustc1_54;

// Stub for expand functionality
AST::ExprNodeP Expand_ParseAndExpand_ExprVal(const AST::Crate& crate, const AST::Module& mod, TokenStream& lex) {
    // This should never be called in the lexer fuzzer
    throw std::runtime_error("Expand_ParseAndExpand_ExprVal called in fuzzer stub");
}