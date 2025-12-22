// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
// Note G Language - Parser

open Types

type parser = {
  tokens: array<token>,
  mutable current: int,
}

let make = (tokens: array<token>): parser => {
  tokens,
  current: 0,
}

let isAtEnd = (p: parser): bool => {
  switch Belt.Array.get(p.tokens, p.current) {
  | Some({kind: EOF}) | None => true
  | _ => false
  }
}

let peek = (p: parser): option<token> => Belt.Array.get(p.tokens, p.current)

let previous = (p: parser): option<token> => Belt.Array.get(p.tokens, p.current - 1)

let advance = (p: parser): option<token> => {
  if !isAtEnd(p) {
    p.current = p.current + 1
  }
  previous(p)
}

let check = (p: parser, kind: tokenKind): bool => {
  switch peek(p) {
  | Some(tok) =>
    switch (tok.kind, kind) {
    | (EOF, EOF) => true
    | (Keyword(k1), Keyword(k2)) => k1 == k2
    | (Identifier(_), Identifier(_)) => true
    | (String(_), String(_)) => true
    | (Number(_), Number(_)) => true
    | (k1, k2) => k1 == k2
    }
  | None => false
  }
}

let match_ = (p: parser, kinds: array<tokenKind>): bool => {
  let matched = Belt.Array.some(kinds, kind => check(p, kind))
  if matched {
    let _ = advance(p)
  }
  matched
}

let consume = (p: parser, kind: tokenKind, message: string): result<token> => {
  if check(p, kind) {
    switch advance(p) {
    | Some(tok) => Ok(tok)
    | None => Error({
        kind: ParserError("Unexpected end of input"),
        message,
        span: None,
      })
    }
  } else {
    let span = switch peek(p) {
    | Some(tok) => Some(tok.span)
    | None => None
    }
    Error({
      kind: ParserError("Unexpected token"),
      message,
      span,
    })
  }
}

// Skip newlines
let skipNewlines = (p: parser): unit => {
  while check(p, Newline) {
    let _ = advance(p)
  }
}

// Expression parsing with precedence climbing
let rec parseExpression = (p: parser): result<expr> => {
  parseOr(p)
}

and parseOr = (p: parser): result<expr> => {
  switch parseAnd(p) {
  | Error(e) => Error(e)
  | Ok(left) =>
    if match_(p, [Or]) {
      switch parseAnd(p) {
      | Error(e) => Error(e)
      | Ok(right) => Ok(BinaryExpr({left, op: OrOp, right}))
      }
    } else {
      Ok(left)
    }
  }
}

and parseAnd = (p: parser): result<expr> => {
  switch parseEquality(p) {
  | Error(e) => Error(e)
  | Ok(left) =>
    if match_(p, [And]) {
      switch parseEquality(p) {
      | Error(e) => Error(e)
      | Ok(right) => Ok(BinaryExpr({left, op: AndOp, right}))
      }
    } else {
      Ok(left)
    }
  }
}

and parseEquality = (p: parser): result<expr> => {
  switch parseComparison(p) {
  | Error(e) => Error(e)
  | Ok(left) =>
    let rec loop = (expr: expr) => {
      if match_(p, [Equal, NotEqual]) {
        let op = switch previous(p) {
        | Some({kind: Equal}) => Eq
        | _ => Neq
        }
        switch parseComparison(p) {
        | Error(e) => Error(e)
        | Ok(right) => loop(BinaryExpr({left: expr, op, right}))
        }
      } else {
        Ok(expr)
      }
    }
    loop(left)
  }
}

and parseComparison = (p: parser): result<expr> => {
  switch parseTerm(p) {
  | Error(e) => Error(e)
  | Ok(left) =>
    let rec loop = (expr: expr) => {
      if match_(p, [LessThan, GreaterThan, LessEqual, GreaterEqual]) {
        let op = switch previous(p) {
        | Some({kind: LessThan}) => Lt
        | Some({kind: GreaterThan}) => Gt
        | Some({kind: LessEqual}) => Lte
        | _ => Gte
        }
        switch parseTerm(p) {
        | Error(e) => Error(e)
        | Ok(right) => loop(BinaryExpr({left: expr, op, right}))
        }
      } else {
        Ok(expr)
      }
    }
    loop(left)
  }
}

and parseTerm = (p: parser): result<expr> => {
  switch parseFactor(p) {
  | Error(e) => Error(e)
  | Ok(left) =>
    let rec loop = (expr: expr) => {
      if match_(p, [Plus, Minus]) {
        let op = switch previous(p) {
        | Some({kind: Plus}) => Add
        | _ => Sub
        }
        switch parseFactor(p) {
        | Error(e) => Error(e)
        | Ok(right) => loop(BinaryExpr({left: expr, op, right}))
        }
      } else {
        Ok(expr)
      }
    }
    loop(left)
  }
}

and parseFactor = (p: parser): result<expr> => {
  switch parseUnary(p) {
  | Error(e) => Error(e)
  | Ok(left) =>
    let rec loop = (expr: expr) => {
      if match_(p, [Star, Slash]) {
        let op = switch previous(p) {
        | Some({kind: Star}) => Mul
        | _ => Div
        }
        switch parseUnary(p) {
        | Error(e) => Error(e)
        | Ok(right) => loop(BinaryExpr({left: expr, op, right}))
        }
      } else {
        Ok(expr)
      }
    }
    loop(left)
  }
}

and parseUnary = (p: parser): result<expr> => {
  if match_(p, [Minus, Not]) {
    let op = switch previous(p) {
    | Some({kind: Minus}) => Negate
    | _ => NotOp
    }
    switch parseUnary(p) {
    | Error(e) => Error(e)
    | Ok(operand) => Ok(UnaryExpr({op, operand}))
    }
  } else {
    parsePipe(p)
  }
}

and parsePipe = (p: parser): result<expr> => {
  switch parseCall(p) {
  | Error(e) => Error(e)
  | Ok(left) =>
    let rec loop = (expr: expr) => {
      if match_(p, [PipeOperator]) {
        switch parseCall(p) {
        | Error(e) => Error(e)
        | Ok(right) => loop(BinaryExpr({left: expr, op: Pipe, right}))
        }
      } else {
        Ok(expr)
      }
    }
    loop(left)
  }
}

and parseCall = (p: parser): result<expr> => {
  switch parsePrimary(p) {
  | Error(e) => Error(e)
  | Ok(callee) =>
    if match_(p, [LeftParen]) {
      let rec parseArgs = (args: array<expr>): result<array<expr>> => {
        if check(p, RightParen) {
          Ok(args)
        } else {
          switch parseExpression(p) {
          | Error(e) => Error(e)
          | Ok(arg) =>
            let newArgs = Belt.Array.concat(args, [arg])
            if match_(p, [Comma]) {
              parseArgs(newArgs)
            } else {
              Ok(newArgs)
            }
          }
        }
      }
      switch parseArgs([]) {
      | Error(e) => Error(e)
      | Ok(args) =>
        switch consume(p, RightParen, "Expected ')' after arguments") {
        | Error(e) => Error(e)
        | Ok(_) => Ok(CallExpr({callee, args}))
        }
      }
    } else {
      Ok(callee)
    }
  }
}

and parsePrimary = (p: parser): result<expr> => {
  skipNewlines(p)

  switch peek(p) {
  | Some({kind: Number(n)}) =>
    let _ = advance(p)
    Ok(LiteralExpr(NumberLit(n)))
  | Some({kind: String(s)}) =>
    let _ = advance(p)
    Ok(LiteralExpr(StringLit(s)))
  | Some({kind: Keyword(Let)}) =>
    // This might be in expression context
    let _ = advance(p)
    Error({
      kind: ParserError("Unexpected 'let' in expression"),
      message: "'let' cannot be used as an expression",
      span: switch previous(p) {
      | Some(t) => Some(t.span)
      | None => None
      },
    })
  | Some({kind: Identifier(name)}) =>
    let _ = advance(p)
    Ok(IdentifierExpr(name))
  | Some({kind: LeftParen}) =>
    let _ = advance(p)
    switch parseExpression(p) {
    | Error(e) => Error(e)
    | Ok(expr) =>
      switch consume(p, RightParen, "Expected ')' after expression") {
      | Error(e) => Error(e)
      | Ok(_) => Ok(expr)
      }
    }
  | Some({kind: LeftBracket}) =>
    let _ = advance(p)
    let rec parseElements = (elements: array<expr>): result<array<expr>> => {
      skipNewlines(p)
      if check(p, RightBracket) {
        Ok(elements)
      } else {
        switch parseExpression(p) {
        | Error(e) => Error(e)
        | Ok(el) =>
          let newElements = Belt.Array.concat(elements, [el])
          skipNewlines(p)
          if match_(p, [Comma]) {
            parseElements(newElements)
          } else {
            Ok(newElements)
          }
        }
      }
    }
    switch parseElements([]) {
    | Error(e) => Error(e)
    | Ok(elements) =>
      skipNewlines(p)
      switch consume(p, RightBracket, "Expected ']' after array") {
      | Error(e) => Error(e)
      | Ok(_) => Ok(ArrayExpr(elements))
      }
    }
  | Some({kind: TemplateOpen}) =>
    parseTemplateExpression(p)
  | Some({kind: Keyword(BSL)}) =>
    let _ = advance(p)
    switch parseExpression(p) {
    | Error(e) => Error(e)
    | Ok(content) => Ok(AccessibilityExpr({kind: BSLKind, content}))
    }
  | Some({kind: Keyword(GSL)}) =>
    let _ = advance(p)
    switch parseExpression(p) {
    | Error(e) => Error(e)
    | Ok(content) => Ok(AccessibilityExpr({kind: GSLKind, content}))
    }
  | Some({kind: Keyword(ASL)}) =>
    let _ = advance(p)
    switch parseExpression(p) {
    | Error(e) => Error(e)
    | Ok(content) => Ok(AccessibilityExpr({kind: ASLKind, content}))
    }
  | Some({kind: Keyword(Makaton)}) =>
    let _ = advance(p)
    switch parseExpression(p) {
    | Error(e) => Error(e)
    | Ok(content) => Ok(AccessibilityExpr({kind: MakatonKind, content}))
    }
  | Some(tok) =>
    Error({
      kind: ParserError("Unexpected token"),
      message: `Unexpected token: ${tok.lexeme}`,
      span: Some(tok.span),
    })
  | None =>
    Error({
      kind: ParserError("Unexpected end of input"),
      message: "Expected an expression",
      span: None,
    })
  }
}

and parseTemplateExpression = (p: parser): result<expr> => {
  let parts = ref([])

  let rec loop = (): result<unit> => {
    switch peek(p) {
    | Some({kind: TemplateOpen}) =>
      let _ = advance(p)
      switch parseExpression(p) {
      | Error(e) => Error(e)
      | Ok(expr) =>
        // Check for filter
        if match_(p, [PipeOperator]) {
          switch peek(p) {
          | Some({kind: Identifier(filter)}) =>
            let _ = advance(p)
            parts := Belt.Array.concat(parts.contents, [FilterPart({expr, filter})])
          | _ =>
            parts := Belt.Array.concat(parts.contents, [ExprPart(expr)])
          }
        } else {
          parts := Belt.Array.concat(parts.contents, [ExprPart(expr)])
        }
        switch consume(p, TemplateClose, "Expected '}}' after template expression") {
        | Error(e) => Error(e)
        | Ok(_) => loop()
        }
      }
    | Some({kind: TemplateClose}) | Some({kind: EOF}) | None =>
      Ok()
    | Some(tok) =>
      // Collect text until next template marker
      parts := Belt.Array.concat(parts.contents, [TextPart(tok.lexeme)])
      let _ = advance(p)
      loop()
    }
  }

  switch loop() {
  | Error(e) => Error(e)
  | Ok() => Ok(TemplateExpr({parts: parts.contents}))
  }
}

// Statement parsing
let rec parseStatement = (p: parser): result<stmt> => {
  skipNewlines(p)

  switch peek(p) {
  | Some({kind: Keyword(Let)}) => parseLetStatement(p, true)
  | Some({kind: Keyword(Const)}) => parseLetStatement(p, false)
  | Some({kind: Keyword(If)}) => parseIfStatement(p)
  | Some({kind: Keyword(For)}) => parseForStatement(p)
  | Some({kind: Keyword(While)}) => parseWhileStatement(p)
  | Some({kind: Keyword(Function)}) => parseFunctionStatement(p)
  | Some({kind: Keyword(Return)}) => parseReturnStatement(p)
  | Some({kind: Keyword(Import)}) => parseImportStatement(p)
  | Some({kind: Keyword(Export)}) => parseExportStatement(p)
  | Some({kind: Keyword(Component)}) => parseComponentStatement(p)
  | Some({kind: Keyword(Accessibility)}) => parseAccessibilityStatement(p)
  | _ =>
    switch parseExpression(p) {
    | Error(e) => Error(e)
    | Ok(expr) => Ok(ExprStmt(expr))
    }
  }
}

and parseLetStatement = (p: parser, mutable_: bool): result<stmt> => {
  let _ = advance(p) // consume let/const
  switch peek(p) {
  | Some({kind: Identifier(name)}) =>
    let _ = advance(p)
    switch consume(p, Equal, "Expected '=' after variable name") {
    | Error(e) => Error(e)
    | Ok(_) =>
      switch parseExpression(p) {
      | Error(e) => Error(e)
      | Ok(value) => Ok(LetStmt({name, mutable_, value}))
      }
    }
  | _ =>
    Error({
      kind: ParserError("Expected identifier"),
      message: "Expected variable name after 'let'/'const'",
      span: switch peek(p) {
      | Some(t) => Some(t.span)
      | None => None
      },
    })
  }
}

and parseIfStatement = (p: parser): result<stmt> => {
  let _ = advance(p) // consume 'if'
  switch parseExpression(p) {
  | Error(e) => Error(e)
  | Ok(condition) =>
    switch parseBlock(p) {
    | Error(e) => Error(e)
    | Ok(then_) =>
      skipNewlines(p)
      let else_ = if match_(p, [Keyword(Else)]) {
        switch parseBlock(p) {
        | Error(_) => None
        | Ok(block) => Some(block)
        }
      } else {
        None
      }
      Ok(IfStmt({condition, then_, else_}))
    }
  }
}

and parseForStatement = (p: parser): result<stmt> => {
  let _ = advance(p) // consume 'for'
  switch peek(p) {
  | Some({kind: Identifier(variable)}) =>
    let _ = advance(p)
    // Expect 'in' keyword (we'll use Identifier for now)
    switch peek(p) {
    | Some({kind: Identifier("in")}) =>
      let _ = advance(p)
      switch parseExpression(p) {
      | Error(e) => Error(e)
      | Ok(iterable) =>
        switch parseBlock(p) {
        | Error(e) => Error(e)
        | Ok(body) => Ok(ForStmt({variable, iterable, body}))
        }
      }
    | _ =>
      Error({
        kind: ParserError("Expected 'in'"),
        message: "Expected 'in' after for loop variable",
        span: switch peek(p) {
        | Some(t) => Some(t.span)
        | None => None
        },
      })
    }
  | _ =>
    Error({
      kind: ParserError("Expected identifier"),
      message: "Expected variable name in for loop",
      span: switch peek(p) {
      | Some(t) => Some(t.span)
      | None => None
      },
    })
  }
}

and parseWhileStatement = (p: parser): result<stmt> => {
  let _ = advance(p) // consume 'while'
  switch parseExpression(p) {
  | Error(e) => Error(e)
  | Ok(condition) =>
    switch parseBlock(p) {
    | Error(e) => Error(e)
    | Ok(body) => Ok(WhileStmt({condition, body}))
    }
  }
}

and parseFunctionStatement = (p: parser): result<stmt> => {
  let _ = advance(p) // consume 'function'
  switch peek(p) {
  | Some({kind: Identifier(name)}) =>
    let _ = advance(p)
    switch consume(p, LeftParen, "Expected '(' after function name") {
    | Error(e) => Error(e)
    | Ok(_) =>
      let rec parseParams = (params: array<string>): result<array<string>> => {
        if check(p, RightParen) {
          Ok(params)
        } else {
          switch peek(p) {
          | Some({kind: Identifier(param)}) =>
            let _ = advance(p)
            let newParams = Belt.Array.concat(params, [param])
            if match_(p, [Comma]) {
              parseParams(newParams)
            } else {
              Ok(newParams)
            }
          | _ =>
            Error({
              kind: ParserError("Expected parameter name"),
              message: "Expected parameter name in function definition",
              span: switch peek(p) {
              | Some(t) => Some(t.span)
              | None => None
              },
            })
          }
        }
      }
      switch parseParams([]) {
      | Error(e) => Error(e)
      | Ok(params) =>
        switch consume(p, RightParen, "Expected ')' after parameters") {
        | Error(e) => Error(e)
        | Ok(_) =>
          switch parseBlock(p) {
          | Error(e) => Error(e)
          | Ok(body) => Ok(FunctionStmt({name, params, body}))
          }
        }
      }
    }
  | _ =>
    Error({
      kind: ParserError("Expected function name"),
      message: "Expected function name after 'function'",
      span: switch peek(p) {
      | Some(t) => Some(t.span)
      | None => None
      },
    })
  }
}

and parseReturnStatement = (p: parser): result<stmt> => {
  let _ = advance(p) // consume 'return'
  if check(p, Newline) || check(p, RightBrace) || check(p, EOF) {
    Ok(ReturnStmt(None))
  } else {
    switch parseExpression(p) {
    | Error(e) => Error(e)
    | Ok(expr) => Ok(ReturnStmt(Some(expr)))
    }
  }
}

and parseImportStatement = (p: parser): result<stmt> => {
  let _ = advance(p) // consume 'import'
  switch consume(p, LeftBrace, "Expected '{' after import") {
  | Error(e) => Error(e)
  | Ok(_) =>
    let rec parseImports = (imports: array<string>): result<array<string>> => {
      if check(p, RightBrace) {
        Ok(imports)
      } else {
        switch peek(p) {
        | Some({kind: Identifier(name)}) =>
          let _ = advance(p)
          let newImports = Belt.Array.concat(imports, [name])
          if match_(p, [Comma]) {
            parseImports(newImports)
          } else {
            Ok(newImports)
          }
        | _ =>
          Error({
            kind: ParserError("Expected import name"),
            message: "Expected import name",
            span: switch peek(p) {
            | Some(t) => Some(t.span)
            | None => None
            },
          })
        }
      }
    }
    switch parseImports([]) {
    | Error(e) => Error(e)
    | Ok(imports) =>
      switch consume(p, RightBrace, "Expected '}' after imports") {
      | Error(e) => Error(e)
      | Ok(_) =>
        // Expect 'from' keyword
        switch peek(p) {
        | Some({kind: Identifier("from")}) =>
          let _ = advance(p)
          switch peek(p) {
          | Some({kind: String(path)}) =>
            let _ = advance(p)
            Ok(ImportStmt({path, imports}))
          | _ =>
            Error({
              kind: ParserError("Expected module path"),
              message: "Expected string module path after 'from'",
              span: switch peek(p) {
              | Some(t) => Some(t.span)
              | None => None
              },
            })
          }
        | _ =>
          Error({
            kind: ParserError("Expected 'from'"),
            message: "Expected 'from' after import list",
            span: switch peek(p) {
            | Some(t) => Some(t.span)
            | None => None
            },
          })
        }
      }
    }
  }
}

and parseExportStatement = (p: parser): result<stmt> => {
  let _ = advance(p) // consume 'export'
  switch peek(p) {
  | Some({kind: Identifier(name)}) =>
    let _ = advance(p)
    Ok(ExportStmt(name))
  | _ =>
    Error({
      kind: ParserError("Expected identifier"),
      message: "Expected name to export",
      span: switch peek(p) {
      | Some(t) => Some(t.span)
      | None => None
      },
    })
  }
}

and parseComponentStatement = (p: parser): result<stmt> => {
  let _ = advance(p) // consume 'component'
  switch peek(p) {
  | Some({kind: Identifier(name)}) =>
    let _ = advance(p)
    switch consume(p, LeftParen, "Expected '(' after component name") {
    | Error(e) => Error(e)
    | Ok(_) =>
      let rec parseProps = (props: array<string>): result<array<string>> => {
        if check(p, RightParen) {
          Ok(props)
        } else {
          switch peek(p) {
          | Some({kind: Identifier(prop)}) =>
            let _ = advance(p)
            let newProps = Belt.Array.concat(props, [prop])
            if match_(p, [Comma]) {
              parseProps(newProps)
            } else {
              Ok(newProps)
            }
          | _ =>
            Error({
              kind: ParserError("Expected prop name"),
              message: "Expected property name in component",
              span: switch peek(p) {
              | Some(t) => Some(t.span)
              | None => None
              },
            })
          }
        }
      }
      switch parseProps([]) {
      | Error(e) => Error(e)
      | Ok(props) =>
        switch consume(p, RightParen, "Expected ')' after props") {
        | Error(e) => Error(e)
        | Ok(_) =>
          switch parseBlock(p) {
          | Error(e) => Error(e)
          | Ok(body) => Ok(ComponentStmt({name, props, body}))
          }
        }
      }
    }
  | _ =>
    Error({
      kind: ParserError("Expected component name"),
      message: "Expected component name after 'component'",
      span: switch peek(p) {
      | Some(t) => Some(t.span)
      | None => None
      },
    })
  }
}

and parseAccessibilityStatement = (p: parser): result<stmt> => {
  let _ = advance(p) // consume 'accessibility'
  switch peek(p) {
  | Some({kind: Keyword(kw)}) =>
    let kind = switch kw {
    | BSL => BSLKind
    | GSL => GSLKind
    | ASL => ASLKind
    | Makaton => MakatonKind
    | _ =>
      return Error({
        kind: ParserError("Expected accessibility type"),
        message: "Expected bsl, gsl, asl, or makaton",
        span: switch peek(p) {
        | Some(t) => Some(t.span)
        | None => None
        },
      })
    }
    let _ = advance(p)
    switch parseExpression(p) {
    | Error(e) => Error(e)
    | Ok(metadata) => Ok(AccessibilityStmt({kind, metadata}))
    }
  | _ =>
    Error({
      kind: ParserError("Expected accessibility type"),
      message: "Expected bsl, gsl, asl, or makaton after 'accessibility'",
      span: switch peek(p) {
      | Some(t) => Some(t.span)
      | None => None
      },
    })
  }
}

and parseBlock = (p: parser): result<block> => {
  skipNewlines(p)
  switch consume(p, LeftBrace, "Expected '{' to start block") {
  | Error(e) => Error(e)
  | Ok(_) =>
    let statements = ref([])
    let error = ref(None)

    let rec loop = () => {
      skipNewlines(p)
      if !check(p, RightBrace) && !isAtEnd(p) && error.contents == None {
        switch parseStatement(p) {
        | Error(e) => error := Some(e)
        | Ok(stmt) =>
          statements := Belt.Array.concat(statements.contents, [stmt])
          loop()
        }
      }
    }
    loop()

    switch error.contents {
    | Some(e) => Error(e)
    | None =>
      skipNewlines(p)
      switch consume(p, RightBrace, "Expected '}' to end block") {
      | Error(e) => Error(e)
      | Ok(_) => Ok(statements.contents)
      }
    }
  }
}

let parse = (tokens: array<token>): result<program> => {
  let p = make(tokens)
  let statements = ref([])
  let error = ref(None)

  let rec loop = () => {
    skipNewlines(p)
    if !isAtEnd(p) && error.contents == None {
      switch parseStatement(p) {
      | Error(e) => error := Some(e)
      | Ok(stmt) =>
        statements := Belt.Array.concat(statements.contents, [stmt])
        loop()
      }
    }
  }
  loop()

  switch error.contents {
  | Some(e) => Error(e)
  | None => Ok({statements: statements.contents, accessibility: None})
  }
}
