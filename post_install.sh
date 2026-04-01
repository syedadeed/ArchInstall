#!/bin/bash

configure_wifi ()
{
    sudo systemctl enable --now NetworkManager && sleep 3
    sudo nmcli device wifi list && sleep 5
    echo "Enter wifi name: "
    read wifi_name
    echo "Enter wifi password: "
    read ps
    sudo nmcli device wifi connect $wifi_name password $ps
    sudo nmcli connection modify $wifi_name connection.autoconnect yes
    sudo nmcli connection up $wifi_name
}

update_hostname ()
{
    echo "Enter hostname: "
    read host_name
    sudo hostnamectl set-hostname $host_name
    echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 ${host_name}" | sudo tee -a /etc/hosts
}

chaotic_aur_setup ()
{
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e "[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Syyu --noconfirm
    sudo pacman -S --noconfirm paru
}

audio_setup ()
{
    sudo pacman -S --noconfirm pipewire
    systemctl --user enable pipewire.service
    sudo pacman -S --noconfirm pipewire-alsa
    sudo pacman -S --noconfirm pipewire-jack
    sudo pacman -S --noconfirm pipewire-pulse
    systemctl --user enable pipewire-pulse.service
}

bluetooth_setup ()
{
    sudo pacman -S --noconfirm bluez
    sudo pacman -S --noconfirm bluez-utils
    sudo systemctl enable bluetooth.service
}

font_installation ()
{
    sudo pacman -S --noconfirm noto-fonts
    sudo pacman -S --noconfirm noto-fonts-cjk
    sudo pacman -S --noconfirm noto-fonts-extra
    sudo pacman -S --noconfirm noto-fonts-emoji
}

gui_setup ()
{
    sudo pacman -S --noconfirm hyprland
    sudo pacman -S --noconfirm xdg-desktop-portal-hyprland
    # sudo pacman -S --noconfirm swww
    sudo pacman -S --noconfirm grim
    sudo pacman -S --noconfirm slurp
    sudo pacman -S --noconfirm hyprpicker
    sudo pacman -S --noconfirm wl-clipboard
    sudo pacman -S --noconfirm brightnessctl
    sudo pacman -S --noconfirm playerctl
    paru -S --noconfirm xremap-hypr-bin
}

cli_tools_installation ()
{
    sudo pacman -S --noconfirm bash-completion btop tree jq
    sudo pacman -S --noconfirm yazi
    sudo pacman -S --noconfirm man-db man-pages
    sudo pacman -S --noconfirm certbot
    sudo pacman -S --noconfirm git github-cli
    #TODO remove tree-sitter-cli in future when neovim pkg updates to 0.12
    sudo pacman -S --noconfirm neovim tree-sitter-cli zip unzip
    sudo pacman -S --noconfirm opencode
    sudo pacman -S --noconfirm npm
    sudo pacman -S --noconfirm go
    sudo pacman -S --noconfirm gradle maven
    sudo pacman -S --noconfirm nasm emscripten
    sudo pacman -S --noconfirm python-virtualenv python-pip tk check-jsonschema
    sudo pacman -S --noconfirm gdb meson cmake clang
    sudo pacman -S --noconfirm android-tools
    sudo pacman -S --noconfirm docker docker-buildx docker-compose
    sudo systemctl enable --now docker.socket
    sudo usermod -aG docker $USER
    sudo pacman -S --noconfirm kubectl talosctl
}

driver_installation ()
{
    sudo pacman -S --noconfirm intel-ucode
    sudo pacman -S --noconfirm intel-media-driver
    sudo pacman -S --noconfirm libva-intel-driver
    sudo pacman -S --noconfirm vulkan-intel
    sudo pacman -S --noconfirm vulkan-radeon
}

gui_apps_installation ()
{
    sudo pacman -S --noconfirm kitty
    sudo pacman -S --noconfirm mpv
    sudo pacman -S --noconfirm brave-bin
    # paru -S --noconfirm beekeeper-studio-bin
    # echo -e "--ozone-platform-hint=auto\n--enable-features=UseOzonePlatform" > ~/.config/bks-flags.conf
    # mkdir -p ~/.config/beekeeper-studio
    # echo -e '{"data":"eyJsaWNlbnNlX2tleSI6eyJ2YWxpZF91bnRpbCI6IjIwOTktMDEtMDFUMDY6MDA6MDAuMDAwWiIsInN1cHBvcnRfdW50aWwiOiIyMDk5LTAxLTAxVDA2OjAwOjAwLjAwMFoiLCJjdXN0b21lcl9zdXBwb3J0X3VudGlsIjoiMjA5OS0wMS0wMVQwNjowMDowMC4wMDBaIiwiY3JlYXRlZF9hdCI6IjIwMjQtMDEtMDFUMDA6MDA6MDAuMDAwWiIsImxpY2Vuc2VfdHlwZSI6IlBlcnNvbmFsTGljZW5zZSIsImVtYWlsIjoicGVudGVzdEBleGFtcGxlLmNvbSIsImlkIjoxLCJrZXkiOiJhYWFhYWFhYS1iYmJiLWNjY2MtZGRkZC1lZWVlZWVlZWVlZWUiLCJzdWJzY3JpcHRpb24iOmZhbHNlLCJtYXhfYWxsb3dlZF9hcHBfcmVsZWFzZSI6bnVsbH0sImVycm9ycyI6bnVsbCwic3RhdHVzIjoyMDB9Cg==","signature":"FdIcSnF8Gv4oQnoOZs2NxTAzo73Vl7hemeraKtdJWq8hgRthNLgBqQMLUmyLUV8gjNjmlXWOK3362cLwRkb4csx3Fmk+OaAhyB0qp/jYNrm4bQ4D5EC+bWbmwTDGXP+vdbPyEDP85ZRuZINuSqnD+8huN7kdc38OHQNNY3w9hp99VpNrEWNIMeGsvF93t+0ljjPV2pSLXPeXZ6XkjwUZT1t7NuY/A/vIz7neVr4KO9uMoL/l83x/99Yt55sSs5xSUmjeodSs2FXOznlF6zCQbajiTuhxhh+8MfY0BDjCvpwP3fzw/Pn4eR7XJmVnulNV9Pdm1pRfUJi3EGr7Q7CIdQ=="}' > ~/.config/beekeeper-studio/license.json
    # mkdir -p /opt/Beekeeper\ Studio/resources
    # echo -e "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyAar3l0A2NSUfCXpF/UU\nK+CsT9l0bScqT5VtoQYwA6QkmGz0Zhe+YW3qIRlDMTXsRGgx5oWdpDG64RL9Dy1t\nNAeimJ6//mOcuAUWQzxo4bHRcdBgKxq/5xeTRqGJCP1KXFiRtQeFpKcVDMS5bu6K\nLSILaEo+UzKPQu+/O055NNivUcqE7aerjzI6Tab/5aeo2nBCYBZVQoe8j2MW1bwt\nuTbvjWXXrZLCk7VibcVNMT5fSSaWQG8tggiTCaoNHSMNQfjrEuqfdCHmMjH3PR1O\nLeiLmRYY2YtfHiaBwpa1wLrzLn4w72mMponvmK4QWj4I5pAqyWvUf6jDj5i3lDAQ\nGQIDAQAB\n-----END PUBLIC KEY-----" | sudo tee /opt/Beekeeper\ Studio/resources/production_pub.pem
    # paru -S --noconfirm insomnia-bin
}

virtualization_setup ()
{
    sudo pacman -S --noconfirm qemu-full
    sudo usermod -aG kvm $USER
    sudo pacman -S --noconfirm virt-manager
    sudo systemctl enable --now libvirtd.socket
    sudo usermod -aG libvirt $USER
    yes | sudo pacman -S iptables-nft
    sudo pacman -S --noconfirm dnsmasq
    sudo pacman -S --noconfirm bridge-utils
    virsh net-autostart default
}

secure_boot_setup ()
{
    sudo pacman -S --noconfirm sbctl
    sudo sbctl create-keys
    sudo sbctl enroll-keys -m
    sudo sbctl sign -s /efi/EFI/Linux/arch-linux.efi
}

disk_maintenance ()
{
    sudo systemctl enable fstrim.timer
}

hibernate_setup ()
{
    echo -e "HibernateMode=shutdown\nHibernateDelaySec=2h" | sudo tee -a /etc/systemd/sleep.conf
    echo -e "HandleLidSwitch=suspend-then-hibernate" | sudo tee -a /etc/systemd/logind.conf
}

vpn_setup ()
{
    #make sure the wg0.conf file doesnt have a dns entry and AllowedIPs should just be 0.0.0.0/0
    sudo pacman -S --noconfirm wireguard-tools
    sudo mkdir -p /etc/wireguard
    server_private_key="$(wg genkey)"
    server_public_key="$(wg pubkey <<< "${server_private_key}")"
    client_private_key="$(wg genkey)"
    client_public_key="$(wg pubkey <<< "${client_private_key}")"
    domain_name="accio.cognus.cl"
    interface="wlp0s20u1"
    echo -e "[Interface]\nAddress = 10.0.0.1/8\nPostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o "${interface}" -j MASQUERADE;\nPostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o "${interface}" -j MASQUERADE;\nListenPort = 51820\nPrivateKey = "${server_private_key}"\n\n[Peer]\nPublicKey = "${client_public_key}"\nAllowedIPs = 10.0.0.2/32" | sudo tee /etc/wireguard/wg0.conf
    echo -e "[Interface]\nAddress = 10.0.0.2/32\nDNS = 8.8.8.8\nPrivateKey = "${client_private_key}"\n\n[Peer]\nPublicKey = "${server_public_key}"\nEndpoint = "${domain_name}":51820\nAllowedIPs = 0.0.0.0/0\nPersistentKeepalive = 25" > client.conf
    sudo chmod 600 /etc/wireguard/wg0.conf
    sudo touch /etc/wireguard/wg1.conf
    sudo chmod 600 /etc/wireguard/wg1.conf
}

configure_wifi
update_hostname
chaotic_aur_setup
audio_setup
bluetooth_setup
font_installation
gui_setup
cli_tools_installation
driver_installation
gui_apps_installation
virtualization_setup
secure_boot_setup
disk_maintenance
hibernate_setup
#vpn_setup

#Bibata cursor theme
