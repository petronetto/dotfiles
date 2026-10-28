# Fixture image for the retained ubuntu-dotfiles-test container.
# Ubuntu 26.04 AMD64. Deliberately minimal: bootstrap installs the remaining
# prerequisites inside the container, so this layer stays reproducible and small.
FROM ubuntu:26.04

# Base image digest is recorded in test evidence at prepare time with:
#   docker image inspect --format '{{index .RepoDigests 0}}' <image>

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    locales \
    openssh-server \
    sudo \
    zsh \
  && rm -rf /var/lib/apt/lists/*

# The fixture account owns its configuration and home. sudo membership keeps
# the standard credential challenge; this fixture adds no exemption entries.
RUN useradd -m -s /bin/zsh tester \
  && usermod -aG sudo tester

# sshd runtime configuration arrives from entrypoint.sh so host keys and
# access policy stay per-container instead of baked into the image layer.
COPY entrypoint.sh /usr/local/bin/fixture-entrypoint
RUN chmod 0755 /usr/local/bin/fixture-entrypoint

ENTRYPOINT ["/usr/local/bin/fixture-entrypoint"]
