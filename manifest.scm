;;; SPDX-License-Identifier: PMPL-1.0-or-later
;;; SPDX-FileCopyrightText: 2024-2025 hyperpolymath

;;; manifest.scm — Guix development environment manifest
;;;
;;; Usage:
;;;   guix shell -m manifest.scm
;;;   guix time-machine -C channels.scm -- shell -m manifest.scm
;;;
;;; For reproducible builds, always use time-machine with pinned channels.

(specifications->manifest
 '(;; ==========================================================================
   ;; Core Build Tools
   ;; ==========================================================================
   "just"                    ; Command runner
   "git"                     ; Version control
   "coreutils"               ; Basic utilities
   "findutils"               ; find, xargs
   "grep"                    ; Pattern matching
   "sed"                     ; Stream editor
   "gawk"                    ; Text processing

   ;; ==========================================================================
   ;; Rust Toolchain
   ;; ==========================================================================
   ;; Note: Prefer rustup for target management, or use:
   ;; "rust"                 ; Guix-packaged Rust
   ;; "rust:cargo"           ; Cargo package manager

   ;; ==========================================================================
   ;; RISC-V Cross-Compilation
   ;; ==========================================================================
   "cross-gcc-toolchain-riscv64-elf"  ; RV64 cross-compiler
   ;; "cross-gcc-toolchain-riscv32-elf"  ; RV32 (if available)

   ;; ==========================================================================
   ;; Debug & Flash Tools
   ;; ==========================================================================
   "openocd"                 ; JTAG/SWD debug probe
   "gdb"                     ; GNU Debugger
   "qemu"                    ; Emulator (includes riscv32/64)

   ;; ==========================================================================
   ;; Serial Communication
   ;; ==========================================================================
   "picocom"                 ; Serial terminal
   "screen"                  ; Alternative serial terminal

   ;; ==========================================================================
   ;; Documentation
   ;; ==========================================================================
   "asciidoctor"             ; AsciiDoc processor

   ;; ==========================================================================
   ;; Code Quality
   ;; ==========================================================================
   "shellcheck"              ; Shell script linter
   "python-pre-commit"       ; Pre-commit hooks

   ;; ==========================================================================
   ;; Optional: Deno Runtime
   ;; ==========================================================================
   ;; "deno"                 ; Uncomment when Guix packages Deno

   ;; ==========================================================================
   ;; Development Utilities
   ;; ==========================================================================
   "binutils"                ; objdump, objcopy, etc.
   "file"                    ; File type detection
   "xxd"                     ; Hex dump utility
   "dtc"                     ; Device tree compiler
   ))
