#!/bin/bash

# exit immediately if a command exits with a non zero statsu
set -e

Color_Off='\033[0m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
BBlue='\033[1;34m'

info() {
    echo -e "${BBlue}[INFO]${Color_Off} $1"
}

success() {
    echo -e "${BGreen}[SUCCESS]${Color_Off} $1"
}

warning() {
    echo -e "${BYellow}[WARNING]${Color_Off} $1"
}

error() {
    echo -e "${BRed}[ERROR]${Color_Off} $1"
}

# main scirpt

info "Starting AltServer setup for Arch Linux..."

# install dependencies
info "Installing required packages from official repositories..."
sudo pacman -S --needed --noconfirm \
  avahi \
  usbmuxd \
  libplist \
  libimobiledevice \
  libimobiledevice-glue \
  gtk3 \
  openssl \
  rustup \
  docker

# install aur dependencies
info "Checking for AUR helper (yay)..."
if ! command -v yay &> /dev/null; then
    error "AUR helper 'yay' not found. Please install it first."
    info "You can install it by running: sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
    exit 1
fi
info "Installing 'libtatsu-git' from the AUR..."
yay -S --needed --noconfirm libtatsu-git

# rust config
info "Setting up Rust default toolchain..."
rustup toolchain install stable
rustup default stable

# download and place binaries
info "Creating /opt/altserver and downloading binaries..."
sudo mkdir -p /opt/altserver
cd /opt/altserver
info "Downloading AltServer binary..."
sudo wget https://github.com/NyaMisty/AltServer-Linux/releases/download/v0.0.5/AltServer-x86_64 -O AltServer
info "Downloading netmuxd binary..."
sudo wget https://github.com/jkcoxson/netmuxd/releases/download/v0.1.4/x86_64-linux-netmuxd -O netmuxd
info "Making binaries executable..."
sudo chmod +x AltServer netmuxd
cd - > /dev/null 

# setup and enable systemd
info "Enabling system-level services (avahi, usbmuxd, docker)..."
sudo systemctl enable --now avahi-daemon.service
sudo systemctl enable --now usbmuxd.service
sudo systemctl enable --now docker.service

info "Setting up user-level services (netmuxd, altserver)..."
mkdir -p ~/.config/systemd/user/
cp ./systemd/netmuxd.service ~/.config/systemd/user/
cp ./systemd/altserver.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now netmuxd.service
systemctl --user enable --now altserver.service

# docker and anisette server setup
info "Adding current user ($USER) to the 'docker' group..."
sudo usermod -aG docker $USER
info "Starting Anisette Docker container..."
docker run -d --restart always --name anisette-v3 -p 6969:6969 --volume anisette-v3_data:/home/Alcoholic/.config/anisette-v3/lib/ dadoum/anisette-v3-server

# final instructions
success "Setup script finished!"
warning "------------------------------------------------------------------"
warning "IMPORTANT: You MUST log out and log back in for the Docker group"
warning "           permissions to take effect."
warning "------------------------------------------------------------------"
info "After logging back in, follow the 'Post-Installation' steps in the README to pair your device and install AltStore."