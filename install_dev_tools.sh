#!/usr/bin/env bash
# DevOps Homework 3: idempotent tools setup for Ubuntu/Debian.
set -Eeuo pipefail

log() { printf '\n[INFO] %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

[[ -r /etc/os-release ]] || fail 'Cannot identify Linux distribution.'
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in
  ubuntu|debian) DISTRO="$ID" ;;
  *) fail 'Only Ubuntu and Debian are supported.' ;;
esac
[[ "$(id -u)" -eq 0 ]] && SUDO=() || {
  command -v sudo >/dev/null 2>&1 || fail 'Install sudo or run as root.'
  SUDO=(sudo)
}
export DEBIAN_FRONTEND=noninteractive

apt_install() {
  "${SUDO[@]}" apt-get install -y --no-install-recommends "$@"
}

configure_docker_repository() {
  log 'Configuring official Docker APT repository...'
  "${SUDO[@]}" apt-get update
  apt_install ca-certificates curl
  "${SUDO[@]}" install -m 0755 -d /etc/apt/keyrings
  "${SUDO[@]}" curl -fsSL "https://download.docker.com/linux/${DISTRO}/gpg" -o /etc/apt/keyrings/docker.asc
  "${SUDO[@]}" chmod a+r /etc/apt/keyrings/docker.asc
  local codename="${VERSION_CODENAME:-}"
  if [[ "$DISTRO" == ubuntu ]]; then
    codename="${UBUNTU_CODENAME:-$codename}"
  fi
  [[ -n "$codename" ]] || fail 'Could not determine distribution codename.'
  local architecture
  architecture="$(dpkg --print-architecture)"
  printf 'Types: deb\nURIs: https://download.docker.com/linux/%s\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' \
    "$DISTRO" "$codename" "$architecture" | \
    "${SUDO[@]}" tee /etc/apt/sources.list.d/docker.sources >/dev/null
  "${SUDO[@]}" apt-get update
}

# Docker Engine: skip when installed.
if command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
  log "Docker already installed: $(docker --version)"
else
  log 'Installing Docker Engine...'
  configure_docker_repository
  # Prevent package conflicts with Docker CE packages.
  for package in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
      "${SUDO[@]}" apt-get remove -y "$package"
    fi
  done
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Docker Compose V2 plugin: installed independently when Docker already exists.
if docker compose version >/dev/null 2>&1; then
  log "Docker Compose already installed: $(docker compose version --short)"
else
  log 'Installing Docker Compose plugin...'
  if ! apt-cache show docker-compose-plugin >/dev/null 2>&1; then
    configure_docker_repository
  fi
  apt_install docker-compose-plugin
fi

# Python 3.9+: use distro Python when possible and avoid unnecessary reinstall.
python_compatible() {
  command -v "$1" >/dev/null 2>&1 &&
    "$1" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1
}
PYTHON=''
for candidate in python3 python3.13 python3.12 python3.11 python3.10 python3.9; do
  if python_compatible "$candidate"; then PYTHON="$candidate"; break; fi
done
if [[ -n "$PYTHON" ]]; then
  log "Python already installed: $($PYTHON --version) ($PYTHON)"
else
  log 'Installing Python 3 through APT...'
  "${SUDO[@]}" apt-get update
  apt_install python3 python3-pip python3-venv
  if python_compatible python3; then
    PYTHON=python3
  else
    # Older releases may offer a supported alternate version.
    for version in 3.13 3.12 3.11 3.10 3.9; do
      if apt-cache show "python${version}" >/dev/null 2>&1; then
        apt_install "python${version}" "python${version}-venv"
        if python_compatible "python${version}"; then
          PYTHON="python${version}"
          break
        fi
      fi
    done
  fi
  [[ -n "$PYTHON" ]] || fail 'APT did not provide Python >= 3.9. Use a supported Ubuntu/Debian release or install Python >= 3.9 separately.'
fi

# Django: respect an existing installation; otherwise use a dedicated virtualenv
# to avoid Debian/Ubuntu externally-managed Python (PEP 668) errors.
if command -v django-admin >/dev/null 2>&1 && django-admin --version >/dev/null 2>&1; then
  log "Django already installed: $(django-admin --version)"
else
  VENV_DIR='/opt/devops-tools/django-venv'
  if [[ -x "$VENV_DIR/bin/django-admin" ]] && "$VENV_DIR/bin/django-admin" --version >/dev/null 2>&1; then
    log "Django already installed in $VENV_DIR"
  else
    log "Installing Django using pip in virtual environment: $VENV_DIR"
    if ! "$PYTHON" -m venv --help >/dev/null 2>&1; then
      "${SUDO[@]}" apt-get update
      apt_install python3-venv python3-pip
    fi
    "${SUDO[@]}" install -d -m 0755 /opt/devops-tools
    if ! "${SUDO[@]}" "$PYTHON" -m venv "$VENV_DIR"; then
      log 'Installing Python venv support and retrying...'
      apt_install python3-venv python3-pip
      "${SUDO[@]}" "$PYTHON" -m venv "$VENV_DIR"
    fi
    "${SUDO[@]}" "$VENV_DIR/bin/python" -m pip install django
  fi
  "${SUDO[@]}" ln -sfn "$VENV_DIR/bin/django-admin" /usr/local/bin/django-admin
fi

log 'Installation checks:'
docker --version
docker compose version
"$PYTHON" --version
django-admin --version
log 'Done. To test the Docker daemon, run: sudo docker run --rm hello-world'
