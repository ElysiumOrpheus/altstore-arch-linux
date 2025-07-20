### `README.md`

# AltServer on Arch Linux
ive looked at so many reddit forums, the aur and githubs trying to install altstore on arch but i couldnt find any so i made my own!

---

- [Prerequisites](#prerequisites)
- [Installation (The Easy Way)](#installation-the-easy-way)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [The Manual Way](#the-manual-way)
- [Sources & Credits](#sources--credits)

## Prerequisites

1.  **Git:** 
    ```sh
    sudo pacman -S git
    ```

2.  **An AUR Helper (like `yay`):**
    ```sh
    sudo pacman -S --needed base-devel
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    ```

## Installation (The Easy Way)

1.  **Clone this project:**
    ```sh
    git clone https://github.com/your-username/altserver-arch-linux.git
    cd altserver-arch-linux
    ```

2.  **Run the install script:**
    ```sh
    ./install.sh
    ```
    The script will ask for your password to install packages and set things up. It will show you exactly what it's doing at each step.

3.  **❗ Log Out and Log Back In ❗**
    This is the most important step! The script adds your user to the `docker` group, but the change won't take effect until you **fully log out and log back in**. DO NOT SKIP!!

## Configuration

The server is running, but it doesn't know about your devices yet. Let's make the introduction.

**1. Pair your iPhone or iPad**
   - Connect your device to your computer with a USB cable.
   - On your phone, you'll get a popup asking you to "Trust This Computer?". Tap **Trust** and enter your passcode. (make sure your phone is on and unlocked during this step otherwise you wont get the prompt)
   - Back on your computer, verify the pairing worked
     ```sh
     idevicepair validate
     ```
   - You should see a `SUCCESS` message. If not, try unplugging and rebooting the phone.

**2. Get Your Device's UDID**
   - This is your phone's unique serial number, and we need it for the next command.
     ```sh
     idevice_id -l
     ```
   - It will print a long string of letters and numbers. Copy that.

**3. Install AltStore for the First Time**
   - We're going to manually tell AltServer to install the AltStore app onto your phone.
   - First, download the app file (`.ipa`) to your home directory:
     ```sh
     cd ~
     curl -L https://cdn.altstore.io/file/altstore/apps/altstore/2_2.ipa > AltStore.ipa
     ```
   - Now, run the install command. **Fill in the placeholders** with your info. (you can read through this code if you dont trust it on the altstore github... i didnt write it myself)
     ```sh
     ALTSERVER_ANISETTE_SERVER=http://127.0.0.1:6969 /opt/altserver/AltServer -u <YOUR_UDID_HERE> -a <your-apple-id@email.com> -p <your-apple-password> ~/AltStore.ipa
     ```

The altstore icon should be on your homescreen. You will need to head to VPN & Device Management and trust the developer app with your apple id on it. (if you dont have a vpn % device management, search up profiles in your setting)

## Troubleshooting

- **Check if the services are running:**
  ```sh
  # Check the background daemons we set up
  systemctl --user status altserver.service netmuxd.service

  # Check the system-wide services
  systemctl status docker.service avahi-daemon.service
  ```
  Look for the `active (running)` status in green.

- **Check the Docker container:**
  ```sh
  docker ps
  ```
  You should see the `dadoum/anisette-v3-server` container running.

- **Look at the logs:**
  If a service is failing, the logs will tell you why.
  ```sh
  # See the AltServer logs in real-time
  journalctl --user -u altserver.service -f

  # See the netmuxd logs
  journalctl --user -u netmuxd.service -f
  ```

## The Manual Way

<details>
<summary>Manually installing:</summary>

Here's a breakdown of what the `install.sh` script does

1.  **Install Dependencies:**
    ```sh
    sudo pacman -S --needed avahi usbmuxd libplist libimobiledevice libimobiledevice-glue gtk3 openssl rustup docker
    yay -S --needed libtatsu-git
    ```
2.  **Setup Rust:**
    ```sh
    rustup toolchain install stable && rustup default stable
    ```
3.  **Download Binaries:**
    ```sh
    sudo mkdir -p /opt/altserver
    sudo wget https://github.com/NyaMisty/AltServer-Linux/releases/download/v0.0.5/AltServer-x86_64 -O /opt/altserver/AltServer
    sudo wget https://github.com/jkcoxson/netmuxd/releases/download/v0.1.4/x86_64-linux-netmuxd -O /opt/altserver/netmuxd
    sudo chmod +x /opt/altserver/AltServer /opt/altserver/netmuxd
    ```
4.  **Setup System Services:**
    ```sh
    sudo systemctl enable --now avahi-daemon.service usbmuxd.service docker.service
    ```
5.  **Setup User Services:**
    Create the file `~/.config/systemd/user/netmuxd.service`:
    ```ini
    [Unit]
    Description=netmuxd for AltServer
    After=network-online.target

    [Service]
    ExecStart=/opt/altserver/netmuxd

    [Install]
    WantedBy=default.target
    ```
    Create `~/.config/systemd/user/altserver.service`:
    ```ini
    [Unit]
    Description=AltServer Daemon
    After=network-online.target netmuxd.service

    [Service]
    Environment="ALTSERVER_ANISETTE_SERVER=http://127.0.0.1:6969"
    ExecStart=/opt/altserver/AltServer

    [Install]
    WantedBy=default.target
    ```
    Then enable them:
    ```sh
    systemctl --user daemon-reload
    systemctl --user enable --now netmuxd.service altserver.service
    ```
6.  **Setup Docker & Anisette:**
    ```sh
    sudo usermod -aG docker $USER
    # LOG OUT AND LOG BACK IN HERE!
  :/lib/ dadoum/anisette-v3-server
    ```
</details>

## Sources & Credits

This project wouldn't be possible without the hard work of many others. So heres credit where credits due

-   **Original Idea:** [quagmire's Raspberry Pi Guide](https://github.com/quagmire/alt-server-pi-guide)
-   **AltServer for Linux:** [NyaMisty](https://github.com/NyaMisty/AltServer-Linux)
-   **netmuxd:** [jkcoxson](https://github.com/jkcoxson/netmuxd)
-   **Anisette Server:** [dadoum](https://github.com/dadoum/anisette-v3-server)