default: install

alias f := format
alias fmt := format

format:
    just --fmt --unstable

install-nushell version="0.94.2":
    #!/usr/bin/env bash
    set -euxo pipefail
    distro=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
    if [ "$distro" = "debian" ]; then
        curl --location --remote-name https://github.com/nushell/nushell/releases/download/{{ version }}/nu-{{ version }}-{{ arch() }}-unknown-linux-gnu.tar.gz
        tar --extract --file nu-{{ version }}-{{ arch() }}-unknown-linux-gnu.tar.gz
        sudo mv nu-{{ version }}-{{ arch() }}-unknown-linux-gnu/nu* /usr/local/bin
        rm --force --recursive nu-{{ version }}-{{ arch() }}-unknown-linux-gnu*
        mkdir --parents {{ config_directory() }}/nushell/
        curl --location --output {{ config_directory() }}/nushell/config.nu https://raw.githubusercontent.com/nushell/nushell/{{ version }}/crates/nu-utils/src/sample_config/default_config.nu
        curl --location --output {{ config_directory() }}/nushell/env.nu https://raw.githubusercontent.com/nushell/nushell/{{ version }}/crates/nu-utils/src/sample_config/default_env.nu
    elif [ "$distro" = "fedora" ]; then
        curl --location https://copr.fedorainfracloud.org/coprs/atim/nushell/repo/fedora/atim-nushell-fedora.repo \
            | sudo tee /etc/yum.repos.d/atim-nushell-fedora.repo
        variant=$(awk -F= '$1=="VARIANT_ID" { print $2 ;}' /etc/os-release)
        if [ "$variant" = "container" ]; then
            sudo dnf --assumeyes install nushell
        elif [ "$variant" = "iot" ] || [ "$variant" = "sericea" ]; then
            sudo rpm-ostree install nushell
        fi
    fi

install-immich-cli: install-nushell install
    #!/usr/bin/env bash
    set -euxo pipefail
    distro=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
    if [ "$distro" = "debian" ]; then
        sudo apt-get --yes install podman
    elif [ "$distro" = "fedora" ]; then
        variant=$(awk -F= '$1=="VARIANT_ID" { print $2 ;}' /etc/os-release)
        if [ "$variant" = "container" ]; then
            sudo dnf --assumeyes install podman
        elif [ "$variant" = "iot" ] || [ "$variant" = "sericea" ]; then
            sudo rpm-ostree install podman
        fi
    fi
    sudo cp immich-cli/autoupload.nu /usr/local/bin

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
