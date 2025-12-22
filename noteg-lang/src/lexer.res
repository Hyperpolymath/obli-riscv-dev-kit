// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
// Note G Language - Lexer

open Types

type lexer = {
  source: string,
  mutable pos: int,
  mutable line: int,
  mutable column: int,
}

let make = (source: string): lexer => {
  source,
  pos: 0,
  line: 1,
  column: 1,
}

let isAtEnd = (l: lexer): bool => l.pos >= String.length(l.source)

let peek = (l: lexer): option<string> => {
  if isAtEnd(l) {
    None
  } else {
    Some(String.sub(l.source, l.pos, 1))
  }
}

let peekNext = (l: lexer): option<string> => {
  if l.pos + 1 >= String.length(l.source) {
    None
  } else {
    Some(String.sub(l.source, l.pos + 1, 1))
  }
}

let advance = (l: lexer): option<string> => {
  switch peek(l) {
  | None => None
  | Some(ch) =>
    l.pos = l.pos + 1
    if ch == "\n" {
      l.line = l.line + 1
      l.column = 1
    } else {
      l.column = l.column + 1
    }
    Some(ch)
  }
}

let currentPosition = (l: lexer): position => {
  line: l.line,
  column: l.column,
  offset: l.pos,
}

let isDigit = (ch: string): bool => {
  ch >= "0" && ch <= "9"
}

let isAlpha = (ch: string): bool => {
  (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch == "_"
}

let isAlphaNumeric = (ch: string): bool => isAlpha(ch) || isDigit(ch)

let keywords: Belt.Map.String.t<keyword> = Belt.Map.String.fromArray([
  ("let", Let),
  ("const", Const),
  ("if", If),
  ("else", Else),
  ("for", For),
  ("while", While),
  ("function", Function),
  ("return", Return),
  ("import", Import),
  ("export", Export),
  ("template", Template),
  ("component", Component),
  ("accessibility", Accessibility),
  ("bsl", BSL),
  ("gsl", GSL),
  ("asl", ASL),
  ("makaton", Makaton),
])

let scanString = (l: lexer, quote: string): result<token> => {
  let startPos = currentPosition(l)
  let _ = advance(l) // consume opening quote
  let buffer = ref("")

  let rec loop = () => {
    switch peek(l) {
    | None => Error({
        kind: LexerError("Unterminated string"),
        message: "String literal was not closed",
        span: Some({start: startPos, end_: currentPosition(l)}),
      })
    | Some(ch) if ch == quote =>
      let _ = advance(l) // consume closing quote
      let endPos = currentPosition(l)
      Ok({
        kind: String(buffer.contents),
        span: {start: startPos, end_: endPos},
        lexeme: quote ++ buffer.contents ++ quote,
      })
    | Some("\\") =>
      let _ = advance(l)
      switch advance(l) {
      | Some("n") => buffer := buffer.contents ++ "\n"
      | Some("t") => buffer := buffer.contents ++ "\t"
      | Some("r") => buffer := buffer.contents ++ "\r"
      | Some(ch) => buffer := buffer.contents ++ ch
      | None => ()
      }
      loop()
    | Some(ch) =>
      buffer := buffer.contents ++ ch
      let _ = advance(l)
      loop()
    }
  }
  loop()
}

let scanNumber = (l: lexer): token => {
  let startPos = currentPosition(l)
  let buffer = ref("")

  let rec scanDigits = () => {
    switch peek(l) {
    | Some(ch) if isDigit(ch) =>
      buffer := buffer.contents ++ ch
      let _ = advance(l)
      scanDigits()
    | _ => ()
    }
  }

  scanDigits()

  // Check for decimal
  switch (peek(l), peekNext(l)) {
  | (Some("."), Some(next)) if isDigit(next) =>
    buffer := buffer.contents ++ "."
    let _ = advance(l)
    scanDigits()
  | _ => ()
  }

  let endPos = currentPosition(l)
  let value = Float.fromString(buffer.contents)->Belt.Option.getWithDefault(0.0)

  {
    kind: Number(value),
    span: {start: startPos, end_: endPos},
    lexeme: buffer.contents,
  }
}

let scanIdentifier = (l: lexer): token => {
  let startPos = currentPosition(l)
  let buffer = ref("")

  let rec loop = () => {
    switch peek(l) {
    | Some(ch) if isAlphaNumeric(ch) =>
      buffer := buffer.contents ++ ch
      let _ = advance(l)
      loop()
    | _ => ()
    }
  }
  loop()

  let endPos = currentPosition(l)
  let lexeme = buffer.contents

  let kind = switch Belt.Map.String.get(keywords, lexeme) {
  | Some(kw) => Keyword(kw)
  | None => Identifier(lexeme)
  }

  {kind, span: {start: startPos, end_: endPos}, lexeme}
}

let scanTemplateMarker = (l: lexer): option<token> => {
  let startPos = currentPosition(l)
  switch (peek(l), peekNext(l)) {
  | (Some("{"), Some("{")) =>
    let _ = advance(l)
    let _ = advance(l)
    Some({
      kind: TemplateOpen,
      span: {start: startPos, end_: currentPosition(l)},
      lexeme: "{{",
    })
  | (Some("}"), Some("}")) =>
    let _ = advance(l)
    let _ = advance(l)
    Some({
      kind: TemplateClose,
      span: {start: startPos, end_: currentPosition(l)},
      lexeme: "}}",
    })
  | _ => None
  }
}

let scanToken = (l: lexer): result<token> => {
  // Skip whitespace (but not newlines)
  let rec skipWhitespace = () => {
    switch peek(l) {
    | Some(" ") | Some("\t") | Some("\r") =>
      let _ = advance(l)
      skipWhitespace()
    | _ => ()
    }
  }
  skipWhitespace()

  if isAtEnd(l) {
    let pos = currentPosition(l)
    Ok({kind: EOF, span: {start: pos, end_: pos}, lexeme: ""})
  } else {
    // Check for template markers first
    switch scanTemplateMarker(l) {
    | Some(tok) => Ok(tok)
    | None =>
      let startPos = currentPosition(l)
      switch peek(l) {
      | Some("\n") =>
        let _ = advance(l)
        Ok({kind: Newline, span: {start: startPos, end_: currentPosition(l)}, lexeme: "\n"})
      | Some("\"") => scanString(l, "\"")
      | Some("'") => scanString(l, "'")
      | Some(ch) if isDigit(ch) => Ok(scanNumber(l))
      | Some(ch) if isAlpha(ch) => Ok(scanIdentifier(l))
      | Some("+") =>
        let _ = advance(l)
        Ok({kind: Plus, span: {start: startPos, end_: currentPosition(l)}, lexeme: "+"})
      | Some("-") =>
        let _ = advance(l)
        Ok({kind: Minus, span: {start: startPos, end_: currentPosition(l)}, lexeme: "-"})
      | Some("*") =>
        let _ = advance(l)
        Ok({kind: Star, span: {start: startPos, end_: currentPosition(l)}, lexeme: "*"})
      | Some("/") =>
        let _ = advance(l)
        Ok({kind: Slash, span: {start: startPos, end_: currentPosition(l)}, lexeme: "/"})
      | Some("=") =>
        let _ = advance(l)
        switch peek(l) {
        | Some("=") =>
          let _ = advance(l)
          Ok({kind: Equal, span: {start: startPos, end_: currentPosition(l)}, lexeme: "=="})
        | _ =>
          Ok({kind: Equal, span: {start: startPos, end_: currentPosition(l)}, lexeme: "="})
        }
      | Some("!") =>
        let _ = advance(l)
        switch peek(l) {
        | Some("=") =>
          let _ = advance(l)
          Ok({kind: NotEqual, span: {start: startPos, end_: currentPosition(l)}, lexeme: "!="})
        | _ =>
          Ok({kind: Not, span: {start: startPos, end_: currentPosition(l)}, lexeme: "!"})
        }
      | Some("<") =>
        let _ = advance(l)
        switch peek(l) {
        | Some("=") =>
          let _ = advance(l)
          Ok({kind: LessEqual, span: {start: startPos, end_: currentPosition(l)}, lexeme: "<="})
        | _ =>
          Ok({kind: LessThan, span: {start: startPos, end_: currentPosition(l)}, lexeme: "<"})
        }
      | Some(">") =>
        let _ = advance(l)
        switch peek(l) {
        | Some("=") =>
          let _ = advance(l)
          Ok({kind: GreaterEqual, span: {start: startPos, end_: currentPosition(l)}, lexeme: ">="})
        | _ =>
          Ok({kind: GreaterThan, span: {start: startPos, end_: currentPosition(l)}, lexeme: ">"})
        }
      | Some("|") =>
        let _ = advance(l)
        Ok({kind: PipeOperator, span: {start: startPos, end_: currentPosition(l)}, lexeme: "|"})
      | Some("(") =>
        let _ = advance(l)
        Ok({kind: LeftParen, span: {start: startPos, end_: currentPosition(l)}, lexeme: "("})
      | Some(")") =>
        let _ = advance(l)
        Ok({kind: RightParen, span: {start: startPos, end_: currentPosition(l)}, lexeme: ")"})
      | Some("{") =>
        let _ = advance(l)
        Ok({kind: LeftBrace, span: {start: startPos, end_: currentPosition(l)}, lexeme: "{"})
      | Some("}") =>
        let _ = advance(l)
        Ok({kind: RightBrace, span: {start: startPos, end_: currentPosition(l)}, lexeme: "}"})
      | Some("[") =>
        let _ = advance(l)
        Ok({kind: LeftBracket, span: {start: startPos, end_: currentPosition(l)}, lexeme: "["})
      | Some("]") =>
        let _ = advance(l)
        Ok({kind: RightBracket, span: {start: startPos, end_: currentPosition(l)}, lexeme: "]"})
      | Some(",") =>
        let _ = advance(l)
        Ok({kind: Comma, span: {start: startPos, end_: currentPosition(l)}, lexeme: ","})
      | Some(":") =>
        let _ = advance(l)
        Ok({kind: Colon, span: {start: startPos, end_: currentPosition(l)}, lexeme: ":"})
      | Some(";") =>
        let _ = advance(l)
        Ok({kind: Semicolon, span: {start: startPos, end_: currentPosition(l)}, lexeme: ";"})
      | Some(".") =>
        let _ = advance(l)
        Ok({kind: Dot, span: {start: startPos, end_: currentPosition(l)}, lexeme: "."})
      | Some(ch) =>
        let _ = advance(l)
        Error({
          kind: LexerError(`Unexpected character: ${ch}`),
          message: `Unknown character '${ch}' encountered`,
          span: Some({start: startPos, end_: currentPosition(l)}),
        })
      | None =>
        let pos = currentPosition(l)
        Ok({kind: EOF, span: {start: pos, end_: pos}, lexeme: ""})
      }
    }
  }
}

let tokenize = (source: string): result<array<token>> => {
  let l = make(source)
  let tokens = ref([])
  let error = ref(None)

  let rec loop = () => {
    switch scanToken(l) {
    | Error(e) => error := Some(e)
    | Ok(tok) =>
      tokens := Belt.Array.concat(tokens.contents, [tok])
      if tok.kind != EOF {
        loop()
      }
    }
  }
  loop()

  switch error.contents {
  | Some(e) => Error(e)
  | None => Ok(tokens.contents)
  }
}
