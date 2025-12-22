// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
// Note G Language - Compiler (to JavaScript/HTML)

open Types

type compilerTarget =
  | JavaScript
  | HTML
  | HTMLA11y  // HTML with accessibility enhancements

type compiler = {
  target: compilerTarget,
  mutable output: array<string>,
  mutable indent: int,
}

let make = (target: compilerTarget): compiler => {
  target,
  output: [],
  indent: 0,
}

let emit = (c: compiler, code: string): unit => {
  let indentation = Js.String.repeat("  ", c.indent)
  c.output = Belt.Array.concat(c.output, [indentation ++ code])
}

let emitRaw = (c: compiler, code: string): unit => {
  c.output = Belt.Array.concat(c.output, [code])
}

let increaseIndent = (c: compiler): unit => {
  c.indent = c.indent + 1
}

let decreaseIndent = (c: compiler): unit => {
  c.indent = Js.Math.max_int(0, c.indent - 1)
}

let getOutput = (c: compiler): string => {
  Js.Array2.joinWith(c.output, "\n")
}

// Escape strings for JavaScript
let escapeJs = (s: string): string => {
  s
  ->Js.String.replaceByRe(%re("/\\/g"), "\\\\")
  ->Js.String.replaceByRe(%re("/\"/g"), "\\\"")
  ->Js.String.replaceByRe(%re("/\n/g"), "\\n")
  ->Js.String.replaceByRe(%re("/\r/g"), "\\r")
  ->Js.String.replaceByRe(%re("/\t/g"), "\\t")
}

// Escape strings for HTML
let escapeHtml = (s: string): string => {
  s
  ->Js.String.replaceByRe(%re("/&/g"), "&amp;")
  ->Js.String.replaceByRe(%re("/</g"), "&lt;")
  ->Js.String.replaceByRe(%re("/>/g"), "&gt;")
  ->Js.String.replaceByRe(%re("/\"/g"), "&quot;")
  ->Js.String.replaceByRe(%re("/'/g"), "&#39;")
}

let accessibilityKindToClass = (kind: accessibilityKind): string => {
  switch kind {
  | BSLKind => "a11y-bsl"
  | GSLKind => "a11y-gsl"
  | ASLKind => "a11y-asl"
  | MakatonKind => "a11y-makaton"
  }
}

let accessibilityKindToLang = (kind: accessibilityKind): string => {
  switch kind {
  | BSLKind => "bfi"  // British Sign Language (ISO 639-3)
  | GSLKind => "gsg"  // German Sign Language
  | ASLKind => "ase"  // American Sign Language
  | MakatonKind => "en"  // Makaton uses English as base
  }
}

let rec compileExpr = (c: compiler, expr: expr): string => {
  switch expr {
  | LiteralExpr(lit) =>
    switch lit {
    | StringLit(s) =>
      switch c.target {
      | JavaScript => `"${escapeJs(s)}"`
      | HTML | HTMLA11y => escapeHtml(s)
      }
    | NumberLit(n) => Float.toString(n)
    | BoolLit(b) => b ? "true" : "false"
    | NullLit => "null"
    }

  | IdentifierExpr(name) => name

  | BinaryExpr({left, op, right}) =>
    let leftCode = compileExpr(c, left)
    let rightCode = compileExpr(c, right)
    let opStr = switch op {
    | Add => "+"
    | Sub => "-"
    | Mul => "*"
    | Div => "/"
    | Eq => "==="
    | Neq => "!=="
    | Lt => "<"
    | Gt => ">"
    | Lte => "<="
    | Gte => ">="
    | AndOp => "&&"
    | OrOp => "||"
    | Pipe => "|>"  // Will need special handling
    }
    switch op {
    | Pipe => `${rightCode}(${leftCode})`
    | _ => `(${leftCode} ${opStr} ${rightCode})`
    }

  | UnaryExpr({op, operand}) =>
    let operandCode = compileExpr(c, operand)
    let opStr = switch op {
    | Negate => "-"
    | NotOp => "!"
    }
    `${opStr}${operandCode}`

  | CallExpr({callee, args}) =>
    let calleeCode = compileExpr(c, callee)
    let argsCode = args->Belt.Array.map(arg => compileExpr(c, arg))->Js.Array2.joinWith(", ")
    `${calleeCode}(${argsCode})`

  | ArrayExpr(elements) =>
    let elementsCode = elements->Belt.Array.map(el => compileExpr(c, el))->Js.Array2.joinWith(", ")
    `[${elementsCode}]`

  | ObjectExpr(pairs) =>
    let pairsCode = pairs->Belt.Array.map(((k, v)) => {
      `${k}: ${compileExpr(c, v)}`
    })->Js.Array2.joinWith(", ")
    `{${pairsCode}}`

  | TemplateExpr({parts}) =>
    switch c.target {
    | JavaScript =>
      let partsCode = parts->Belt.Array.map(part => {
        switch part {
        | TextPart(text) => `"${escapeJs(text)}"`
        | ExprPart(e) => compileExpr(c, e)
        | FilterPart({expr: e, filter}) => `${filter}(${compileExpr(c, e)})`
        }
      })->Js.Array2.joinWith(" + ")
      partsCode
    | HTML | HTMLA11y =>
      parts->Belt.Array.map(part => {
        switch part {
        | TextPart(text) => escapeHtml(text)
        | ExprPart(e) => `\${${compileExpr(c, e)}}`
        | FilterPart({expr: e, filter}) => `\${${filter}(${compileExpr(c, e)})}`
        }
      })->Js.Array2.joinWith("")
    }

  | AccessibilityExpr({kind, content}) =>
    let contentCode = compileExpr(c, content)
    switch c.target {
    | JavaScript => contentCode
    | HTML => contentCode
    | HTMLA11y =>
      let className = accessibilityKindToClass(kind)
      let lang = accessibilityKindToLang(kind)
      `<span class="${className}" lang="${lang}" role="note">${contentCode}</span>`
    }
  }
}

let rec compileStmt = (c: compiler, stmt: stmt): unit => {
  switch stmt {
  | LetStmt({name, value, mutable_}) =>
    let keyword = mutable_ ? "let" : "const"
    let valueCode = compileExpr(c, value)
    emit(c, `${keyword} ${name} = ${valueCode};`)

  | ExprStmt(expr) =>
    let exprCode = compileExpr(c, expr)
    emit(c, `${exprCode};`)

  | IfStmt({condition, then_, else_}) =>
    let condCode = compileExpr(c, condition)
    emit(c, `if (${condCode}) {`)
    increaseIndent(c)
    compileBlock(c, then_)
    decreaseIndent(c)
    switch else_ {
    | Some(elseBlock) =>
      emit(c, "} else {")
      increaseIndent(c)
      compileBlock(c, elseBlock)
      decreaseIndent(c)
      emit(c, "}")
    | None =>
      emit(c, "}")
    }

  | ForStmt({variable, iterable, body}) =>
    let iterCode = compileExpr(c, iterable)
    emit(c, `for (const ${variable} of ${iterCode}) {`)
    increaseIndent(c)
    compileBlock(c, body)
    decreaseIndent(c)
    emit(c, "}")

  | WhileStmt({condition, body}) =>
    let condCode = compileExpr(c, condition)
    emit(c, `while (${condCode}) {`)
    increaseIndent(c)
    compileBlock(c, body)
    decreaseIndent(c)
    emit(c, "}")

  | FunctionStmt({name, params, body}) =>
    let paramsCode = Js.Array2.joinWith(params, ", ")
    emit(c, `function ${name}(${paramsCode}) {`)
    increaseIndent(c)
    compileBlock(c, body)
    decreaseIndent(c)
    emit(c, "}")

  | ReturnStmt(exprOpt) =>
    switch exprOpt {
    | None => emit(c, "return;")
    | Some(expr) =>
      let exprCode = compileExpr(c, expr)
      emit(c, `return ${exprCode};`)
    }

  | ImportStmt({path, imports}) =>
    let importsCode = Js.Array2.joinWith(imports, ", ")
    emit(c, `import { ${importsCode} } from "${escapeJs(path)}";`)

  | ExportStmt(name) =>
    emit(c, `export { ${name} };`)

  | ComponentStmt({name, props, body}) =>
    let propsCode = Js.Array2.joinWith(props, ", ")
    switch c.target {
    | JavaScript =>
      emit(c, `function ${name}(${propsCode}) {`)
      increaseIndent(c)
      compileBlock(c, body)
      decreaseIndent(c)
      emit(c, "}")
    | HTML | HTMLA11y =>
      emit(c, `<!-- Component: ${name} -->`)
      emit(c, `<template id="component-${Js.String.toLowerCase(name)}">`)
      increaseIndent(c)
      compileBlock(c, body)
      decreaseIndent(c)
      emit(c, "</template>")
    }

  | AccessibilityStmt({kind, metadata}) =>
    let metaCode = compileExpr(c, metadata)
    switch c.target {
    | JavaScript =>
      let kindStr = switch kind {
      | BSLKind => "bsl"
      | GSLKind => "gsl"
      | ASLKind => "asl"
      | MakatonKind => "makaton"
      }
      emit(c, `// Accessibility: ${kindStr}`)
      emit(c, `const __a11y_${kindStr} = ${metaCode};`)
    | HTML =>
      emit(c, `<!-- Accessibility metadata -->`)
    | HTMLA11y =>
      let className = accessibilityKindToClass(kind)
      let lang = accessibilityKindToLang(kind)
      emit(c, `<aside class="${className}-metadata" lang="${lang}" aria-label="Accessibility information">`)
      increaseIndent(c)
      emit(c, metaCode)
      decreaseIndent(c)
      emit(c, "</aside>")
    }
  }
}

and compileBlock = (c: compiler, block: block): unit => {
  block->Belt.Array.forEach(stmt => compileStmt(c, stmt))
}

let compileProgram = (c: compiler, program: program): string => {
  switch c.target {
  | JavaScript =>
    emit(c, "// Generated by Note G Compiler")
    emit(c, "// SPDX-License-Identifier: AGPL-3.0-or-later")
    emit(c, "")
    // Add runtime helpers
    emit(c, "const __noteg_runtime = {")
    increaseIndent(c)
    emit(c, "escape_html: (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'),")
    emit(c, "upper: (s) => s.toUpperCase(),")
    emit(c, "lower: (s) => s.toLowerCase(),")
    emit(c, "join: (arr, sep) => arr.join(sep),")
    emit(c, "len: (x) => x.length,")
    decreaseIndent(c)
    emit(c, "};")
    emit(c, "")

  | HTML =>
    emit(c, "<!DOCTYPE html>")
    emit(c, "<html lang=\"en\">")
    emit(c, "<head>")
    increaseIndent(c)
    emit(c, "<meta charset=\"UTF-8\">")
    emit(c, "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">")
    emit(c, "<meta name=\"generator\" content=\"Note G Compiler\">")
    emit(c, "<title>Note G Document</title>")
    decreaseIndent(c)
    emit(c, "</head>")
    emit(c, "<body>")
    increaseIndent(c)

  | HTMLA11y =>
    emit(c, "<!DOCTYPE html>")
    emit(c, "<html lang=\"en\">")
    emit(c, "<head>")
    increaseIndent(c)
    emit(c, "<meta charset=\"UTF-8\">")
    emit(c, "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">")
    emit(c, "<meta name=\"generator\" content=\"Note G Compiler\">")
    emit(c, "<title>Note G Document (Accessible)</title>")
    emit(c, "<style>")
    increaseIndent(c)
    emit(c, ".a11y-bsl, .a11y-gsl, .a11y-asl, .a11y-makaton {")
    increaseIndent(c)
    emit(c, "border-left: 3px solid #4a90d9;")
    emit(c, "padding-left: 0.5em;")
    emit(c, "margin: 0.5em 0;")
    decreaseIndent(c)
    emit(c, "}")
    emit(c, ".a11y-bsl::before { content: '[BSL] '; font-weight: bold; }")
    emit(c, ".a11y-gsl::before { content: '[DGS] '; font-weight: bold; }")
    emit(c, ".a11y-asl::before { content: '[ASL] '; font-weight: bold; }")
    emit(c, ".a11y-makaton::before { content: '[Makaton] '; font-weight: bold; }")
    decreaseIndent(c)
    emit(c, "</style>")
    decreaseIndent(c)
    emit(c, "</head>")
    emit(c, "<body>")
    increaseIndent(c)
    emit(c, "<a href=\"#main-content\" class=\"skip-link\">Skip to main content</a>")
    emit(c, "<main id=\"main-content\" role=\"main\">")
    increaseIndent(c)
  }

  // Compile program statements
  program.statements->Belt.Array.forEach(stmt => compileStmt(c, stmt))

  // Close HTML structure
  switch c.target {
  | JavaScript => ()
  | HTML =>
    decreaseIndent(c)
    emit(c, "</body>")
    emit(c, "</html>")
  | HTMLA11y =>
    decreaseIndent(c)
    emit(c, "</main>")
    decreaseIndent(c)
    emit(c, "</body>")
    emit(c, "</html>")
  }

  getOutput(c)
}

let compile = (source: string, target: compilerTarget): result<string> => {
  switch Lexer.tokenize(source) {
  | Error(e) => Error(e)
  | Ok(tokens) =>
    switch Parser.parse(tokens) {
    | Error(e) => Error(e)
    | Ok(program) =>
      let c = make(target)
      Ok(compileProgram(c, program))
    }
  }
}

let compileToJs = (source: string): result<string> => compile(source, JavaScript)
let compileToHtml = (source: string): result<string> => compile(source, HTML)
let compileToA11yHtml = (source: string): result<string> => compile(source, HTMLA11y)
