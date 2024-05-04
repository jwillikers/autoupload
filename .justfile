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
        sudo apt-get --yes install podman
        mkdir --parents "{{ config_directory() }}/systemd/user"
        ln --force --relative --symbolic immich-cli/user/*.service "{{ config_directory() }}/systemd/user/"
    elif [ "$distro" = "fedora" ]; then
        variant=$(awk -F= '$1=="VARIANT_ID" { print $2 ;}' /etc/os-release)
        if [ "$variant" = "container" ]; then
            sudo dnf --assumeyes install podman
        elif [ "$variant" = "iot" ] || [ "$variant" = "sericea" ]; then
            sudo rpm-ostree install podman
        fi
        mkdir --parents "{{ config_directory() }}/containers/systemd"
        ln --force --relative --symbolic immich-cli/podman.network immich-cli/autoupload-immich@.container "{{ config_directory() }}/containers/systemd/"
    fi
    sudo loginctl enable-linger $USER
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
