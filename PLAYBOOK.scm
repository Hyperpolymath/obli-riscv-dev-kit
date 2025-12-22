;;; PLAYBOOK.scm - Development Playbook and Procedures
;;; obli-riscv-dev-kit / Note G Language
;;; Reference: https://github.com/hyperpolymath/PLAYBOOK.scm

;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

(define-module (obli-riscv-dev-kit playbook)
  #:export (development-playbook
            testing-playbook
            release-playbook
            accessibility-playbook))

;;;============================================================================
;;; DEVELOPMENT PLAYBOOK
;;; Step-by-step procedures for common development tasks
;;;============================================================================

(define development-playbook
  '((setup
     (title . "Initial Development Setup")
     (steps
      (("Clone repository" . "git clone https://github.com/hyperpolymath/obli-riscv-dev-kit")
       ("Enter directory" . "cd obli-riscv-dev-kit")
       ("Install tools" . "asdf install")
       ("Enter dev shell" . "guix shell -D -f guix.scm")
       ("Verify setup" . "just check"))))

    (add-feature
     (title . "Adding a New Feature")
     (steps
      (("Create branch" . "git checkout -b feature/<name>")
       ("Update STATE.scm" . "Add feature to current-position")
       ("Implement feature" . "Follow coding standards in META.scm")
       ("Add tests" . "Create tests in tests/unit/ or tests/e2e/")
       ("Run tests" . "just test")
       ("Update docs" . "Add documentation for feature")
       ("Commit" . "git commit -m 'feat: <description>'")
       ("Push" . "git push -u origin feature/<name>")
       ("Create PR" . "gh pr create"))))

    (fix-bug
     (title . "Fixing a Bug")
     (steps
      (("Create branch" . "git checkout -b fix/<issue-number>")
       ("Reproduce bug" . "Add failing test case")
       ("Fix bug" . "Implement fix")
       ("Run tests" . "just test")
       ("Commit" . "git commit -m 'fix: <description> (#<issue>)'")
       ("Push and PR" . "git push -u origin fix/<issue-number> && gh pr create"))))

    (language-development
     (title . "Note G Language Development")
     (steps
      (("Modify lexer" . "Edit noteg-lang/src/lexer.res")
       ("Modify parser" . "Edit noteg-lang/src/parser.res")
       ("Update types" . "Edit noteg-lang/src/types.res")
       ("Update interpreter" . "Edit noteg-lang/src/interpreter.res")
       ("Update compiler" . "Edit noteg-lang/src/compiler.res")
       ("Run language tests" . "just test-lang")
       ("Update LSP" . "Edit noteg-lang/src/lsp/server.res")
       ("Test LSP" . "just lsp"))))))

;;;============================================================================
;;; TESTING PLAYBOOK
;;; Procedures for testing and quality assurance
;;;============================================================================

(define testing-playbook
  '((unit-tests
     (title . "Running Unit Tests")
     (commands
      (("All tests" . "just test")
       ("Language tests" . "just test-lang")
       ("SSG tests" . "just test-ssg")
       ("Engine tests" . "just test-engine"))))

    (e2e-tests
     (title . "End-to-End Testing")
     (commands
      (("Full E2E suite" . "just test-e2e")
       ("Accessibility E2E" . "just test-a11y")
       ("Build E2E" . "just test-build"))))

    (bernoulli-verification
     (title . "Bernoulli Verification")
     (description . "Probabilistic verification of template synthesis")
     (commands
      (("Run verification" . "just verify")
       ("Generate report" . "just verify-report"))))

    (accessibility-testing
     (title . "Accessibility Testing")
     (commands
      (("WCAG check" . "just a11y-check")
       ("BSL validation" . "just test-bsl")
       ("ASL validation" . "just test-asl")
       ("Makaton validation" . "just test-makaton"))))))

;;;============================================================================
;;; RELEASE PLAYBOOK
;;; Procedures for releasing new versions
;;;============================================================================

(define release-playbook
  '((prepare-release
     (title . "Preparing a Release")
     (steps
      (("Ensure main is up to date" . "git checkout main && git pull")
       ("Run all tests" . "just test-all")
       ("Update version" . "Edit version in guix.scm, flake.nix, CITATION.cff")
       ("Update CHANGELOG" . "Add release notes to CHANGELOG.adoc")
       ("Update STATE.scm" . "Mark milestone complete")
       ("Commit changes" . "git commit -m 'chore: prepare release vX.Y.Z'"))))

    (create-release
     (title . "Creating the Release")
     (steps
      (("Create tag" . "git tag -s vX.Y.Z -m 'Release vX.Y.Z'")
       ("Push tag" . "git push origin vX.Y.Z")
       ("Create GitHub release" . "gh release create vX.Y.Z --generate-notes")
       ("Verify CI/CD" . "Check that all workflows pass"))))

    (post-release
     (title . "Post-Release Tasks")
     (steps
      (("Update main" . "git checkout main && git pull")
       ("Bump version" . "Increment to next development version")
       ("Update STATE.scm" . "Set next milestone as current")
       ("Notify channels" . "Announce release"))))))

;;;============================================================================
;;; ACCESSIBILITY PLAYBOOK
;;; Procedures for accessibility-first development
;;;============================================================================

(define accessibility-playbook
  '((content-creation
     (title . "Creating Accessible Content")
     (steps
      (("Write content" . "Create content with clear structure")
       ("Add alt text" . "Provide alt text for all images")
       ("Add sign language" . "Add BSL/ASL/GSL annotations")
       ("Add Makaton" . "Add Makaton symbols where appropriate")
       ("Test with screen reader" . "Verify with NVDA/VoiceOver")
       ("Run a11y checks" . "just a11y-check"))))

    (sign-language-annotation
     (title . "Adding Sign Language Support")
     (syntax . "accessibility <language> { ... }")
     (languages
      (("bsl" . "British Sign Language (ISO 639-3: bfi)")
       ("asl" . "American Sign Language (ISO 639-3: ase)")
       ("gsl" . "German Sign Language / DGS (ISO 639-3: gsg)")
       ("auslan" . "Australian Sign Language (ISO 639-3: asf)")))
     (fields
      (("videoUrl" . "URL to interpretation video")
       ("transcript" . "Written transcript")
       ("glosses" . "Array of sign glosses")
       ("interpreter" . "Interpreter name/ID"))))

    (makaton-annotation
     (title . "Adding Makaton Support")
     (syntax . "accessibility makaton { ... }")
     (fields
      (("symbols" . "Array of Makaton symbols")
       ("sequence" . "Symbol sequence representation")
       ("audioUrl" . "URL to spoken audio")
       ("level" . "core | additional | resource"))))

    (wcag-compliance
     (title . "WCAG Compliance Checklist")
     (levels
      (("A" . "Minimum accessibility")
       ("AA" . "Standard target (RSR default)")
       ("AAA" . "Enhanced accessibility")))
     (checks
      (("1.1.1" . "Non-text Content - Alt text for images")
       ("1.2.1" . "Audio-only and Video-only - Alternatives provided")
       ("1.2.5" . "Audio Description - For video content")
       ("1.3.1" . "Info and Relationships - Semantic markup")
       ("1.4.3" . "Contrast - Minimum 4.5:1 for normal text")
       ("2.1.1" . "Keyboard - All functionality keyboard accessible")
       ("2.4.1" . "Bypass Blocks - Skip links provided")
       ("3.1.1" . "Language of Page - lang attribute set")
       ("4.1.1" . "Parsing - Valid HTML"))))))

;;;============================================================================
;;; HELPER FUNCTIONS
;;;============================================================================

(define (get-playbook name)
  "Retrieve a specific playbook by name"
  (case name
    ((development) development-playbook)
    ((testing) testing-playbook)
    ((release) release-playbook)
    ((accessibility) accessibility-playbook)
    (else #f)))

(define (list-playbooks)
  "List all available playbooks"
  '(development testing release accessibility))

;;; End of PLAYBOOK.scm
