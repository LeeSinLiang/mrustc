# mrustc Fuzzing Target Analysis

This document identifies APIs in mrustc suitable for fuzzing with OSS-Fuzz/libFuzzer, prioritized by vulnerability potential and ease of fuzzing.

## Configuration
- **Edition**: Rust 2021 (latest)
- **Sanitizers**: AddressSanitizer (ASan) + UndefinedBehaviorSanitizer (UBSan)
- **Approach**: Individual component fuzzing (not end-to-end)
- **Corpus**: Retrieved from internet (Rust test suite, existing Rust code)

---

## Priority 1: CRITICAL (Highest Vulnerability Potential)

### 1. HIR Deserializer - Binary Format Parser ⚠️ CRITICAL
**Location**: `src/hir/deserialise.cpp`

**API to Fuzz**:
```cpp
HIR::serialise::Reader reader(const std::string& data);
reader.read_u8();
reader.read_u16c();
reader.read_u64c();
reader.read_count();     // ← Integer overflow risk
reader.read_string();    // ← Buffer overrun risk
reader.read_istring();
```

**What it does**: Parses binary .hir files (serialized High-level IR) from external crates. This is essentially untrusted binary input from dependencies.

**Why CRITICAL**:
- ✅ **Security boundary**: Processes external, potentially malicious crate files
- ✅ **Binary parser**: Direct memory manipulation, pointer arithmetic
- ✅ **Supply chain attack vector**: Malicious crates could exploit this
- ✅ **Integer overflow**: `read_count()` used for allocations
- ✅ **Buffer overrun**: Length-prefixed strings without validation
- ✅ **Type confusion**: Tagged union deserialization

**Vulnerability Types Expected**:
1. **Buffer overruns** - Reading past end of input buffer
2. **Integer overflow** - Size calculations for vectors/maps
3. **Out-of-bounds reads** - Malformed type references
4. **Memory corruption** - Invalid pointer deserialization
5. **Denial of service** - Malicious size values causing huge allocations

**Ease of Fuzzing**: ⭐⭐⭐⭐⭐ (5/5)
- Pure binary input, no setup required
- Low-level primitives easy to test
- Fast execution

**Attack Scenario**: Attacker publishes malicious crate with crafted .hir file → victim adds dependency → mrustc crashes/exploited during compilation.

---

### 2. Lexer (Tokenizer)
**Location**: `src/parse/lex.cpp` (44,361 lines)

**API to Fuzz**:
```cpp
class Lexer : public TokenStream {
    Lexer(std::istringstream& ss, AST::Edition edition, ParseState ps);
    Token realGetToken();
};
```

**What it does**: Converts UTF-8 Rust source code into tokens. First stage of compilation.

**Why HIGH PRIORITY**:
- ✅ **Unicode attack surface**: Complex UTF-8/codepoint handling
- ✅ **Number parsing**: Integer overflow in `parseInt()`, `parseFloat()`
- ✅ **Escape sequences**: `parseEscape()` - classic vulnerability source
- ✅ **Raw string parsing**: Delimiter matching, nested quotes
- ✅ **Fast execution**: Suitable for high-throughput fuzzing
- ✅ **No dependencies**: Pure text → tokens

**Vulnerability Types Expected**:
1. **Integer overflow** - Number literal parsing (line 71: `parseInt()`)
2. **Buffer overruns** - String/char literal parsing
3. **Infinite loops** - Malformed raw string delimiters
4. **Stack overflow** - Deeply nested structures (unlikely but possible)
5. **UTF-8 validation bugs** - Invalid codepoint sequences

**Ease of Fuzzing**: ⭐⭐⭐⭐⭐ (5/5)
- Simple text input
- Very fast execution
- No complex setup

**Specific Code Paths to Hit**:
- `getTokenInt_RawString()` - Raw string parsing (line 63)
- `parseInt()` / `parseFloat()` - Number parsing (lines 71-72)
- `parseEscape()` - Escape sequence handling (line 73)
- `getc_cp()` - UTF-8 decoding (line 87)

---

## Priority 2: HIGH (Complex Parsing, Good Bug Potential)

### 3. Expression Parser
**Location**: `src/parse/expr.cpp` (54,118 lines)

**API to Fuzz**:
```cpp
AST::Expr Parse_Expr(TokenStream& lex);
AST::ExprNodeP Parse_Expr0(TokenStream& lex);
AST::ExprNodeP Parse_ExprBlockNode(TokenStream& lex, ...);
```

**What it does**: Parses Rust expressions into AST nodes. Handles complex nested syntax.

**Why HIGH PRIORITY**:
- ✅ **Recursive descent parser**: Stack overflow potential
- ✅ **54K lines**: Very complex logic
- ✅ **Deep nesting**: Expressions can nest arbitrarily deep
- ✅ **Complex grammar**: Many edge cases and ambiguities
- ✅ **State management**: Complex lookahead and backtracking

**Vulnerability Types Expected**:
1. **Stack overflow** - Deeply nested expressions: `(((((...)))))`
2. **Infinite recursion** - Malformed recursive constructs
3. **Memory exhaustion** - Large expression trees
4. **Parser confusion** - Ambiguous syntax edge cases

**Ease of Fuzzing**: ⭐⭐⭐⭐ (4/5)
- Needs lexer setup (TokenStream)
- Slower than lexer but still reasonable
- May need some valid token sequences to reach deep code

**Example Attack Inputs**:
- Deeply nested parentheses/blocks
- Complex macro invocations within expressions
- Ambiguous operator precedence cases

---

### 4. Module/Item Parser (Parse_Crate)
**Location**: `src/parse/root.cpp` (82,599 lines!)

**API to Fuzz**:
```cpp
AST::Crate Parse_Crate(std::string mainfile, AST::Edition edition);
void Parse_ModRoot(TokenStream& lex, AST::Module& mod, ...);
```

**What it does**: Parses top-level Rust code (modules, items, declarations).

**Why HIGH PRIORITY**:
- ✅ **82K lines**: Extremely complex
- ✅ **Module recursion**: `mod` statements can nest
- ✅ **Attribute parsing**: Complex metadata syntax
- ✅ **Macro invocations**: Can trigger expansion

**Vulnerability Types Expected**:
1. **Stack overflow** - Deeply nested modules
2. **Parser state bugs** - Complex attribute combinations
3. **Memory issues** - Large item lists

**Ease of Fuzzing**: ⭐⭐⭐ (3/5)
- Needs more setup than expression parser
- Slower execution
- May need semi-valid Rust structure

---

## Priority 3: MEDIUM (Moderate Complexity, Specific Attack Surface)

### 5. Target Specification Parser (TOML)
**Location**: `src/trans/target.cpp:87` (`load_spec_from_file`)

**API to Fuzz**:
```cpp
TargetSpec load_spec_from_file(const std::string& filename);
```

**What it does**: Parses TOML files defining custom compilation targets (architecture, ABI, codegen options).

**Why MEDIUM PRIORITY**:
- ✅ **External format**: TOML parsing
- ✅ **Config injection**: Could affect code generation
- ✅ **Type conversions**: String → enum, integer parsing
- ✅ **100K lines**: Large file suggests complexity

**Vulnerability Types Expected**:
1. **TOML parser bugs** - Malformed structure
2. **Type confusion** - Invalid arch/ABI combinations
3. **Integer overflow** - Alignment values
4. **Path injection** - In codegen options (if unsanitized)

**Ease of Fuzzing**: ⭐⭐⭐⭐ (4/5)
- Simple file input
- Moderate speed
- TOML library may already be well-tested

**Note**: The TOML parsing is done by external library (`toml.h` from tools/common), so bugs may be in integration logic rather than parser itself.

---

### 6. Macro Rules Evaluator
**Location**: `src/macro_rules/eval.cpp`, `src/macro_rules/parse.cpp`

**API to Fuzz**:
```cpp
// MacroRules pattern matching and expansion
// (Need to check actual public API)
```

**What it does**: Implements `macro_rules!` declarative macro system. Pattern matching and token expansion.

**Why MEDIUM PRIORITY**:
- ✅ **Turing-complete**: Can loop and recurse
- ✅ **Pattern complexity**: Repetitions, captures, nested patterns
- ✅ **Expansion bombs**: Exponential growth potential
- ✅ **Known hard problem**: Macro systems historically buggy

**Vulnerability Types Expected**:
1. **Infinite recursion** - Self-referential macros
2. **Exponential expansion** - Macro bombs (`$($($x)+)+`)
3. **Stack overflow** - Deep pattern nesting
4. **Memory exhaustion** - Runaway expansion

**Ease of Fuzzing**: ⭐⭐ (2/5)
- Complex setup (need valid macro definition structure)
- May be slow due to expansion
- Harder to generate valid inputs

---

### 7. Format String Parser
**Location**: `src/expand/format_args.cpp` (37,994 lines)

**API to Fuzz**:
```cpp
// Parse format!() macro strings
// (Need to find exact entry point)
```

**What it does**: Parses format string DSL for `format!()`, `println!()`, etc.

**Why MEDIUM PRIORITY**:
- ✅ **37K lines**: Significant complexity
- ✅ **DSL parsing**: Custom syntax (alignment, precision, types)
- ✅ **User-facing**: Direct user input
- ✅ **Fast**: No heavy semantic analysis

**Vulnerability Types Expected**:
1. **Format string parsing bugs** - Invalid specifiers
2. **Stack overflow** - Nested braces
3. **Integer overflow** - Precision/width values

**Ease of Fuzzing**: ⭐⭐⭐ (3/5)
- Need macro invocation context
- Format string syntax is limited
- Moderate speed

---

## Priority 4: LOW (Less Critical but Worth Considering)

### 8. Type Parser
**Location**: `src/parse/types.cpp`

**What it does**: Parses type annotations, generic parameters, trait bounds.

**Why LOWER PRIORITY**:
- Complex but less likely to have critical bugs
- Slower to reach from raw input
- Still worth fuzzing for completeness

---

### 9. Pattern Parser
**Location**: `src/parse/pattern.cpp`

**What it does**: Parses pattern matching syntax.

**Why LOWER PRIORITY**:
- Moderate complexity
- Good for finding edge cases but not critical vulnerabilities

---

## Recommended Fuzzing Strategy

### Phase 1: Quick Wins (Start Here)
1. **HIR Deserializer** - Most critical, easiest to fuzz
2. **Lexer** - High bug potential, very fast fuzzing

### Phase 2: Parser Deep Dive
3. **Expression Parser** - Complex, good bug potential
4. **Module Parser** - Very complex, slower but valuable

### Phase 3: Specialized Components
5. **Target Spec Parser** - Config injection risks
6. **Macro Evaluator** - DoS potential

### Phase 4: Completeness
7. **Format Parser** - User-facing attack surface
8. **Type/Pattern Parsers** - Edge case hunting

---

## Expected Bug Classes by Target

| Target | Memory Safety | Integer Overflow | Stack Overflow | DoS | Type Confusion |
|--------|---------------|------------------|----------------|-----|----------------|
| HIR Deserializer | ✅✅✅ | ✅✅✅ | ❌ | ✅✅ | ✅✅✅ |
| Lexer | ✅✅ | ✅✅✅ | ❌ | ✅ | ❌ |
| Expr Parser | ✅ | ✅ | ✅✅✅ | ✅✅ | ❌ |
| Module Parser | ✅ | ✅ | ✅✅ | ✅✅ | ❌ |
| Target Parser | ✅ | ✅✅ | ❌ | ✅ | ✅ |
| Macro Evaluator | ✅ | ✅ | ✅✅✅ | ✅✅✅ | ❌ |
| Format Parser | ✅ | ✅✅ | ✅ | ✅ | ❌ |

✅✅✅ = Very likely, ✅✅ = Likely, ✅ = Possible, ❌ = Unlikely

---

## Technical Implementation Notes

### For HIR Deserializer:
- **Entry point**: `HIR::serialise::Reader` constructor + read methods
- **Input**: Raw binary data (can be completely random)
- **Setup**: Minimal - just construct Reader and call read methods
- **Speed**: Very fast (microseconds per input)

### For Lexer:
- **Entry point**: `Lexer(istringstream, edition, ParseState)`
- **Input**: UTF-8 text (any string)
- **Setup**: Need minimal ParseState with dummy crate
- **Speed**: Very fast (milliseconds per input)
- **Corpus**: Rust source files from internet

### For Parsers:
- **Entry point**: `Parse_Expr()`, `Parse_Crate()`, etc.
- **Input**: UTF-8 text (needs some token structure)
- **Setup**: Lexer + ParseState + dummy crate
- **Speed**: Moderate (tens of milliseconds)
- **Corpus**: Valid Rust code, then mutate

### For Target Parser:
- **Entry point**: `load_spec_from_file(filename)`
- **Input**: TOML file content
- **Setup**: Write to temp file (fuzzer limitation)
- **Speed**: Fast
- **Corpus**: Existing .toml target specs from rustc

---

## Corpus Sources

### For All Targets:
1. **rustc test suite**: https://github.com/rust-lang/rust/tree/master/tests
2. **Rust by Example**: Simple, well-formed Rust code
3. **crates.io top crates**: Real-world Rust code

### For HIR Deserializer:
- Build mrustc against rustc 1.74.0, collect generated .hir files
- These are valid binary inputs to start mutation from

### For Lexer/Parser:
- All .rs files from rustc test suite
- Focus on edge case tests: `tests/ui/parser/`

### For Target Parser:
- Extract .toml specs from rustc source: `compiler/rustc_target/spec/`

---

## Questions to Finalize Implementation

1. **Do you want all 7 fuzzers, or prioritize top 3-4?**
2. **Any specific vulnerability classes you're most concerned about?**
   - Memory corruption (ASan will catch)
   - DoS (infinite loops, exponential complexity)
   - Logic bugs (incorrect parsing)
3. **Do you have a preference for fuzzer execution time?**
   - Fast (lexer, HIR) - seconds per run
   - Thorough (parsers, macro) - minutes per run
4. **Should fuzzers share code/utilities or be standalone?**

Let me know what you think of this analysis and which targets you want to prioritize!
