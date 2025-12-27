;;; SPDX-License-Identifier: MIT OR AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2024-2025 hyperpolymath

;;; channels.scm — Pinned Guix channels for reproducible builds
;;;
;;; Usage:
;;;   guix time-machine -C channels.scm -- shell -m manifest.scm
;;;   guix time-machine -C channels.scm -- build -f guix.scm
;;;
;;; To update channels:
;;;   guix describe -f channels > channels.scm.new
;;;   # Review and update this file

(list
 (channel
  (name 'guix)
  (url "https://git.savannah.gnu.org/git/guix.git")
  ;; Pin to a specific commit for reproducibility
  ;; Update this commit hash to upgrade the entire toolchain
  (commit "a1b2c3d4e5f6789012345678901234567890abcd")
  (introduction
   (make-channel-introduction
    "9edb3f66fd807b096b48283debdcddccfea34bad"
    (openpgp-fingerprint
     "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))

 ;; Nonguix channel for additional packages (optional)
 ;; Uncomment if needed for proprietary firmware blobs
 ;; (channel
 ;;  (name 'nonguix)
 ;;  (url "https://gitlab.com/nonguix/nonguix")
 ;;  (commit "abc123...")
 ;;  (introduction
 ;;   (make-channel-introduction
 ;;    "..."
 ;;    (openpgp-fingerprint "..."))))
 )
