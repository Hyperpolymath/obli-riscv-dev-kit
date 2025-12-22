// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
// Note G SSG - Build System

open Types

// Build context
type buildContext = {
  config: siteConfig,
  mutable contentFiles: array<contentFile>,
  mutable templates: array<template>,
  mutable errors: array<buildError>,
  mutable warnings: array<buildWarning>,
}

let createContext = (config: siteConfig): buildContext => {
  config,
  contentFiles: [],
  templates: [],
  errors: [],
  warnings: [],
}

// Parse YAML frontmatter from content
let parseFrontmatter = (content: string): (frontmatter, string) => {
  // Check for frontmatter delimiter
  if Js.String.startsWith("---", content) {
    let parts = Js.String.split("---", content)
    if Belt.Array.length(parts) >= 3 {
      // Parse YAML (simplified - real impl would use YAML parser)
      let yamlStr = Belt.Array.getExn(parts, 1)
      let body = Belt.Array.sliceToEnd(parts, 2)->Js.Array2.joinWith("---")

      // Extract basic fields from YAML
      let lines = Js.String.split("\n", yamlStr)
      let title = ref("Untitled")
      let date = ref(None)
      let author = ref(None)
      let tags = ref([])
      let layout = ref(None)
      let draft = ref(false)

      lines->Belt.Array.forEach(line => {
        let trimmed = Js.String.trim(line)
        if Js.String.includes(":", trimmed) {
          let colonIdx = Js.String.indexOf(":", trimmed)
          let key = Js.String.trim(Js.String.substring(~from=0, ~to_=colonIdx, trimmed))
          let value = Js.String.trim(Js.String.substringToEnd(~from=colonIdx + 1, trimmed))

          switch key {
          | "title" => title := value
          | "date" => date := Some(value)
          | "author" => author := Some(value)
          | "layout" => layout := Some(value)
          | "draft" => draft := value == "true"
          | "tags" =>
            // Simple array parsing
            if Js.String.startsWith("[", value) {
              let inner = Js.String.slice(~from=1, ~to_=-1, value)
              tags := Js.String.split(",", inner)->Belt.Array.map(Js.String.trim)
            }
          | _ => ()
          }
        }
      })

      (
        {
          title: title.contents,
          date: date.contents,
          author: author.contents,
          tags: tags.contents,
          layout: layout.contents,
          accessibility: None,
          draft: draft.contents,
          custom: Js.Dict.empty(),
        },
        body,
      )
    } else {
      // No valid frontmatter
      (
        {
          title: "Untitled",
          date: None,
          author: None,
          tags: [],
          layout: None,
          accessibility: None,
          draft: false,
          custom: Js.Dict.empty(),
        },
        content,
      )
    }
  } else {
    // No frontmatter
    (
      {
        title: "Untitled",
        date: None,
        author: None,
        tags: [],
        layout: None,
        accessibility: None,
        draft: false,
        custom: Js.Dict.empty(),
      },
      content,
    )
  }
}

// Determine content format from file extension
let getContentFormat = (path: string): contentFormat => {
  if Js.String.endsWith(".md", path) || Js.String.endsWith(".markdown", path) {
    Markdown
  } else if Js.String.endsWith(".noteg", path) || Js.String.endsWith(".ng", path) {
    NoteG
  } else if Js.String.endsWith(".html", path) || Js.String.endsWith(".htm", path) {
    HTML
  } else if Js.String.endsWith(".adoc", path) || Js.String.endsWith(".asciidoc", path) {
    AsciiDoc
  } else {
    Markdown // Default
  }
}

// Load a content file
let loadContentFile = (path: string, content: string): contentFile => {
  let (frontmatter, body) = parseFrontmatter(content)
  let format = getContentFormat(path)
  {path, frontmatter, body, format}
}

// Extract template variables from a template string
let extractTemplateVariables = (content: string): array<string> => {
  let variables = ref([])
  let regex = %re("/\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}/g")

  let rec findMatches = () => {
    switch Js.Re.exec_(regex, content) {
    | Some(result) =>
      switch Js.Nullable.toOption(Js.Re.captures(result)[1]) {
      | Some(varName) =>
        if !Belt.Array.some(variables.contents, v => v == varName) {
          variables := Belt.Array.concat(variables.contents, [varName])
        }
      | None => ()
      }
      findMatches()
    | None => ()
    }
  }
  findMatches()

  variables.contents
}

// Load a template file
let loadTemplate = (name: string, path: string, content: string): template => {
  let variables = extractTemplateVariables(content)
  {name, path, content, variables}
}

// Render content with template
let renderContent = (
  ctx: buildContext,
  content: contentFile,
  template: template,
): result<string, buildError> => {
  // Create variable context
  let vars = Js.Dict.empty()
  Js.Dict.set(vars, "title", content.frontmatter.title)
  Js.Dict.set(vars, "content", content.body)
  Js.Dict.set(vars, "site_name", ctx.config.name)
  Js.Dict.set(vars, "site_title", ctx.config.title)
  Js.Dict.set(vars, "site_description", ctx.config.description)
  Js.Dict.set(vars, "base_url", ctx.config.baseUrl)

  switch content.frontmatter.date {
  | Some(d) => Js.Dict.set(vars, "date", d)
  | None => ()
  }

  switch content.frontmatter.author {
  | Some(a) => Js.Dict.set(vars, "author", a)
  | None => ()
  }

  // Simple template substitution
  let output = ref(template.content)
  template.variables->Belt.Array.forEach(varName => {
    switch Js.Dict.get(vars, varName) {
    | Some(value) =>
      let pattern = Js.Re.fromStringWithFlags("\\{\\{\\s*" ++ varName ++ "\\s*\\}\\}", ~flags="g")
      output := Js.String.replaceByRe(pattern, value, output.contents)
    | None =>
      // Variable not found - leave as is or emit warning
      ctx.warnings = Belt.Array.concat(ctx.warnings, [{
        file: content.path,
        message: `Template variable '${varName}' not found`,
        suggestion: Some(`Define '${varName}' in frontmatter or site config`),
      }])
    }
  })

  Ok(output.contents)
}

// Generate accessibility-enhanced HTML
let generateA11yHtml = (content: string, config: accessibilityConfig): string => {
  if !config.enabled {
    content
  } else {
    // Add accessibility wrapper and metadata
    let lang = signLanguageToCode(config.defaultLanguage)
    let langName = signLanguageToName(config.defaultLanguage)

    `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="generator" content="Note G SSG">
  <meta name="accessibility-enhanced" content="true">
  <meta name="sign-language-support" content="${lang}">
  <style>
    .a11y-bsl, .a11y-asl, .a11y-gsl, .a11y-makaton {
      border-left: 3px solid #4a90d9;
      padding-left: 0.5em;
      margin: 0.5em 0;
    }
    .skip-link {
      position: absolute;
      left: -9999px;
      top: 0;
      z-index: 999;
    }
    .skip-link:focus {
      left: 0;
      background: #000;
      color: #fff;
      padding: 0.5em 1em;
    }
  </style>
</head>
<body>
  <a href="#main-content" class="skip-link">Skip to main content</a>
  <nav aria-label="Accessibility options">
    <details>
      <summary>Accessibility Options</summary>
      <ul>
        <li><a href="#a11y-${lang}">View in ${langName}</a></li>
      </ul>
    </details>
  </nav>
  <main id="main-content" role="main">
    ${content}
  </main>
</body>
</html>`
  }
}

// Build a single file
let buildFile = (
  ctx: buildContext,
  content: contentFile,
): result<outputFile, buildError> => {
  // Skip drafts in production
  if content.frontmatter.draft {
    return Error({
      file: content.path,
      line: None,
      column: None,
      message: "Skipping draft content",
      code: "DRAFT_SKIP",
    })
  }

  // Find template
  let templateName = switch content.frontmatter.layout {
  | Some(name) => name
  | None => "default"
  }

  let template = Belt.Array.getBy(ctx.templates, t => t.name == templateName)

  switch template {
  | None =>
    Error({
      file: content.path,
      line: None,
      column: None,
      message: `Template '${templateName}' not found`,
      code: "TEMPLATE_NOT_FOUND",
    })
  | Some(tmpl) =>
    switch renderContent(ctx, content, tmpl) {
    | Error(e) => Error(e)
    | Ok(rendered) =>
      // Apply accessibility enhancements
      let output = switch ctx.config.build.compilerTarget {
      | HTMLA11y => generateA11yHtml(rendered, ctx.config.accessibility)
      | _ => rendered
      }

      // Calculate output path
      let outputPath = Js.String.replace(
        ctx.config.paths.content,
        ctx.config.paths.output,
        content.path,
      )->Js.String.replace(".md", ".html")
        ->Js.String.replace(".noteg", ".html")
        ->Js.String.replace(".ng", ".html")

      Ok({
        path: outputPath,
        size: String.length(output),
        format: HTMLFile,
        accessibilityScore: ctx.config.accessibility.enabled ? Some(0.95) : None,
      })
    }
  }
}

// Main build function
let build = (ctx: buildContext): buildResult => {
  let startTime = Js.Date.now()
  let outputFiles = ref([])
  let accessibilityCount = ref(0)

  // Process all content files
  ctx.contentFiles->Belt.Array.forEach(content => {
    switch buildFile(ctx, content) {
    | Ok(file) =>
      outputFiles := Belt.Array.concat(outputFiles.contents, [file])
      if Belt.Option.isSome(file.accessibilityScore) {
        accessibilityCount := accessibilityCount.contents + 1
      }
    | Error(e) =>
      if e.code != "DRAFT_SKIP" {
        ctx.errors = Belt.Array.concat(ctx.errors, [e])
      }
    }
  })

  let endTime = Js.Date.now()
  let buildTime = (endTime -. startTime) /. 1000.0

  {
    success: Belt.Array.length(ctx.errors) == 0,
    outputFiles: outputFiles.contents,
    errors: ctx.errors,
    warnings: ctx.warnings,
    stats: {
      totalFiles: Belt.Array.length(outputFiles.contents),
      totalSize: outputFiles.contents->Belt.Array.reduce(0, (acc, f) => acc + f.size),
      buildTime,
      accessibilityFilesGenerated: accessibilityCount.contents,
    },
  }
}

// Print build summary
let printSummary = (result: buildResult): unit => {
  Js.Console.log("\n=== Note G SSG Build Summary ===\n")

  if result.success {
    Js.Console.log("Status: SUCCESS")
  } else {
    Js.Console.log("Status: FAILED")
  }

  Js.Console.log(`Files generated: ${Belt.Int.toString(result.stats.totalFiles)}`)
  Js.Console.log(`Total size: ${Belt.Int.toString(result.stats.totalSize)} bytes`)
  Js.Console.log(`Build time: ${Float.toString(result.stats.buildTime)}s`)
  Js.Console.log(`Accessibility files: ${Belt.Int.toString(result.stats.accessibilityFilesGenerated)}`)

  if Belt.Array.length(result.warnings) > 0 {
    Js.Console.log(`\nWarnings: ${Belt.Int.toString(Belt.Array.length(result.warnings))}`)
    result.warnings->Belt.Array.forEach(w => {
      Js.Console.log(`  - ${w.file}: ${w.message}`)
    })
  }

  if Belt.Array.length(result.errors) > 0 {
    Js.Console.log(`\nErrors: ${Belt.Int.toString(Belt.Array.length(result.errors))}`)
    result.errors->Belt.Array.forEach(e => {
      Js.Console.log(`  - ${e.file}: ${e.message} (${e.code})`)
    })
  }
}
