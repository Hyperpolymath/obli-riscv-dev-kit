// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
// Note G Lexer Tests

// Test utilities
let assertEqual = (actual, expected, message) => {
  if actual == expected {
    Js.Console.log(`✓ ${message}`)
    true
  } else {
    Js.Console.log(`✗ ${message}`)
    Js.Console.log(`  Expected: ${expected}`)
    Js.Console.log(`  Actual: ${actual}`)
    false
  }
}

let assertTrue = (condition, message) => {
  if condition {
    Js.Console.log(`✓ ${message}`)
    true
  } else {
    Js.Console.log(`✗ ${message}`)
    false
  }
}

// Token kind to string for comparison
let tokenKindToString = (kind: Types.tokenKind): string => {
  open Types
  switch kind {
  | EOF => "EOF"
  | Newline => "Newline"
  | Whitespace => "Whitespace"
  | Comment => "Comment"
  | String(s) => `String("${s}")`
  | Number(n) => `Number(${Float.toString(n)})`
  | Boolean(b) => `Boolean(${b ? "true" : "false"})`
  | Identifier(s) => `Identifier("${s}")`
  | Keyword(k) =>
    let kw = switch k {
    | Let => "let"
    | Const => "const"
    | If => "if"
    | Else => "else"
    | For => "for"
    | While => "while"
    | Function => "function"
    | Return => "return"
    | Import => "import"
    | Export => "export"
    | Template => "template"
    | Component => "component"
    | Accessibility => "accessibility"
    | BSL => "bsl"
    | GSL => "gsl"
    | ASL => "asl"
    | Makaton => "makaton"
    }
    `Keyword(${kw})`
  | Plus => "Plus"
  | Minus => "Minus"
  | Star => "Star"
  | Slash => "Slash"
  | Equal => "Equal"
  | NotEqual => "NotEqual"
  | LessThan => "LessThan"
  | GreaterThan => "GreaterThan"
  | LessEqual => "LessEqual"
  | GreaterEqual => "GreaterEqual"
  | And => "And"
  | Or => "Or"
  | Not => "Not"
  | LeftParen => "LeftParen"
  | RightParen => "RightParen"
  | LeftBrace => "LeftBrace"
  | RightBrace => "RightBrace"
  | LeftBracket => "LeftBracket"
  | RightBracket => "RightBracket"
  | Comma => "Comma"
  | Colon => "Colon"
  | Semicolon => "Semicolon"
  | Dot => "Dot"
  | Arrow => "Arrow"
  | TemplateOpen => "TemplateOpen"
  | TemplateClose => "TemplateClose"
  | PipeOperator => "PipeOperator"
  }
}

// Test: Empty input
let testEmptyInput = () => {
  Js.Console.log("\n--- Test: Empty Input ---")
  switch Lexer.tokenize("") {
  | Error(_) => assertTrue(false, "Should not error on empty input")
  | Ok(tokens) =>
    assertEqual(Belt.Array.length(tokens), 1, "Should have 1 token (EOF)") &&
    assertTrue(
      switch Belt.Array.get(tokens, 0) {
      | Some({kind: Types.EOF}) => true
      | _ => false
      },
      "Token should be EOF",
    )
  }
}

// Test: Simple identifier
let testSimpleIdentifier = () => {
  Js.Console.log("\n--- Test: Simple Identifier ---")
  switch Lexer.tokenize("hello") {
  | Error(_) => assertTrue(false, "Should not error")
  | Ok(tokens) =>
    assertEqual(Belt.Array.length(tokens), 2, "Should have 2 tokens") &&
    assertTrue(
      switch Belt.Array.get(tokens, 0) {
      | Some({kind: Types.Identifier("hello")}) => true
      | _ => false
      },
      "First token should be Identifier('hello')",
    )
  }
}

// Test: Keywords
let testKeywords = () => {
  Js.Console.log("\n--- Test: Keywords ---")
  let keywords = ["let", "const", "if", "else", "for", "while", "function", "return"]
  let passed = ref(true)

  keywords->Belt.Array.forEach(kw => {
    switch Lexer.tokenize(kw) {
    | Error(_) =>
      Js.Console.log(`✗ Failed to tokenize keyword: ${kw}`)
      passed := false
    | Ok(tokens) =>
      switch Belt.Array.get(tokens, 0) {
      | Some({kind: Types.Keyword(_)}) =>
        Js.Console.log(`✓ Keyword '${kw}' recognized`)
      | _ =>
        Js.Console.log(`✗ '${kw}' not recognized as keyword`)
        passed := false
      }
    }
  })

  passed.contents
}

// Test: Accessibility keywords
let testAccessibilityKeywords = () => {
  Js.Console.log("\n--- Test: Accessibility Keywords ---")
  let a11yKeywords = ["accessibility", "bsl", "gsl", "asl", "makaton"]
  let passed = ref(true)

  a11yKeywords->Belt.Array.forEach(kw => {
    switch Lexer.tokenize(kw) {
    | Error(_) =>
      Js.Console.log(`✗ Failed to tokenize a11y keyword: ${kw}`)
      passed := false
    | Ok(tokens) =>
      switch Belt.Array.get(tokens, 0) {
      | Some({kind: Types.Keyword(_)}) =>
        Js.Console.log(`✓ A11y keyword '${kw}' recognized`)
      | _ =>
        Js.Console.log(`✗ '${kw}' not recognized as a11y keyword`)
        passed := false
      }
    }
  })

  passed.contents
}

// Test: Numbers
let testNumbers = () => {
  Js.Console.log("\n--- Test: Numbers ---")

  let test1 = switch Lexer.tokenize("42") {
  | Ok(tokens) =>
    switch Belt.Array.get(tokens, 0) {
    | Some({kind: Types.Number(42.0)}) =>
      Js.Console.log("✓ Integer 42 parsed correctly")
      true
    | _ =>
      Js.Console.log("✗ Integer 42 not parsed correctly")
      false
    }
  | Error(_) =>
    Js.Console.log("✗ Failed to tokenize 42")
    false
  }

  let test2 = switch Lexer.tokenize("3.14") {
  | Ok(tokens) =>
    switch Belt.Array.get(tokens, 0) {
    | Some({kind: Types.Number(n)}) if n > 3.13 && n < 3.15 =>
      Js.Console.log("✓ Float 3.14 parsed correctly")
      true
    | _ =>
      Js.Console.log("✗ Float 3.14 not parsed correctly")
      false
    }
  | Error(_) =>
    Js.Console.log("✗ Failed to tokenize 3.14")
    false
  }

  test1 && test2
}

// Test: Strings
let testStrings = () => {
  Js.Console.log("\n--- Test: Strings ---")

  let test1 = switch Lexer.tokenize("\"hello world\"") {
  | Ok(tokens) =>
    switch Belt.Array.get(tokens, 0) {
    | Some({kind: Types.String("hello world")}) =>
      Js.Console.log("✓ Double-quoted string parsed correctly")
      true
    | _ =>
      Js.Console.log("✗ Double-quoted string not parsed correctly")
      false
    }
  | Error(_) =>
    Js.Console.log("✗ Failed to tokenize double-quoted string")
    false
  }

  let test2 = switch Lexer.tokenize("'hello'") {
  | Ok(tokens) =>
    switch Belt.Array.get(tokens, 0) {
    | Some({kind: Types.String("hello")}) =>
      Js.Console.log("✓ Single-quoted string parsed correctly")
      true
    | _ =>
      Js.Console.log("✗ Single-quoted string not parsed correctly")
      false
    }
  | Error(_) =>
    Js.Console.log("✗ Failed to tokenize single-quoted string")
    false
  }

  test1 && test2
}

// Test: Template markers
let testTemplateMarkers = () => {
  Js.Console.log("\n--- Test: Template Markers ---")

  switch Lexer.tokenize("{{ name }}") {
  | Ok(tokens) =>
    let hasOpen = Belt.Array.some(tokens, t => t.kind == Types.TemplateOpen)
    let hasClose = Belt.Array.some(tokens, t => t.kind == Types.TemplateClose)
    let hasIdent = Belt.Array.some(tokens, t => {
      switch t.kind {
      | Types.Identifier("name") => true
      | _ => false
      }
    })

    assertTrue(hasOpen, "Should have TemplateOpen token") &&
    assertTrue(hasClose, "Should have TemplateClose token") &&
    assertTrue(hasIdent, "Should have Identifier token")
  | Error(e) =>
    Js.Console.log(`✗ Failed to tokenize template: ${e.message}`)
    false
  }
}

// Test: Operators
let testOperators = () => {
  Js.Console.log("\n--- Test: Operators ---")
  let passed = ref(true)

  let ops = [
    ("+", Types.Plus),
    ("-", Types.Minus),
    ("*", Types.Star),
    ("/", Types.Slash),
    ("|", Types.PipeOperator),
  ]

  ops->Belt.Array.forEach(((opStr, expected)) => {
    switch Lexer.tokenize(opStr) {
    | Ok(tokens) =>
      switch Belt.Array.get(tokens, 0) {
      | Some({kind}) if kind == expected =>
        Js.Console.log(`✓ Operator '${opStr}' recognized`)
      | Some({kind}) =>
        Js.Console.log(`✗ Operator '${opStr}' got wrong kind: ${tokenKindToString(kind)}`)
        passed := false
      | None =>
        Js.Console.log(`✗ No token for operator '${opStr}'`)
        passed := false
      }
    | Error(_) =>
      Js.Console.log(`✗ Failed to tokenize operator '${opStr}'`)
      passed := false
    }
  })

  passed.contents
}

// Test: Full expression
let testFullExpression = () => {
  Js.Console.log("\n--- Test: Full Expression ---")

  let code = "let x = 10 + 20"
  switch Lexer.tokenize(code) {
  | Ok(tokens) =>
    // Should have: let, x, =, 10, +, 20, EOF = 7 tokens
    let len = Belt.Array.length(tokens)
    Js.Console.log(`Token count: ${Belt.Int.toString(len)}`)
    assertTrue(len >= 6, "Should have at least 6 tokens")
  | Error(e) =>
    Js.Console.log(`✗ Failed to tokenize expression: ${e.message}`)
    false
  }
}

// Run all tests
let runAllTests = () => {
  Js.Console.log("=================================")
  Js.Console.log("Note G Lexer Unit Tests")
  Js.Console.log("=================================")

  let results = [
    testEmptyInput(),
    testSimpleIdentifier(),
    testKeywords(),
    testAccessibilityKeywords(),
    testNumbers(),
    testStrings(),
    testTemplateMarkers(),
    testOperators(),
    testFullExpression(),
  ]

  let passed = Belt.Array.reduce(results, 0, (acc, r) => r ? acc + 1 : acc)
  let total = Belt.Array.length(results)

  Js.Console.log("\n=================================")
  Js.Console.log(`Results: ${Belt.Int.toString(passed)}/${Belt.Int.toString(total)} tests passed`)
  Js.Console.log("=================================")

  passed == total
}

// Entry point
let _ = runAllTests()
