#!/usr/bin/env bash
set -euo pipefail

LOG="/var/log/pi-hotspot-setup.log"
exec > >(tee -a "$LOG") 2>&1

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

WIFI_IFACE="${WIFI_IFACE:-}"
DEFAULT_SSID="${DEFAULT_SSID:-PiHotspot}"
DEFAULT_CHANNEL="${DEFAULT_CHANNEL:-6}"
DEFAULT_IP="${DEFAULT_IP:-10.10.0.1/24}"
DHCP_START="${DHCP_START:-10.10.0.100}"
DHCP_END="${DHCP_END:-10.10.0.200}"
DHCP_LEASE="${DHCP_LEASE:-24h}"

backup_file() {
  local f="$1"
  if [[ -f "$f" && ! -f "${f}.bak" ]]; then
    cp -a "$f" "${f}.bak"
  fi
}

detect_wifi_iface() {
  if [[ -n "$WIFI_IFACE" ]]; then
    echo "$WIFI_IFACE"
    return 0
  fi

  local iface
  iface="$(iw dev 2>/dev/null | awk '$1=="Interface" {print $2; exit}')" || true
  if [[ -n "${iface:-}" ]]; then
    echo "$iface"
    return 0
  fi

  iface="$(ls /sys/class/net 2>/dev/null | grep -E '^(wlan|wl)' | head -n1 || true)"
  if [[ -n "${iface:-}" ]]; then
    echo "$iface"
    return 0
  fi

  return 1
}

system_has() { command -v "$1" >/dev/null 2>&1; }

prompt_secret() {
  local varname="$1" prompt="$2" value confirm
  while true; do
    read -r -p "$prompt: " value
    read -r -s -p "Confirm $prompt: " confirm
    echo
    [[ -n "$value" && "$value" == "$confirm" ]] && break
    echo "Values did not match or were empty. Try again."
  done
  printf -v "$varname" '%s' "$value"
}

read -r -p "Hotspot SSID [${DEFAULT_SSID}]: " SSID
SSID="${SSID:-$DEFAULT_SSID}"

prompt_secret PASSWORD "Hotspot password (8+ chars)"
if [[ ${#PASSWORD} -lt 8 ]]; then
  echo "Password must be at least 8 characters."
  exit 1
fi

if ! WIFI_IFACE="$(detect_wifi_iface)"; then
  echo "No Wi-Fi interface found."
  exit 1
fi

echo "Using Wi-Fi interface: $WIFI_IFACE"

APT_PKGS=(hostapd dnsmasq)
if system_has dhcpcd || systemctl list-unit-files 2>/dev/null | grep -q '^dhcpcd\.service'; then
  APT_PKGS+=(dhcpcd5)
fi

apt update
apt install -y "${APT_PKGS[@]}"

if systemctl list-unit-files 2>/dev/null | grep -q '^NetworkManager\.service'; then
  echo "NetworkManager detected. Removing Wi-Fi connection(s) bound to ${WIFI_IFACE}."

  if system_has nmcli; then
    mapfile -t WIFI_CONNS < <(
      nmcli -t -f NAME,DEVICE connection show | awk -F: -v iface="$WIFI_IFACE" '$2==iface {print $1}'
    )

    if [[ ${#WIFI_CONNS[@]} -eq 0 ]]; then
      echo "No NetworkManager Wi-Fi connections found on ${WIFI_IFACE}."
    else
      for c in "${WIFI_CONNS[@]}"; do
        [[ -n "$c" ]] && nmcli connection delete "$c"
      done
    fi
  else
    echo "nmcli not found; cannot remove NetworkManager connections automatically."
  fi
fi

if systemctl list-unit-files 2>/dev/null | grep -q '^dhcpcd\.service'; then
  systemctl enable dhcpcd
  systemctl start dhcpcd || true

  backup_file /etc/dhcpcd.conf
  if ! grep -q "interface ${WIFI_IFACE}" /etc/dhcpcd.conf; then
    cat >> /etc/dhcpcd.conf <<EOF

interface ${WIFI_IFACE}
static ip_address=${DEFAULT_IP}
nohook wpa_supplicant
EOF
  fi

  systemctl restart dhcpcd || true
else
  echo "dhcpcd service not found; skipping dhcpcd config."
fi

backup_file /etc/dnsmasq.conf
cat > /etc/dnsmasq.conf <<EOF
interface=${WIFI_IFACE}
dhcp-range=${DHCP_START},${DHCP_END},255.255.255.0,${DHCP_LEASE}
EOF

mkdir -p /etc/hostapd
backup_file /etc/hostapd/hostapd.conf
cat > /etc/hostapd/hostapd.conf <<EOF
interface=${WIFI_IFACE}
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=${DEFAULT_CHANNEL}
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

if grep -q '^DAEMON_CONF=' /etc/default/hostapd 2>/dev/null; then
  sed -i 's|^DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
else
  echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd
fi

systemctl unmask hostapd || true
systemctl enable hostapd
systemctl enable dnsmasq
systemctl restart dnsmasq
systemctl restart hostapd

cat <<EOF

Hotspot configured successfully.
SSID: ${SSID}
Interface: ${WIFI_IFACE}
IP: ${DEFAULT_IP}
Log: ${LOG}

Reboot recommended:
  sudo reboot
EOF
