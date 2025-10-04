#!/bin/bash

# exit immediately if a command exits with a non zero status
set -e

Color_Off='\033[0m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
BBlue='\033[1;34m'
BPurple='\033[1;35m'

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

detect() {
    echo -e "${BPurple}[DETECT]${Color_Off} $1"
}

# Function to check if a package is installed
is_package_installed() {
    pacman -Qi "$1" &>/dev/null
}

# Function to check if an AUR package is available
is_aur_package_available() {
    yay -Si "$1" &>/dev/null 2>&1
}

# Function to remove conflicting packages safely (only if actually installed)
remove_conflicting_package() {
    local package="$1"
    local reason="$2"
    
    if is_package_installed "$package"; then
        warning "Removing conflicting package '$package' ($reason)"
        sudo pacman -Rdd --noconfirm "$package" || {
            warning "Could not remove $package cleanly, trying force removal..."
            sudo pacman -Rdd --noconfirm --nodeps "$package" || {
                error "Failed to remove conflicting package $package"
                return 1
            }
        }
        success "Removed conflicting package: $package"
        return 0
    else
        detect "Package '$package' not installed, skipping removal"
        return 0
    fi
}

# Function to detect and resolve package conflicts
resolve_package_conflicts() {
    info "Scanning for potential package conflicts..."
    
    # Define conflict pairs: [official_package]=[aur_package]
    declare -A conflicts=(
        ["libplist"]="libplist-git"
        ["libimobiledevice"]="libimobiledevice-git"
        ["libimobiledevice-glue"]="libimobiledevice-glue-git"
        ["usbmuxd"]="usbmuxd-git"
    )
    
    # Check each conflict pair
    for official in "${!conflicts[@]}"; do
        local aur="${conflicts[$official]}"
        
        # Check if AUR version is available and needed by our AUR dependencies
        if is_aur_package_available "$aur"; then
            detect "Checking conflict: $official vs $aur"
            
            # Check if the AUR package is required by libtatsu-git or other AUR deps
            local aur_deps=$(yay -Si libtatsu-git 2>/dev/null | grep -E "^Depends On" | grep -o "$aur" || echo "")
            
            if [[ -n "$aur_deps" ]] || [[ "$aur" == "libplist-git" ]]; then
                detect "AUR package '$aur' is required by AUR dependencies"
                
                # Check if AUR version is already installed
                if is_package_installed "$aur"; then
                    success "AUR package '$aur' already installed, skipping official version"
                    # Remove from official install list since AUR version exists
                    OFFICIAL_PACKAGES=(${OFFICIAL_PACKAGES[@]/$official})
                elif is_package_installed "$official"; then
                    # Only remove if official is installed and we need AUR version
                    remove_conflicting_package "$official" "conflicts with required AUR package $aur"
                    # Add to AUR install list
                    AUR_PACKAGES_TO_INSTALL+=("$aur")
                    # Remove from official install list
                    OFFICIAL_PACKAGES=(${OFFICIAL_PACKAGES[@]/$official})
                else
                    # Neither is installed, prefer AUR version
                    detect "Neither '$official' nor '$aur' installed, will install AUR version"
                    AUR_PACKAGES_TO_INSTALL+=("$aur")
                    # Remove from official install list
                    OFFICIAL_PACKAGES=(${OFFICIAL_PACKAGES[@]/$official})
                fi
            fi
        fi
    done
}

# Main script starts here
info "Starting AltServer setup for Arch Linux with conflict detection..."

# Check for AUR helper first
info "Checking for AUR helper (yay)..."
if ! command -v yay &> /dev/null; then
    error "AUR helper 'yay' not found. Please install it first."
    info "You can install it by running: sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
    exit 1
fi

# Define package lists
OFFICIAL_PACKAGES=(
    "avahi"
    "usbmuxd"
    "libplist"
    "libimobiledevice"
    "libimobiledevice-glue"
    "gtk3"
    "openssl"
    "rustup"
    "docker"
)

AUR_PACKAGES_TO_INSTALL=(
    "libtatsu-git"
)

# Resolve conflicts before installation
resolve_package_conflicts

# Remove empty elements from OFFICIAL_PACKAGES array
OFFICIAL_PACKAGES=($(printf "%s\n" "${OFFICIAL_PACKAGES[@]}" | grep -v '^$'))

# Install official packages (after conflict resolution)
if [ ${#OFFICIAL_PACKAGES[@]} -gt 0 ]; then
    info "Installing required packages from official repositories..."
    info "Packages to install: ${OFFICIAL_PACKAGES[*]}"
    sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"
else
    info "No official packages to install (all replaced by AUR versions)"
fi

# Install AUR packages
if [ ${#AUR_PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
    info "Installing AUR packages..."
    info "AUR packages to install: ${AUR_PACKAGES_TO_INSTALL[*]}"
    
    # Remove duplicates from AUR packages list
    AUR_PACKAGES_TO_INSTALL=($(printf "%s\n" "${AUR_PACKAGES_TO_INSTALL[@]}" | sort -u))
    
    yay -S --needed --noconfirm "${AUR_PACKAGES_TO_INSTALL[@]}"
else
    warning "No AUR packages to install"
fi

# Verify critical packages are installed
info "Verifying critical packages are installed..."
CRITICAL_PACKAGES=("libplist" "libplist-git" "libtatsu-git")
FOUND_LIBPLIST=false

for pkg in "${CRITICAL_PACKAGES[@]}"; do
    if is_package_installed "$pkg"; then
        success "Found: $pkg"
        if [[ "$pkg" == "libplist"* ]]; then
            FOUND_LIBPLIST=true
        fi
    fi
done

if [ "$FOUND_LIBPLIST" = false ]; then
    error "Neither libplist nor libplist-git is installed! This will cause issues."
    exit 1
fi

if ! is_package_installed "libtatsu-git"; then
    error "libtatsu-git is not installed! This is required for AltServer."
    exit 1
fi

# Rust config
info "Setting up Rust default toolchain..."
rustup toolchain install stable
rustup default stable

# Download and place binaries
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

# Setup and enable systemd
info "Enabling system-level services (avahi, usbmuxd, docker)..."
sudo systemctl enable --now avahi-daemon.service
sudo systemctl enable --now usbmuxd.service
sudo systemctl enable --now docker.service

info "Configuring netmuxd as a system service (root)..."
# Stop/disable any user-scoped netmuxd that might have been set up previously
systemctl --user stop netmuxd.service >/dev/null 2>&1 || true
systemctl --user disable netmuxd.service >/dev/null 2>&1 || true
rm -f ~/.config/systemd/user/netmuxd.service 2>/dev/null || true

# Write system unit for netmuxd
sudo tee /etc/systemd/system/netmuxd.service >/dev/null <<'EOF'
[Unit]
Description=netmuxd (network usbmuxd bridge)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/altserver/netmuxd
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now netmuxd.service

# Configure AltServer as a user service
info "Setting up user-level AltServer service..."
mkdir -p ~/.config/systemd/user/
cp ./systemd/altserver.service ~/.config/systemd/user/

# Ensure the user unit does not depend on a user-scoped netmuxd
sed -i 's/^After=network-online.target netmuxd.service$/After=network-online.target/' ~/.config/systemd/user/altserver.service || true

systemctl --user daemon-reload
systemctl --user enable --now altserver.service

# Docker and anisette server setup
info "Adding current user ($USER) to the 'docker' group..."
sudo usermod -aG docker $USER

info "Checking if Anisette container already exists..."
if docker ps -a --format "table {{.Names}}" | grep -q "anisette-v3"; then
    warning "Anisette container already exists. Removing old container..."
    docker stop anisette-v3 2>/dev/null || true
    docker rm anisette-v3 2>/dev/null || true
fi

info "Starting Anisette Docker container..."
docker run -d --restart always --name anisette-v3 -p 6969:6969 --volume anisette-v3_data:/home/Alcoholic/.config/anisette-v3/lib/ dadoum/anisette-v3-server

# Final verification
info "Performing final system verification..."
success "✓ Package installation completed successfully"
success "✓ Rust toolchain configured"
success "✓ Binaries downloaded and installed"
success "✓ System services enabled"
success "✓ User services configured"
success "✓ Docker group membership updated"
success "✓ Anisette server started"

# Final instructions
success "Setup script finished successfully!"
warning "=================================================================="
warning "IMPORTANT: You MUST log out and log back in for the Docker group"
warning "           permissions to take effect."
warning "=================================================================="
info "After logging back in, follow the 'Post-Installation' steps in the README to pair your device and install AltStore."
info ""
info "Quick verification commands you can run after reboot:"
info "  systemctl --user status altserver.service"
info "  systemctl status netmuxd.service"
info "  docker ps | grep anisette"
info "  groups | grep docker"
