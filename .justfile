default: install

alias f := format
alias fmt := format

format:
    just --fmt --unstable

install-immich-cli immich_cli_version="v0.14.0" nodejs_version=20.11.0:
    #!/usr/bin/env bash
    set -euxo pipefail
    distro=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
    if [ "$distro" = "debian" ]; then
        git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch {{ immich_cli_version }}
        sudo apt-get --yes install dirmngr gpg curl gawk
        . "$HOME/.asdf/asdf.sh" && asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
        . "$HOME/.asdf/asdf.sh" && asdf install nodejs {{ nodejs_version }}
        . "$HOME/.asdf/asdf.sh" && asdf global nodejs {{ nodejs_version }}
        . "$HOME/.asdf/asdf.sh" && sudo npm install --global @immich/cli
    elif [ "$distro" = "fedora" ]; then
        variant=$(awk -F= '$1=="VARIANT_ID" { print $2 ;}' /etc/os-release)
        if [ "$variant" = "container" ]; then
            sudo dnf --assumeyes install nodejs
        elif [ "$variant" = "iot" ] || [ "$variant" = "sericea" ]; then
            sudo rpm-ostree install nodejs
        fi
        sudo npm install --global @immich/cli
    fi

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
