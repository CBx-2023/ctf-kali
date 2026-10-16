# syntax=docker/dockerfile:1
FROM kalilinux/kali-rolling@sha256:02f5d6c019e549b0f55da58e835cad5355ef1030c6b2645265a324e37dfc4acc
ARG TARGETARCH
ARG CLAUDE_VERSION=2.1.238
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git jq ripgrep file unzip zip xz-utils \
    python3 python3-venv python3-pip build-essential pkg-config \
    gdb binutils strace nmap netcat-openbsd socat dnsutils iproute2 iputils-ping \
    openssh-client openssl procps tini less nano libstdc++6 \
    && dpkg-query -W > /usr/local/share/ctf-system-packages.txt \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN set -eu; \
    case "$TARGETARCH" in amd64) platform=linux-x64 ;; arm64) platform=linux-arm64 ;; *) exit 1 ;; esac; \
    base="https://downloads.claude.ai/claude-code-releases/$CLAUDE_VERSION"; \
    mkdir -p /usr/local/libexec; \
    curl --retry 3 -fsSL "$base/manifest.json" -o /tmp/manifest.json; \
    checksum="$(jq -er --arg p "$platform" '.platforms[$p].checksum' /tmp/manifest.json)"; \
    curl --retry 3 -fsSL "$base/$platform/claude" -o /usr/local/libexec/claude; \
    echo "$checksum  /usr/local/libexec/claude" | sha256sum -c -; \
    chmod 755 /usr/local/libexec/claude; \
    rm /tmp/manifest.json
COPY requirements.lock /opt/ctf/requirements.lock
RUN python3 -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r /opt/ctf/requirements.lock \
    && /opt/venv/bin/pip check
RUN useradd -m -u 1000 -s /bin/bash ctf && mkdir -p /workspace /opt/ctf \
    && chown ctf:ctf /workspace
COPY app/ /opt/ctf/app/
COPY tests/ /opt/ctf/tests/
COPY prompts/ /opt/ctf/prompts/
COPY docker/claude docker/ctf docker/entrypoint /usr/local/bin/
RUN chmod 755 /usr/local/bin/claude /usr/local/bin/ctf /usr/local/bin/entrypoint
ENV PATH="/opt/venv/bin:${PATH}" \
    HOME=/home/ctf PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 \
    DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    CTF_WORKSPACE=/workspace
USER ctf
WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
CMD ["run"]
