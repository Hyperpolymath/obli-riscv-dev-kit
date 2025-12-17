# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2024-2025 hyperpolymath
#
# obli-riscv-dev-kit - Container Image
# Build: podman build -f Containerfile -t obli-riscv-dev-kit .
# Run:   podman run -it --rm obli-riscv-dev-kit

# Use Guix as base for reproducibility (RSR primary)
# Fallback: debian:bookworm-slim if Guix unavailable
FROM docker.io/library/debian:bookworm-slim AS base

LABEL org.opencontainers.image.title="obli-riscv-dev-kit"
LABEL org.opencontainers.image.description="RISC-V development kit with oblivious computing"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.source="https://github.com/hyperpolymath/obli-riscv-dev-kit"
LABEL org.opencontainers.image.licenses="MIT OR AGPL-3.0-or-later"
LABEL org.opencontainers.image.vendor="hyperpolymath"

# Install core dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    guile-3.0 \
    && rm -rf /var/lib/apt/lists/*

# Install just (task runner)
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# Create non-root user for security
RUN useradd -m -s /bin/bash developer
USER developer
WORKDIR /home/developer/obli-riscv-dev-kit

# Copy project files
COPY --chown=developer:developer . .

# Default command
CMD ["just", "--list"]
