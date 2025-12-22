// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
// Note G Language - Core Types

// Token types for lexical analysis
type tokenKind =
  | EOF
  | Newline
  | Whitespace
  | Comment
  // Literals
  | String(string)
  | Number(float)
  | Boolean(bool)
  // Identifiers and keywords
  | Identifier(string)
  | Keyword(keyword)
  // Operators
  | Plus
  | Minus
  | Star
  | Slash
  | Equal
  | NotEqual
  | LessThan
  | GreaterThan
  | LessEqual
  | GreaterEqual
  | And
  | Or
  | Not
  // Delimiters
  | LeftParen
  | RightParen
  | LeftBrace
  | RightBrace
  | LeftBracket
  | RightBracket
  | Comma
  | Colon
  | Semicolon
  | Dot
  | Arrow
  // Template syntax
  | TemplateOpen   // {{
  | TemplateClose  // }}
  | PipeOperator   // |

and keyword =
  | Let
  | Const
  | If
  | Else
  | For
  | While
  | Function
  | Return
  | Import
  | Export
  | Template
  | Component
  | Accessibility
  | BSL  // British Sign Language
  | GSL  // German Sign Language
  | ASL  // American Sign Language
  | Makaton

type position = {
  line: int,
  column: int,
  offset: int,
}

type span = {
  start: position,
  end_: position,
}

type token = {
  kind: tokenKind,
  span: span,
  lexeme: string,
}

// AST Node types
type rec expr =
  | LiteralExpr(literal)
  | IdentifierExpr(string)
  | BinaryExpr({left: expr, op: binaryOp, right: expr})
  | UnaryExpr({op: unaryOp, operand: expr})
  | CallExpr({callee: expr, args: array<expr>})
  | TemplateExpr({parts: array<templatePart>})
  | AccessibilityExpr({kind: accessibilityKind, content: expr})
  | ArrayExpr(array<expr>)
  | ObjectExpr(array<(string, expr)>)

and literal =
  | StringLit(string)
  | NumberLit(float)
  | BoolLit(bool)
  | NullLit

and binaryOp =
  | Add | Sub | Mul | Div
  | Eq | Neq | Lt | Gt | Lte | Gte
  | AndOp | OrOp
  | Pipe

and unaryOp =
  | Negate
  | NotOp

and templatePart =
  | TextPart(string)
  | ExprPart(expr)
  | FilterPart({expr: expr, filter: string})

and accessibilityKind =
  | BSLKind
  | GSLKind
  | ASLKind
  | MakatonKind

type rec stmt =
  | LetStmt({name: string, mutable_: bool, value: expr})
  | ExprStmt(expr)
  | IfStmt({condition: expr, then_: block, else_: option<block>})
  | ForStmt({variable: string, iterable: expr, body: block})
  | WhileStmt({condition: expr, body: block})
  | FunctionStmt({name: string, params: array<string>, body: block})
  | ReturnStmt(option<expr>)
  | ImportStmt({path: string, imports: array<string>})
  | ExportStmt(string)
  | ComponentStmt({name: string, props: array<string>, body: block})
  | AccessibilityStmt({kind: accessibilityKind, metadata: expr})

and block = array<stmt>

type program = {
  statements: array<stmt>,
  accessibility: option<accessibilityMetadata>,
}

and accessibilityMetadata = {
  bsl: option<signLanguageData>,
  gsl: option<signLanguageData>,
  asl: option<signLanguageData>,
  makaton: option<makatonData>,
}

and signLanguageData = {
  videoUrl: option<string>,
  transcript: option<string>,
  glosses: array<string>,
}

and makatonData = {
  symbols: array<string>,
  sequence: option<string>,
}

// Error types
type errorKind =
  | LexerError(string)
  | ParserError(string)
  | TypeError(string)
  | RuntimeError(string)
  | AccessibilityError(string)

type error = {
  kind: errorKind,
  message: string,
  span: option<span>,
}

type result<'a> = Belt.Result.t<'a, error>
