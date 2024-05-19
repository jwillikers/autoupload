default: install

alias f := format
alias fmt := format

format:
    just --fmt --unstable

install-immich-cli: install
    #!/usr/bin/env bash
    set -euxo pipefail
    distro=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
    if [ "$distro" = "debian" ]; then
        sudo apt-get --yes install podman
        sudo cp immich-cli/system/*.service "/etc/systemd/system/"
        sudo cp immich-cli/user/*.service "/etc/systemd/user/"
    elif [ "$distro" = "fedora" ]; then
        variant=$(awk -F= '$1=="VARIANT_ID" { print $2 ;}' /etc/os-release)
        if [ "$variant" = "container" ]; then
            sudo dnf --assumeyes install podman
        elif [ "$variant" = "iot" ] || [ "$variant" = "sericea" ]; then
            sudo rpm-ostree install podman
        fi
        sudo cp immich-cli/system/*.service "/etc/systemd/system/"
        sudo cp immich-cli/user/*.service "/etc/systemd/user/"
        sudo mkdir --parents "/etc/containers/systemd"
        sudo cp immich-cli/podman.network immich-cli/autoupload-immich@.container "/etc/containers/systemd/"
    fi
    sudo systemctl daemon-reload

install-rclone: install
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
