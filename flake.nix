# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2024-2025 hyperpolymath
#
# obli-riscv-dev-kit - Nix Flake (fallback after Guix)
# Usage: nix develop

{
  description = "RISC-V development kit with oblivious computing - RSR compliant";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "obli-riscv-dev-kit";
          version = "0.1.0";

          src = ./.;

          buildInputs = with pkgs; [
            guile
            just
          ];

          meta = with pkgs.lib; {
            description = "RISC-V development kit with oblivious computing";
            homepage = "https://github.com/hyperpolymath/obli-riscv-dev-kit";
            license = with licenses; [ mit agpl3Plus ];
            maintainers = [ ];
            platforms = platforms.all;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core tools
            guile
            just

            # Development utilities
            git
            gnumake

            # CI/CD tools
            actionlint
          ];

          shellHook = ''
            echo "obli-riscv-dev-kit development shell"
            echo "Primary: Use 'guix shell -D -f guix.scm' for Guix"
            echo "Fallback: This Nix flake"
            echo ""
            echo "Available commands:"
            echo "  just --list    # Show available tasks"
          '';
        };
      }
    );
}
