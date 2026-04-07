# 🛜 RouterPi

<p align="center">
  <b>Raspberry Pi 5 based 5GHz WiFi Router with DPI Bypass</b><br>
  <i>Plug-and-play home network solution that automatically bypasses ISP censorship</i>
</p>

---

Connects to your main modem via Ethernet, broadcasts its own 5GHz WiFi access point, and automatically bypasses ISP restrictions (DNS manipulation + DPI/SNI filtering). Meta Quest, PC, phone — every connected device is automatically routed through the protected network.

Built and tested in Turkey against Turkish ISP censorship infrastructure (Türk Telekom, etc.), but the approach is applicable to any country with similar DNS + DPI based blocking.

## ✨ Features

- **5GHz WiFi Access Point** — 802.11ac (WiFi 5), 80MHz channel width, ~300 Mbps
- **DNS-over-HTTPS (DoH)** — Bypasses ISP DNS manipulation (Cloudflare + Google DoH via dnscrypt-proxy)
- **DPI Bypass** — Defeats SNI-based filtering (zapret/nfqws)
- **Autohostlist** — Automatically detects blocked sites, no manual intervention needed
- **NAT Router** — Transparent internet for all connected devices
- **Boot-persistent** — All services start automatically after reboot
- **Meta Quest / PCVR compatible** — Sufficient bandwidth for VR streaming

## 🔧 Hardware Requirements

| Component | Model | Notes |
|-----------|-------|-------|
| SBC | Raspberry Pi 5 (4GB/8GB) | 8GB recommended |
| Storage | 32GB+ microSD | Class 10 / A2 recommended |
| Ethernet | Cat5e/Cat6 cable | Connection to main modem |
| Power | USB-C 5V/5A (27W) | Official RPi 5 PSU recommended |
| Cooling | Active fan (official or third-party) | Optional but recommended |

> **Note:** No external USB WiFi adapter needed — the RPi 5's built-in WiFi chip is used in AP mode.

## 🌐 Network Topology

```
                        Ethernet                    WiFi 5GHz
┌──────────────┐       ┌─────────────────────────┐       ┌──────────────────┐
│  Main Modem  │──────▶│  Raspberry Pi 5          │◀─────│  Devices         │
│              │ eth0  │                           │ wlan0│                  │
│  192.168.1.1 │       │  ┌─────────┐ ┌─────────┐ │      │  • Meta Quest 3S │
└──────────────┘       │  │ dnscrypt│ │ zapret  │ │      │  • PC            │
                       │  │  (DoH)  │ │ (nfqws) │ │      │  • Phone         │
                       │  └─────────┘ └─────────┘ │      │  • Tablet        │
                       │  NAT Masquerade (nftables)│      └──────────────────┘
                       │  192.168.4.1              │       192.168.4.2-100
                       └─────────────────────────┘
                              RouterPi
```

## 📦 Running Services

| Service | Role | Listening |
|---------|------|-----------|
| `hostapd` | 5GHz WiFi access point (AP) | wlan0 |
| `dnsmasq` | DHCP server + DNS forwarder | wlan0:53 |
| `dnscrypt-custom` | DNS-over-HTTPS proxy (Cloudflare/Google) | 127.0.0.1:5053 |
| `zapret` | DPI bypass (nfqws, autohostlist) | nfqueue |
| `nftables` | NAT masquerade | eth0 |
| `routerpi-wlan0` | Static IP for wlan0 + ip_forward | wlan0 |

## 🚀 Installation

### Prerequisites

A Raspberry Pi 5 with a clean Raspberry Pi OS install (Bookworm or Trixie, 64-bit) and SSH access. All commands are run over SSH.

---

### Step 1 — System Update and Package Installation

```bash
sudo apt update && sudo apt upgrade -y
```

Core packages:

```bash
sudo apt install -y hostapd dnsmasq iptables iptables-persistent git
```

Zapret build dependencies:

```bash
sudo apt install -y build-essential \
  libnetfilter-queue-dev \
  libmnl-dev \
  zlib1g-dev \
  libcap-dev \
  libnfnetlink-dev \
  libsystemd-dev
```

DNS-over-HTTPS:

```bash
sudo apt install -y dnscrypt-proxy
```

---

### Step 2 — Remove wlan0 from NetworkManager

On RPi OS Bookworm/Trixie, NetworkManager is active by default and manages wlan0. It must be released to use wlan0 as an AP.

```bash
# Delete existing WiFi connection (replace <SSID> with your network name)
sudo nmcli con delete "netplan-wlan0-<SSID>"

# Set wlan0 as unmanaged
sudo nmcli dev set wlan0 managed no
```

Make it persistent:

```bash
sudo tee /etc/NetworkManager/conf.d/unmanage-wlan0.conf << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF
```

---

### Step 3 — wlan0 Static IP Service

dhcpcd is not active by default on Bookworm/Trixie, so we use a systemd service to assign a static IP:

```bash
sudo tee /etc/systemd/system/routerpi-wlan0.service << 'EOF'
[Unit]
Description=Set static IP on wlan0
After=network.target
Before=hostapd.service dnsmasq.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/ip addr flush dev wlan0
ExecStart=/usr/sbin/ip addr add 192.168.4.1/24 dev wlan0
ExecStart=/usr/sbin/sysctl -w net.ipv4.ip_forward=1

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable routerpi-wlan0.service
```

---

### Step 4 — IP Forwarding (Persistent)

```bash
# Add to sysctl.conf
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# Extra safety: create a separate drop-in file
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-routerpi.conf

# Apply immediately
sudo sysctl -w net.ipv4.ip_forward=1
```

---

### Step 5 — hostapd (5GHz Access Point)

```bash
sudo tee /etc/hostapd/hostapd.conf << 'EOF'
interface=wlan0
driver=nl80211
ssid=RouterPi
hw_mode=a
channel=36
wmm_enabled=1
ieee80211n=1
ieee80211ac=1
ht_capab=[HT40+][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40]
vht_capab=[SHORT-GI-80]
vht_oper_chwidth=1
vht_oper_centr_freq_seg0_idx=42
country_code=TR
ieee80211d=1
auth_algs=1
wpa=2
wpa_passphrase=YOUR_PASSWORD_HERE
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
```

> ⚠️ **Important:** Change `wpa_passphrase` to your own password (minimum 8 characters).

> ⚠️ **Important:** Change `country_code` to your country's ISO code if you're not in Turkey.

> ⚠️ **Note:** The RPi 5's built-in WiFi chip does not support the `MAX-MPDU-11454` VHT capability. Only use `[SHORT-GI-80]` in the `vht_capab` line, otherwise hostapd will fail to start.

```bash
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
```

---

### Step 6 — dnsmasq (DHCP + DNS)

```bash
# Back up the default config
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak

sudo tee /etc/dnsmasq.conf << 'EOF'
interface=wlan0
bind-interfaces
dhcp-range=192.168.4.2,192.168.4.100,255.255.255.0,24h
server=127.0.0.1#5053
no-resolv
EOF
```

- `bind-interfaces` → listens on wlan0 only, prevents port 53 conflicts with systemd-resolved
- `no-resolv` → uses dnscrypt-proxy (port 5053) instead of `/etc/resolv.conf`

```bash
sudo systemctl enable dnsmasq
```

---

### Step 7 — dnscrypt-proxy (DNS-over-HTTPS)

Debian's dnscrypt-proxy package uses systemd socket activation which can cause issues. We create our own service:

```bash
# Disable Debian's own service/socket
sudo systemctl disable dnscrypt-proxy.service
sudo systemctl disable dnscrypt-proxy.socket
sudo systemctl mask dnscrypt-proxy.socket
```

Edit the config — find and change the `listen_addresses` and `server_names` lines:

```bash
sudo nano /etc/dnscrypt-proxy/dnscrypt-proxy.toml
```

```toml
listen_addresses = ['127.0.0.1:5053']
server_names = ['cloudflare', 'google']
```

Create required directories:

```bash
sudo mkdir -p /var/cache/dnscrypt-proxy /var/log/dnscrypt-proxy
```

Custom systemd service:

```bash
sudo tee /etc/systemd/system/dnscrypt-custom.service << 'EOF'
[Unit]
Description=DNSCrypt DoH Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable dnscrypt-custom
```

Point the Pi's own DNS to the DoH proxy:

```bash
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf
```

> `chattr +i` makes the file immutable so NetworkManager can't overwrite it.

---

### Step 8 — nftables (NAT Masquerade)

```bash
sudo tee /etc/nftables.conf << 'EOF'
#!/usr/sbin/nft -f
flush ruleset

table ip routerpi {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        oifname "eth0" masquerade
    }
    chain forward {
        type filter hook forward priority 0; policy accept;
    }
}
EOF

sudo systemctl enable nftables
```

> ⚠️ **Important:** Only put your own NAT rules in `nftables.conf`. Zapret adds its own mangle/filter rules at runtime. Do NOT save zapret's `xt match` rules here — they can't be parsed at boot and will crash the nftables service.

---

### Step 9 — Zapret (DPI Bypass)

```bash
cd ~
git clone --depth 1 https://github.com/bol-van/zapret.git
cd zapret
sudo ./install_easy.sh
```

Installation choices:

| Prompt | Choice | Explanation |
|--------|--------|-------------|
| Copy to /opt/zapret? | **Y** | Zapret only runs from /opt/zapret |
| Firewall | **iptables** | Compatible with nftables (iptables-nft backend) |
| IPv6 support | Your choice | |
| Filtering | **4 (autohostlist)** | Automatically detects blocked sites |
| tpws SOCKS mode | **N** | Not needed |
| tpws transparent mode | **N** | nfqws is sufficient |
| nfqws options | Accept defaults | Can be customized later |
| LAN interface | **wlan0** | Interface devices connect to |
| WAN interface | **eth0** | Internet uplink |
| Auto download list | **Y → default** | |

---

### Step 10 — Fan Configuration (Optional)

Recommended for 24/7 router operation:

```bash
sudo tee -a /boot/firmware/config.txt << 'EOF'

# RouterPi Fan Settings
dtparam=fan_temp0=45000
dtparam=fan_temp0_hyst=5000
dtparam=fan_temp0_speed=75
dtparam=fan_temp1=50000
dtparam=fan_temp1_hyst=5000
dtparam=fan_temp1_speed=125
dtparam=fan_temp2=55000
dtparam=fan_temp2_hyst=5000
dtparam=fan_temp2_speed=200
dtparam=fan_temp3=60000
dtparam=fan_temp3_hyst=5000
dtparam=fan_temp3_speed=255
EOF
```

Fan starts spinning at 45°C and runs at full speed at 60°C.

---

### Step 11 — Reboot and Verify

```bash
sudo reboot
```

After reboot, verify all services:

```bash
# All services should be active
sudo systemctl status hostapd dnsmasq dnscrypt-custom zapret nftables routerpi-wlan0

# IP forwarding enabled?
cat /proc/sys/net/ipv4/ip_forward
# Expected: 1

# wlan0 has static IP?
ip addr show wlan0
# Expected: inet 192.168.4.1/24

# NAT rule loaded?
sudo nft list table ip routerpi
# Expected: oifname "eth0" masquerade

# DNS-over-HTTPS working?
dig @127.0.0.1 -p 5053 pornhub.com
# Expected: Real IP (NOT the ISP block page IP)

# Internet works over Ethernet?
ping -c 3 1.1.1.1
```

Connect to the "RouterPi" network from your phone and verify internet access + blocked site access.

---

## ⚙️ Configuration

### Adding Blocked Sites (Manual)

Autohostlist automatically detects most blocked sites. For manual additions:

```bash
sudo nano /opt/zapret/ipset/zapret-hosts-user.txt
```

One domain per line:

```
pornhub.com
discord.com
youtube.com
```

```bash
sudo systemctl restart zapret
```

### WiFi Settings

```bash
sudo nano /etc/hostapd/hostapd.conf
```

| Parameter | Description |
|-----------|-------------|
| `ssid=` | Network name |
| `wpa_passphrase=` | WiFi password (min 8 characters) |
| `channel=` | WiFi channel (5GHz: 36, 40, 44, 48 — avoid DFS channels) |
| `country_code=` | Your country's ISO code |

```bash
sudo systemctl restart hostapd
```

### Customizing Zapret Parameters

```bash
sudo nano /opt/zapret/config
# Edit NFQWS_OPT lines
sudo systemctl restart zapret
```

Parameters that work well against Turkish ISP DPI:

```
--dpi-desync=fake,multisplit --dpi-desync-split-pos=method+2 --dpi-desync-fooling=md5sig --dpi-desync-ttl=3
--dpi-desync=fake,multidisorder --dpi-desync-split-pos=1,midsld --dpi-desync-fooling=badseq,md5sig --dpi-desync-ttl=3
```

### Viewing Autohostlist

```bash
cat /opt/zapret/ipset/zapret-hosts-auto.txt
```

---

## 🔍 Troubleshooting

### RouterPi network not visible

```bash
sudo systemctl status hostapd
journalctl -u hostapd -e --no-pager
```

Common causes:
- `VHT_CAP_MAX_MPDU_LENGTH_MASK` error → remove `[MAX-MPDU-11454]` from `vht_capab`
- wlan0 still managed by NetworkManager → redo Step 2

### Connects but can't get an IP

```bash
sudo systemctl status dnsmasq
journalctl -u dnsmasq -e --no-pager
ip addr show wlan0
```

Common causes:
- dnsmasq port 53 conflict → `bind-interfaces` missing from dnsmasq.conf
- No IP on wlan0 → check `routerpi-wlan0` service

### Connected but no internet

```bash
cat /proc/sys/net/ipv4/ip_forward    # Should be 1
sudo nft list table ip routerpi       # Should show masquerade rule
ip route show                         # Should show default via x.x.x.x dev eth0
```

Common causes:
- ip_forward disabled → `sudo sysctl -w net.ipv4.ip_forward=1`
- nftables rules not loaded → `sudo nft -f /etc/nftables.conf`

### Blocked sites still blocked

```bash
# DNS test
dig @127.0.0.1 -p 5053 <domain>
# If ISP block page IP is returned → DoH is not working

sudo systemctl status dnscrypt-custom
sudo systemctl status zapret
```

If DNS resolves correctly but the site is still blocked, add it to the manual list:

```bash
echo "domain.com" | sudo tee -a /opt/zapret/ipset/zapret-hosts-user.txt
sudo systemctl restart zapret
```

### No internet after reboot

```bash
sudo systemctl status nftables
```

Common cause: zapret's `xt match` rules were saved to `nftables.conf` → rewrite it with the clean version from Step 8

---

## 🧠 How It Works

### DNS Censorship Bypass

```
Normal:  Device → ISP DNS (port 53) → Block page IP (e.g. 195.175.254.2)
RouterPi: Device → dnsmasq → dnscrypt-proxy (DoH/HTTPS) → Cloudflare 1.1.1.1 → Real IP
```

The ISP intercepts DNS queries on port 53 and returns a block page IP. DNS-over-HTTPS sends queries encrypted over HTTPS — the ISP can't see or tamper with the content.

### DPI Censorship Bypass

```
Normal:  Device → TLS ClientHello (SNI: pornhub.com visible) → ISP DPI → BLOCKED
RouterPi: Device → nfqws (packet manipulation) → ISP DPI (can't read SNI) → PASS
```

Zapret/nfqws fragments TLS handshake packets (split/disorder), injects fake packets, and manipulates TTL values. The ISP's Deep Packet Inspection system can no longer read the SNI field.

### Autohostlist

Zapret automatically monitors connection failures. When a domain is blocked by DPI, zapret detects the failure pattern and adds it to `zapret-hosts-auto.txt`. Subsequent connections to that domain are automatically bypassed.

---

## 📊 Performance

| Metric | Value |
|--------|-------|
| WiFi Standard | 802.11ac (WiFi 5) |
| Max Link Speed | ~300 Mbps (AP mode) |
| Ping (typical) | ~9 ms |
| Jitter | ~5 ms |
| Download | ~32 Mbps (ISP dependent) |
| Upload | ~11 Mbps (ISP dependent) |

### PCVR / VR Streaming Notes

- Start with **50-80 Mbps** bitrate in Virtual Desktop / ALVR
- Keep the Pi close to the Quest (same room is ideal)
- 5GHz channel 36 is open and stable in Turkey
- Avoid DFS channels (52-144) — radar scanning can drop the connection

---

## 📁 File Structure

```
/etc/
├── hostapd/
│   └── hostapd.conf                    # WiFi AP configuration
├── dnsmasq.conf                         # DHCP + DNS configuration
├── dnscrypt-proxy/
│   └── dnscrypt-proxy.toml              # DoH proxy configuration
├── nftables.conf                        # NAT masquerade rules
├── resolv.conf                          # DNS (127.0.0.1, immutable)
├── sysctl.d/
│   └── 99-routerpi.conf                 # ip_forward=1
├── NetworkManager/conf.d/
│   └── unmanage-wlan0.conf              # wlan0 unmanaged by NM
└── systemd/system/
    ├── routerpi-wlan0.service           # wlan0 static IP
    └── dnscrypt-custom.service          # DoH proxy service

/opt/zapret/
├── config                               # Zapret main configuration
├── nfq/nfqws                           # DPI bypass binary
└── ipset/
    ├── zapret-hosts-user.txt            # Manual site list
    ├── zapret-hosts-auto.txt            # Auto-detected blocked sites
    └── zapret-hosts-user-exclude.txt    # Sites excluded from bypass

/boot/firmware/
└── config.txt                           # Fan settings
```

---

## 📜 License

MIT

## 🤝 Contributing

Pull requests and issues are welcome. Especially useful contributions:

- Working zapret parameters for different ISPs (not just Turkish ones)
- Test results on different RPi models
- WiFi 6 USB dongle compatibility reports
