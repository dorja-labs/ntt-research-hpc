FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Install all dependencies in a single layer
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    apt-transport-https \
    ca-certificates \
    unzip \
    make \
    build-essential \
    gcc \
    g++ \
    libc6-dev \
    zsh \
    git \
    fonts-powerline \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user/group if it doesn't exist
RUN if ! getent group $USERNAME > /dev/null 2>&1; then \
    groupadd --gid $USER_GID $USERNAME; \
    fi && \
    if ! getent passwd $USERNAME > /dev/null 2>&1; then \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME; \
    fi && \
    apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set up the workspace
WORKDIR /workspaces/cluster-toolkit

# Switch to non-root user
USER $USERNAME

# Set up environment variables
ENV SHELL=/bin/zsh