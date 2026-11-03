ARG BASE_IMAGE=ubuntu:26.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    jq \
    libarchive-tools \
    locales \
    python3 \
    sudo \
    zsh \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/zsh tester \
  && usermod -aG sudo tester \
  && printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d \
  && chmod 0755 /usr/sbin/policy-rc.d

COPY entrypoint.sh /usr/local/bin/fixture-entrypoint
RUN chmod 0755 /usr/local/bin/fixture-entrypoint

USER tester
WORKDIR /home/tester
ENTRYPOINT ["/usr/local/bin/fixture-entrypoint"]
CMD ["sleep", "infinity"]
