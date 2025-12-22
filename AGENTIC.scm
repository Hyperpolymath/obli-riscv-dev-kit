;;; AGENTIC.scm - AI Agent Collaboration Framework
;;; obli-riscv-dev-kit / Note G Language
;;; Reference: https://github.com/hyperpolymath/AGENTIC.scm

;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

(define-module (obli-riscv-dev-kit agentic)
  #:export (agent-capabilities
            collaboration-protocols
            safety-constraints
            context-sharing))

;;;============================================================================
;;; AGENT CAPABILITIES
;;; Defines what AI agents can do in this repository
;;;============================================================================

(define agent-capabilities
  '((code-generation
     (allowed . #t)
     (languages . ("ReScript" "Ada" "Scheme" "Nickel"))
     (constraints
      (("No TypeScript" . "Use ReScript instead")
       ("No npm" . "Use Deno with import maps")
       ("No Python" . "Use Rust/Ada/Elixir")))
     (preferred-patterns
      (("Functional" . "Prefer immutable data and pure functions")
       ("Type-safe" . "Use strong typing, avoid any/unknown")
       ("Accessible" . "Include a11y metadata in all content"))))

    (file-operations
     (allowed . #t)
     (create . #t)
     (modify . #t)
     (delete . ("Only with explicit confirmation"))
     (protected-files
      (".git/"
       "LICENSE.txt"
       ".well-known/security.txt")))

    (git-operations
     (allowed . #t)
     (commit . #t)
     (push . ("Only to feature branches"))
     (force-push . #f)
     (protected-branches . ("main" "master")))

    (testing
     (allowed . #t)
     (run-tests . #t)
     (write-tests . #t)
     (coverage-minimum . 70))

    (documentation
     (allowed . #t)
     (formats . ("AsciiDoc" "Markdown"))
     (auto-generate . #t)
     (update-scm-files . #t))))

;;;============================================================================
;;; COLLABORATION PROTOCOLS
;;; How agents should interact with this codebase
;;;============================================================================

(define collaboration-protocols
  '((context-loading
     (description . "How to load project context")
     (steps
      (("Read STATE.scm" . "Current project state and position")
       ("Read META.scm" . "Architecture decisions and practices")
       ("Read ECOSYSTEM.scm" . "Related projects and integrations")
       ("Read PLAYBOOK.scm" . "Development procedures")
       ("Read CLAUDE.md" . "Language and security policies"))))

    (state-updates
     (description . "How to update project state")
     (when
      (("After completing tasks" . "Update STATE.scm completion percentages")
       ("After adding features" . "Add to working-features list")
       ("After fixing bugs" . "Remove from blockers-and-issues")
       ("After sessions" . "Add to session-history")))
     (format . "Preserve S-expression structure"))

    (code-review
     (description . "How to review code changes")
     (checklist
      (("RSR compliance" . "Check language and security policies")
       ("Accessibility" . "Verify a11y metadata present")
       ("Tests" . "Ensure tests added/updated")
       ("Documentation" . "Check docs are current")
       ("SCM files" . "Update if needed"))))

    (error-handling
     (description . "How to handle errors")
     (steps
      (("Log error" . "Record in blockers-and-issues")
       ("Analyze" . "Determine root cause")
       ("Fix or escalate" . "Fix if possible, else escalate to user")
       ("Test fix" . "Verify fix works")
       ("Document" . "Update docs if needed"))))))

;;;============================================================================
;;; SAFETY CONSTRAINTS
;;; Boundaries for AI agent behavior
;;;============================================================================

(define safety-constraints
  '((security
     (no-secrets . "Never commit API keys, passwords, or tokens")
     (no-http . "Always use HTTPS, never HTTP")
     (no-weak-crypto . "No MD5/SHA1 for security purposes")
     (sha-pin-actions . "All GitHub Actions must be SHA-pinned")
     (validate-input . "Always validate external input"))

    (consent
     (ai-training . "Explicit consent required per ai.txt")
     (attribution . "Required for all derived works")
     (data-collection . "Explicit consent for level 2+ data"))

    (reversibility
     (no-destructive-ops . "Avoid irreversible operations")
     (backup-before-delete . "Create backup before removing content")
     (git-history . "Preserve git history, no force pushes to main"))

    (scope
     (stay-in-repo . "Only modify files within repository")
     (no-external-calls . "Don't make unauthorized external requests")
     (respect-gitignore . "Don't commit ignored files"))))

;;;============================================================================
;;; CONTEXT SHARING
;;; How to share context between agent sessions
;;;============================================================================

(define context-sharing
  '((persistent-files
     (description . "Files that persist context across sessions")
     (files
      (("STATE.scm" . "Project state and progress")
       ("META.scm" . "Architecture decisions")
       ("ECOSYSTEM.scm" . "Project relationships")
       ("PLAYBOOK.scm" . "Development procedures")
       ("AGENTIC.scm" . "Agent collaboration rules")
       ("NEUROSYM.scm" . "Neurosymbolic patterns"))))

    (session-handoff
     (description . "How to hand off between sessions")
     (steps
      (("Update STATE.scm" . "Record accomplishments and position")
       ("Commit changes" . "Ensure all work is committed")
       ("Document blockers" . "Record any outstanding issues")
       ("Leave notes" . "Add session notes in session-history"))))

    (state-format
     (description . "Format for state serialization")
     (type . "Guile Scheme S-expressions")
     (encoding . "UTF-8")
     (schema-version . "1.0"))))

;;;============================================================================
;;; MCP INTEGRATION
;;; Model Context Protocol server capabilities
;;;============================================================================

(define mcp-integration
  '((server-info
     (name . "noteg-mcp")
     (version . "0.1.0")
     (protocol-version . "2024-11-05"))

    (capabilities
     (tools . #t)
     (resources . #t)
     (prompts . #t)
     (sampling . #f))

    (tools
     (("compile" . "Compile Note G source to target format")
      ("interpret" . "Interpret Note G code")
      ("validate" . "Validate Note G syntax")
      ("a11y-check" . "Check accessibility compliance")))

    (resources
     (("noteg://config" . "Current site configuration")
      ("noteg://templates" . "Available templates")
      ("noteg://content" . "Content files")
      ("noteg://a11y" . "Accessibility metadata")))))

;;;============================================================================
;;; HELPER FUNCTIONS
;;;============================================================================

(define (agent-can? action)
  "Check if an agent action is allowed"
  (let ((cap (assoc-ref agent-capabilities action)))
    (if cap
        (assoc-ref cap 'allowed)
        #f)))

(define (get-constraints)
  "Get all safety constraints as a flat list"
  (append-map cdr safety-constraints))

(define (get-protected-files)
  "Get list of protected files"
  (assoc-ref (assoc-ref agent-capabilities 'file-operations) 'protected-files))

;;; End of AGENTIC.scm
