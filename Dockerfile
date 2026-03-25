# Stage 1: Browser and build tools installation
# Python 3.12+ required for LangChain v1
FROM registry.access.redhat.com/ubi9/python-312 AS install-browser

LABEL io.k8s.display-name="GPT Researcher" \
      io.k8s.description="Autonomous AI research agent with web scraping capabilities" \
      io.openshift.expose-services="8000:http" \
      io.openshift.tags="python,ai,research,fastapi" \
      summary="GPT Researcher autonomous AI agent" \
      maintainer="GPT Researcher"

USER root

# Install Chromium (headless), Chromedriver, and build tools.
# EPEL provides chromium/chromedriver but depends on libs (pipewire, double-conversion)
# only in full RHEL AppStream. CentOS Stream 9 repos supply these missing deps.
# Firefox is not available in UBI9/EPEL; Chromium is sufficient for headless scraping.
COPY <<'REPOEOF' /etc/yum.repos.d/centos-stream-9.repo
[centos-stream-9-baseos]
name=CentOS Stream 9 - BaseOS
baseurl=https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/
gpgcheck=0
enabled=1

[centos-stream-9-appstream]
name=CentOS Stream 9 - AppStream
baseurl=https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/
gpgcheck=0
enabled=1
REPOEOF

RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
    && /usr/bin/crb enable \
    && dnf install -y --nodocs --setopt=install_weak_deps=False \
       ca-certificates gcc gcc-c++ make \
       chromium-headless chromedriver \
    && chromedriver --version \
    && rm -f /etc/yum.repos.d/centos-stream-9.repo \
    && dnf clean all \
    && rm -rf /var/cache/dnf /tmp/*

# Stage 2: Python dependencies installation
FROM install-browser AS gpt-researcher-install

USER root
ENV PIP_ROOT_USER_ACTION=ignore
WORKDIR /opt/app-root/src

# Copy and install Python dependencies in a single layer to optimize cache usage
COPY ./requirements.txt ./requirements.txt
COPY ./multi_agents/requirements.txt ./multi_agents/requirements.txt

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt --upgrade --prefer-binary && \
    pip install --no-cache-dir -r multi_agents/requirements.txt --upgrade --prefer-binary && \
    dnf remove -y gcc gcc-c++ make && \
    dnf clean all && \
    rm -rf /var/cache/dnf /tmp/* ~/.cache/pip

# Stage 3: Final stage with non-root user and app
FROM gpt-researcher-install AS gpt-researcher

# Basic server configuration
ENV HOST=0.0.0.0 \
    PORT=8000 \
    WORKERS=1

EXPOSE ${PORT}

# Create all runtime-writable directories with OpenShift-compatible permissions.
# OpenShift runs containers as an arbitrary UID in group 0 (root group),
# so all writable paths must be owned by GID 0 with group write via g=u.
RUN mkdir -p /opt/app-root/src/outputs \
             /opt/app-root/src/logs \
             /opt/app-root/src/data \
             /opt/app-root/src/my-docs \
    && chown -R 1001:0 /opt/app-root \
    && chmod -R g=u /opt/app-root \
    && chmod g=u /etc/passwd

USER 1001
WORKDIR /opt/app-root/src

# Copy the rest of the application files with proper ownership
COPY --chown=1001:0 ./ ./

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
