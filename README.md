# RPI-AP

[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-Zero%202%20W-red)](https://www.raspberrypi.com/products/raspberry-pi-zero-2-w/)
[![Shell Script](https://img.shields.io/badge/Script-Bash-blue)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/Platform-Linux-green)](https://www.raspberrypi.com/software/operating-systems/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Simple Raspberry Pi hotspot setup for headless installations.

This project configures a Raspberry Pi Zero 2 W as a Wi‑Fi access point using:

- `hostapd`
- `dnsmasq`
- `dhcpcd` when available
- `nmcli` cleanup for NetworkManager-based Wi‑Fi profiles

## Quick Start

The simplest way to use this project is:

```bash
git clone https://github.com/Moerbius/RPI-AP.git
cd RPI-AP
chmod +x setup.sh
sudo ./setup.sh
sudo reboot
```

The script will ask for:

- the hotspot SSID
- the hotspot password

## One-line install

```bash
git clone https://github.com/Moerbius/RPI-AP.git && cd RPI-AP && chmod +x setup.sh && sudo ./setup.sh && sudo reboot
```

## What it does

When you run `setup.sh`, it will:

- detect the active Wi‑Fi interface automatically
- remove the NetworkManager Wi‑Fi connection bound to that interface
- install the required packages
- configure a static IP for the access point
- configure DHCP with `dnsmasq`
- configure the access point with `hostapd`
- enable the services to start on boot
- write a log to `/var/log/pi-hotspot-setup.log`

## Requirements

- Raspberry Pi OS installed and booting to a terminal
- `sudo` access
- A Wi‑Fi adapter that supports access point mode
- Internet access during installation

## Default settings

Unless changed in the script, these defaults are used:

- IP address: `10.10.0.1/24`
- DHCP range: `10.10.0.100` to `10.10.0.200`
- Channel: `6`
- Wi‑Fi interface: auto-detected

## After installation

After the script finishes, reboot the Raspberry Pi:

```bash
sudo reboot
```

Then connect your device to the SSID you entered during setup.

## Verify services

If you want to check that everything is running:

```bash
systemctl status hostapd
systemctl status dnsmasq
```

To view the setup log:

```bash
sudo tail -n 50 /var/log/pi-hotspot-setup.log
```

## Uninstall / Revert

The script creates backups of edited configuration files with a `.bak` extension.

To manually restore the previous configuration, copy the backup files back into place, for example:

```bash
sudo cp /etc/dhcpcd.conf.bak /etc/dhcpcd.conf
sudo cp /etc/dnsmasq.conf.bak /etc/dnsmasq.conf
sudo cp /etc/hostapd/hostapd.conf.bak /etc/hostapd/hostapd.conf
sudo reboot
```

If you removed a NetworkManager Wi‑Fi connection, you may need to recreate it manually with `nmcli` or reconnect through your normal Wi‑Fi configuration method.

## Troubleshooting

### Hotspot does not appear

- Make sure your Wi‑Fi adapter supports AP mode.
- Confirm that `hostapd` is enabled and running.
- Check the log file for errors.

### NetworkManager keeps taking control of Wi‑Fi

- The script removes the active Wi‑Fi profile bound to the wireless interface.
- If a new profile appears after reboot, delete it again with:

```bash
nmcli connection show
sudo nmcli connection delete "CONNECTION_NAME"
```

### Check logs

```bash
sudo journalctl -u hostapd -u dnsmasq -b
sudo tail -n 100 /var/log/pi-hotspot-setup.log
```

## Notes

This repository is intended for a Raspberry Pi Zero 2 W and similar headless Raspberry Pi setups.

If you want a version that also supports restoring the client Wi‑Fi automatically after disabling the hotspot, that can be added later.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
