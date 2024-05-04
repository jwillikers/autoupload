default: install

alias f := format
alias fmt := format

format:
    just --fmt --unstable

install-immich-cli:
    #!/usr/bin/env bash
    set -euxo pipefail
    distro=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
    if [ "$distro" = "debian" ]; then
        distro_version=$(awk -F= '$1=="VERSION_ID" { gsub(/"/, "", $2); print $2 ;}' /etc/os-release)
        echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/Debian_$distro_version/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
        curl -fsSL "https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/Debian_$distro_version/Release.key" | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_stable.gpg > /dev/null
        sudo apt-get update
        sudo apt-get --yes install podman
    elif [ "$distro" = "fedora" ]; then
        variant=$(awk -F= '$1=="VARIANT_ID" { print $2 ;}' /etc/os-release)
        if [ "$variant" = "container" ]; then
            sudo dnf --assumeyes install podman
        elif [ "$variant" = "iot" ] || [ "$variant" = "sericea" ]; then
            sudo rpm-ostree install podman
        fi
    fi
    sudo loginctl enable-linger $USER
    mkdir --parents ~/.config/containers/systemd
    ln --force --relative --symbolic immich-cli/podman.network immich-cli/autoupload-immich.container ~/.config/containers/systemd/
    systemctl --user daemon-reload

install-rclone:
    #!/usr/bin/env bash
    set -euxo pipefail
    distro=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
    if [ "$distro" = "debian" ]; then
        sudo apt-get --yes install rclone
    elif [ "$distro" = "fedora" ]; then
        variant=$(awk -F= '$1=="VARIANT_ID" { print $2 ;}' /etc/os-release)
        if [ "$variant" = "container" ]; then
            sudo dnf --assumeyes install rclone
        elif [ "$variant" = "iot" ] || [ "$variant" = "sericea" ]; then
            sudo rpm-ostree install rclone
        fi
    fi

install:
    sudo cp systemd/user/* /etc/systemd/user/
    sudo cp systemd/system/* /etc/systemd/system/
    sudo systemctl daemon-reload
