#!/bin/bash

set -euo pipefail

# Installs the tools p3 needs (if missing): docker, k3d, kubectl.
# Works on macOS (brew) and Debian-family Linux (apt).

OS="$(uname -s)"

case "$OS" in

    Darwin)
        if ! command -v brew >/dev/null 2>&1; then
            echo "Error: Homebrew is required (https://brew.sh)"
            exit 1
        fi

        for tool in k3d kubectl; do
            if command -v "$tool" >/dev/null 2>&1; then
                echo "$tool: already installed"
            else
                brew install "$tool"
            fi
        done

        if ! command -v docker >/dev/null 2>&1; then
            brew install --cask docker-desktop
        fi
        ;;
    Linux)
        if [ "$(id -u)" -ne 0 ]; then
            SUDO="sudo"
        else
            SUDO=""
        fi
        $SUDO apt-get update -y >/dev/null

        command -v curl >/dev/null 2>&1 || $SUDO apt-get install -y curl
        command -v docker >/dev/null 2>&1 || $SUDO apt-get install -y docker.io

        if ! command -v kubectl >/dev/null 2>&1; then 
            $SUDO curl -sfLo /usr/local/bin/kubectl \
                "https://dl.k8s.io/release/$(curl -sfL \
                https://dl.k8s.io/release/stable.txt)/bin/linux/$(dpkg --print-architecture)/kubectl" 
            $SUDO chmod +x /usr/local/bin/kubectl
        fi
        if ! command -v k3d  >/dev/null 2>&1; then
            curl -sfL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | $SUDO bash
        fi
        ;;
    *)
        echo "Error: unsupported OS: $OS"
        exit 1
        ;;

esac

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed (or not on PATH)."
    exit 1
fi

if ! docker info  >/dev/null 2>&1; then
    echo "Docker is installed but the daemon is not running."
    echo "macOS: start Docker Desktop. Linux: sudo systemctl start docker"
    echo "  Linux: if you see permission denied, run: sudo usermod -aG docker \$USER"
    echo "         then log out and back in."
    exit 1
fi

echo "All tools are ready! Yay!"