// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
// Note G Language Server Protocol Implementation

// LSP types following the specification
module LspTypes = {
  type position = {
    line: int,
    character: int,
  }

  type range = {
    start: position,
    @as("end") end_: position,
  }

  type location = {
    uri: string,
    range: range,
  }

  type diagnostic = {
    range: range,
    severity: int,  // 1=Error, 2=Warning, 3=Info, 4=Hint
    code: option<string>,
    source: string,
    message: string,
  }

  type textDocumentItem = {
    uri: string,
    languageId: string,
    version: int,
    text: string,
  }

  type textDocumentIdentifier = {
    uri: string,
  }

  type versionedTextDocumentIdentifier = {
    uri: string,
    version: int,
  }

  type textDocumentPositionParams = {
    textDocument: textDocumentIdentifier,
    position: position,
  }

  type completionItem = {
    label: string,
    kind: int,  // 1=Text, 2=Method, 3=Function, 6=Variable, 14=Keyword
    detail: option<string>,
    documentation: option<string>,
    insertText: option<string>,
  }

  type hover = {
    contents: string,
    range: option<range>,
  }

  type serverCapabilities = {
    textDocumentSync: int,  // 1=Full, 2=Incremental
    completionProvider: option<{resolveProvider: bool, triggerCharacters: array<string>}>,
    hoverProvider: bool,
    definitionProvider: bool,
    referencesProvider: bool,
    documentSymbolProvider: bool,
    diagnosticProvider: option<{interFileDependencies: bool, workspaceDiagnostics: bool}>,
  }

  type initializeResult = {
    capabilities: serverCapabilities,
    serverInfo: option<{name: string, version: option<string>}>,
  }
}

open LspTypes

// Document store
type documentStore = Belt.Map.String.t<{text: string, version: int}>

type server = {
  mutable documents: documentStore,
  mutable initialized: bool,
}

let make = (): server => {
  documents: Belt.Map.String.empty,
  initialized: false,
}

// Keywords for completion
let keywords = [
  ("let", "Declare a mutable variable"),
  ("const", "Declare an immutable constant"),
  ("if", "Conditional statement"),
  ("else", "Else branch of conditional"),
  ("for", "For loop"),
  ("while", "While loop"),
  ("function", "Declare a function"),
  ("return", "Return from function"),
  ("import", "Import from module"),
  ("export", "Export from module"),
  ("template", "Template definition"),
  ("component", "UI component definition"),
  ("accessibility", "Accessibility metadata"),
  ("bsl", "British Sign Language annotation"),
  ("gsl", "German Sign Language annotation"),
  ("asl", "American Sign Language annotation"),
  ("makaton", "Makaton symbol annotation"),
]

// Built-in functions for completion
let builtins = [
  ("print", "Output a value to console", "print(value)"),
  ("len", "Get length of string or array", "len(value)"),
  ("upper", "Convert string to uppercase", "upper(str)"),
  ("lower", "Convert string to lowercase", "lower(str)"),
  ("escape_html", "Escape HTML special characters", "escape_html(str)"),
  ("date", "Get current date", "date(format)"),
  ("join", "Join array elements with separator", "join(array, separator)"),
]

let getKeywordCompletions = (): array<completionItem> => {
  keywords->Belt.Array.map(((label, doc)) => {
    {
      label,
      kind: 14,  // Keyword
      detail: Some("keyword"),
      documentation: Some(doc),
      insertText: Some(label),
    }
  })
}

let getBuiltinCompletions = (): array<completionItem> => {
  builtins->Belt.Array.map(((label, doc, snippet)) => {
    {
      label,
      kind: 3,  // Function
      detail: Some("builtin function"),
      documentation: Some(doc),
      insertText: Some(snippet),
    }
  })
}

let getAccessibilityCompletions = (): array<completionItem> => {
  [
    {
      label: "accessibility bsl",
      kind: 15,  // Snippet
      detail: Some("BSL accessibility block"),
      documentation: Some("Add British Sign Language accessibility metadata"),
      insertText: Some("accessibility bsl {\n  videoUrl: \"\",\n  transcript: \"\"\n}"),
    },
    {
      label: "accessibility asl",
      kind: 15,
      detail: Some("ASL accessibility block"),
      documentation: Some("Add American Sign Language accessibility metadata"),
      insertText: Some("accessibility asl {\n  videoUrl: \"\",\n  transcript: \"\"\n}"),
    },
    {
      label: "accessibility gsl",
      kind: 15,
      detail: Some("GSL accessibility block"),
      documentation: Some("Add German Sign Language accessibility metadata"),
      insertText: Some("accessibility gsl {\n  videoUrl: \"\",\n  transcript: \"\"\n}"),
    },
    {
      label: "accessibility makaton",
      kind: 15,
      detail: Some("Makaton accessibility block"),
      documentation: Some("Add Makaton symbol accessibility metadata"),
      insertText: Some("accessibility makaton {\n  symbols: [],\n  sequence: \"\"\n}"),
    },
  ]
}

// Handle initialize request
let handleInitialize = (_server: server): initializeResult => {
  {
    capabilities: {
      textDocumentSync: 1,  // Full sync
      completionProvider: Some({
        resolveProvider: false,
        triggerCharacters: [".", "{", "<"],
      }),
      hoverProvider: true,
      definitionProvider: true,
      referencesProvider: true,
      documentSymbolProvider: true,
      diagnosticProvider: Some({
        interFileDependencies: false,
        workspaceDiagnostics: false,
      }),
    },
    serverInfo: Some({
      name: "noteg-lsp",
      version: Some("0.1.0"),
    }),
  }
}

// Handle completion request
let handleCompletion = (_server: server, _params: textDocumentPositionParams): array<completionItem> => {
  Belt.Array.concatMany([
    getKeywordCompletions(),
    getBuiltinCompletions(),
    getAccessibilityCompletions(),
  ])
}

// Convert our error span to LSP range
let spanToRange = (span: Types.span): range => {
  {
    start: {line: span.start.line - 1, character: span.start.column - 1},
    end_: {line: span.end_.line - 1, character: span.end_.column - 1},
  }
}

// Get diagnostics for a document
let getDiagnostics = (text: string): array<diagnostic> => {
  switch Lexer.tokenize(text) {
  | Error(e) =>
    let range = switch e.span {
    | Some(s) => spanToRange(s)
    | None => {start: {line: 0, character: 0}, end_: {line: 0, character: 0}}
    }
    [{
      range,
      severity: 1,  // Error
      code: Some("E001"),
      source: "noteg",
      message: e.message,
    }]
  | Ok(tokens) =>
    switch Parser.parse(tokens) {
    | Error(e) =>
      let range = switch e.span {
      | Some(s) => spanToRange(s)
      | None => {start: {line: 0, character: 0}, end_: {line: 0, character: 0}}
      }
      [{
        range,
        severity: 1,
        code: Some("E002"),
        source: "noteg",
        message: e.message,
      }]
    | Ok(_) => []
    }
  }
}

// Handle hover request
let handleHover = (_server: server, params: textDocumentPositionParams): option<hover> => {
  // Get document text
  // For now, return keyword documentation based on position
  // In a real implementation, we'd parse and find the token at position
  let _ = params
  Some({
    contents: "**Note G Language**\n\nAccessibility-first templating language.",
    range: None,
  })
}

// Update document in store
let updateDocument = (server: server, uri: string, text: string, version: int): unit => {
  server.documents = Belt.Map.String.set(server.documents, uri, {text, version})
}

// Remove document from store
let closeDocument = (server: server, uri: string): unit => {
  server.documents = Belt.Map.String.remove(server.documents, uri)
}

// Get document from store
let getDocument = (server: server, uri: string): option<{text: string, version: int}> => {
  Belt.Map.String.get(server.documents, uri)
}

// Main message handler (simplified JSON-RPC)
type messageHandler = {
  onInitialize: unit => initializeResult,
  onCompletion: textDocumentPositionParams => array<completionItem>,
  onHover: textDocumentPositionParams => option<hover>,
  onDiagnostics: string => array<diagnostic>,
}

let createHandler = (server: server): messageHandler => {
  {
    onInitialize: () => handleInitialize(server),
    onCompletion: params => handleCompletion(server, params),
    onHover: params => handleHover(server, params),
    onDiagnostics: text => getDiagnostics(text),
  }
}

// Entry point for the language server
let start = (): unit => {
  let server = make()
  let _handler = createHandler(server)

  // In a real implementation, this would:
  // 1. Set up JSON-RPC over stdin/stdout
  // 2. Handle incoming messages
  // 3. Send responses

  Js.Console.log("Note G Language Server started")
  Js.Console.log("Capabilities: completion, hover, diagnostics")
}
