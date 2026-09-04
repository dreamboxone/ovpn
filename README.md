# ovpn — a router-wide tunnel for OpenWrt

**Version 1.0.0** · support / contact: [t.me/routekernel1](https://t.me/routekernel1)
🇮🇷 **[راهنمای فارسی: README.fa.md](README.fa.md)**

Install it, press **Connect**, and every device on your network goes through
the tunnel. No settings on your phone, no settings on your laptop, no
subscription to paste in.

The router keeps a list of servers, refreshes it once a day, and measures
them. Not a ping — a complete web request through each server, timed from
start to finish. A server can answer a ping in 30 ms and still be unusable;
only a request that finishes proves the route works. The fastest server wins,
and that is the one you get.

Built on [Xray](https://github.com/XTLS/Xray-core). It does not need PassWall2
or any other package, and it does not touch their settings.

Developed on **OpenWrt 25.12**, target `ipq40xx/chromium`, architecture
`arm_cortex-a7_neon-vfpv4`. Releases also carry `.ipk` packages for **24.10
and 23.05**, across four architectures.

---

## 1. Install

Releases ship both package formats, because OpenWrt changed package manager in
25.12. Take the pair that matches your router:

| Your OpenWrt | Package manager | Files to download |
|---|---|---|
| 25.12 and later | `apk` | `ovpn-<version>.<arch>.apk` and `luci-app-ovpn-<version>.apk` |
| 24.10, 23.05 | `opkg` | `ovpn_<version>_<arch>.ipk` and `luci-app-ovpn_<version>_all.ipk` |

Your architecture is `DISTRIB_ARCH` in `/etc/openwrt_release` (on 23.05 and
24.10, `opkg print-architecture` prints it too). The `luci-app-ovpn` package
fits every router.

**OpenWrt 25.12 and later:**

```sh
scp ovpn-*.apk luci-app-ovpn-*.apk root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'apk add --allow-untrusted /tmp/ovpn-*.apk /tmp/luci-app-ovpn-*.apk'
```

**OpenWrt 24.10 and 23.05:**

```sh
scp ovpn_*.ipk luci-app-ovpn_*.ipk root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'opkg update && opkg install /tmp/ovpn_*.ipk /tmp/luci-app-ovpn_*.ipk'
```

**The router needs working internet while you install.** Three things ovpn
relies on are not part of a stock OpenWrt image — `kmod-nft-tproxy`, `curl`
and `ip-full` — and the package manager fetches them from the OpenWrt
repository as it installs. Do this step on a connection that works, before
you need the tunnel.

Then open LuCI → **Services → ovpn**.

Nothing runs after installation. The tunnel stays off until you press
**Connect** — you decide when the router starts tunnelling.

---

## 2. Using it

The page has two buttons and three lines.

| | |
|---|---|
| **Connect** | Picks the fastest server and sends every LAN device through it. |
| **Disconnect** | Stops the tunnel. Your network goes back to normal immediately. |

| Line | Meaning |
|---|---|
| **Status** | `Disconnected` · `Connecting…` · `Connected` |
| **Server** | Which country the traffic comes out in |
| **Latency** | How long a full web request took through that server when it was measured |

The first **Connect** takes longer than the ones after it: the router is
measuring every server before choosing. After that the choice is already made
and connecting is quick.

Once connected, every device on the network is tunnelled — phones, laptops,
televisions, consoles. None of them need to be configured, and nothing needs
to be installed on them.

The router's own traffic is deliberately left alone. That is what keeps the
tunnel able to reach its own servers.

---

## 3. Uninstall

```sh
ssh root@192.168.1.1
/etc/init.d/ovpn stop
apk del luci-app-ovpn ovpn          # opkg remove ... on 24.10 and older
```

That removes the service, the Xray core and the web page, and takes the daily
refresh out of the router's schedule.

Removing the packages leaves your settings behind on purpose, so reinstalling
picks up where you left off. To erase those too:

```sh
rm -rf /etc/config/ovpn /etc/ovpn
```

Nothing else on the router is touched — no firewall zone, no other package's
configuration. The routing rules exist only while the tunnel is up and go away
when you press **Disconnect** or stop the service.

---

## 4. If something does not work

**The page says `Connecting…` and stays there.** No server answered a test
request. That usually means the connection the router itself has is blocking
everything; the daily refresh at 21:00 will try a new list, or press
**Disconnect** and **Connect** to measure again straight away.

**Some devices are not tunnelled.** Only devices on the router's LAN go
through it. A device on a guest network or a second router of its own will
not.

**It was working and stopped.** Servers on a free list come and go. Press
**Disconnect** then **Connect**: the router measures again and moves to
whichever server is fastest now.

Support and contact: [t.me/routekernel1](https://t.me/routekernel1)

---

## 5. Licence

GPL-3.0-only. Xray-core is licensed by its own authors under MPL-2.0.
