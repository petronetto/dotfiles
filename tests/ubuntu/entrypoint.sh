#!/bin/sh
# Fixture entrypoint: per-container SSH host keys, restricted access policy,
# and sshd in the foreground under the compose-init process.
set -eu

mkdir -p /run/sshd

# Per-container host keys: generated in the container filesystem so a restarted
# container keeps its identity and a rebuilt container gets a new one.
ssh-keygen -A

cat > /etc/ssh/sshd_config.d/fixture.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
EOF
chmod 0644 /etc/ssh/sshd_config.d/fixture.conf

exec /usr/sbin/sshd -D -e
