// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
// Note G SSG - Type Definitions

// Site configuration schema
type siteConfig = {
  name: string,
  title: string,
  description: string,
  baseUrl: string,
  language: string,
  author: option<authorInfo>,
  accessibility: accessibilityConfig,
  build: buildConfig,
  paths: pathConfig,
}

and authorInfo = {
  name: string,
  email: option<string>,
  url: option<string>,
  orcid: option<string>,
}

and accessibilityConfig = {
  enabled: bool,
  defaultLanguage: signLanguage,
  supportedLanguages: array<signLanguage>,
  makatonEnabled: bool,
  generateAltFormats: bool,
}

and signLanguage =
  | BSL  // British Sign Language
  | ASL  // American Sign Language
  | GSL  // German Sign Language (DGS)
  | Auslan  // Australian Sign Language
  | LSF  // French Sign Language
  | JSL  // Japanese Sign Language

and buildConfig = {
  outputDir: string,
  minify: bool,
  sourceMaps: bool,
  compilerTarget: compilerTarget,
}

and compilerTarget =
  | HTML
  | HTMLA11y
  | JavaScript
  | JSON

and pathConfig = {
  content: string,
  templates: string,
  static: string,
  output: string,
}

// Content types
type contentFile = {
  path: string,
  frontmatter: frontmatter,
  body: string,
  format: contentFormat,
}

and frontmatter = {
  title: string,
  date: option<string>,
  author: option<string>,
  tags: array<string>,
  layout: option<string>,
  accessibility: option<contentAccessibility>,
  draft: bool,
  custom: Js.Dict.t<Js.Json.t>,
}

and contentFormat =
  | Markdown
  | NoteG
  | HTML
  | AsciiDoc

and contentAccessibility = {
  bsl: option<signLanguageContent>,
  asl: option<signLanguageContent>,
  gsl: option<signLanguageContent>,
  makaton: option<makatonContent>,
}

and signLanguageContent = {
  videoUrl: option<string>,
  transcript: option<string>,
  glosses: array<string>,
  interpreter: option<string>,
}

and makatonContent = {
  symbols: array<makatonSymbol>,
  sequence: option<string>,
  audioUrl: option<string>,
}

and makatonSymbol = {
  id: string,
  meaning: string,
  imageUrl: option<string>,
}

// Template types
type template = {
  name: string,
  path: string,
  content: string,
  variables: array<string>,
}

// Build result types
type buildResult = {
  success: bool,
  outputFiles: array<outputFile>,
  errors: array<buildError>,
  warnings: array<buildWarning>,
  stats: buildStats,
}

and outputFile = {
  path: string,
  size: int,
  format: outputFormat,
  accessibilityScore: option<float>,
}

and outputFormat =
  | HTMLFile
  | CSSFile
  | JSFile
  | JSONFile
  | XMLFile

and buildError = {
  file: string,
  line: option<int>,
  column: option<int>,
  message: string,
  code: string,
}

and buildWarning = {
  file: string,
  message: string,
  suggestion: option<string>,
}

and buildStats = {
  totalFiles: int,
  totalSize: int,
  buildTime: float,
  accessibilityFilesGenerated: int,
}

// Default configurations
let defaultAccessibilityConfig: accessibilityConfig = {
  enabled: true,
  defaultLanguage: BSL,
  supportedLanguages: [BSL, ASL, GSL],
  makatonEnabled: true,
  generateAltFormats: true,
}

let defaultBuildConfig: buildConfig = {
  outputDir: "_site",
  minify: true,
  sourceMaps: false,
  compilerTarget: HTMLA11y,
}

let defaultPathConfig: pathConfig = {
  content: "content",
  templates: "templates",
  static: "static",
  output: "_site",
}

let defaultSiteConfig: siteConfig = {
  name: "My Note G Site",
  title: "My Site",
  description: "An accessible website built with Note G",
  baseUrl: "/",
  language: "en",
  author: None,
  accessibility: defaultAccessibilityConfig,
  build: defaultBuildConfig,
  paths: defaultPathConfig,
}

// Sign language utilities
let signLanguageToCode = (lang: signLanguage): string => {
  switch lang {
  | BSL => "bfi"
  | ASL => "ase"
  | GSL => "gsg"
  | Auslan => "asf"
  | LSF => "fsl"
  | JSL => "jsl"
  }
}

let signLanguageToName = (lang: signLanguage): string => {
  switch lang {
  | BSL => "British Sign Language"
  | ASL => "American Sign Language"
  | GSL => "German Sign Language"
  | Auslan => "Australian Sign Language"
  | LSF => "French Sign Language"
  | JSL => "Japanese Sign Language"
  }
}
