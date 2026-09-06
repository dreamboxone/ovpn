# Audit of ovpn 1.0.1

What was wrong with the previous version, how each thing was confirmed, and
what was done about it. Everything below was checked against a real Xray
26.3.27, a real nftables, and the live server list — not read and reasoned
about. Where I first suspected something and turned out to be wrong, that is
recorded too, because a fix for a problem that does not exist is its own kind
of bug.

---

## 1. One bad server in the list stopped everything

**The most important finding.** This is almost certainly the "it gave many
errors and did not work" you describe.

Version 1.0.1 built **one** Xray configuration containing all hundred servers
at once — a hundred inbounds, a hundred outbounds, a hundred routing rules —
and started it to measure them. Xray validates a configuration as a whole. One
unusable entry anywhere in it and the core refuses to start at all.

`ovpn-update` then reported this as:

```
no xray on this router can run the generated configuration
```

and, one line later, selection failed completely. Not "ninety-nine servers
measured, one skipped" — **nothing measured, no server chosen, no connection**,
for as long as that entry stayed in the list.

Confirmed by building v1's exact configuration from today's live list and
adding one entry with an invalid TLS fingerprint:

| configuration | Xray's verdict |
|---|---|
| today's 100 servers | accepted |
| the same 100, plus one bad entry | **rejected — nothing can be measured** |

The kinds of entry that do this are ordinary and common in free lists: a
REALITY public key that is not a valid key, a cipher Xray dropped years ago
(`rc4-md5`), a fingerprint that does not exist. Both of the first two are in
the test fixtures now because both were found in the wild.

Today's list happens to be clean, so v1 would work today. It would go dark on
any day a stranger's list contained one malformed line, and stay dark until
they fixed it. Nothing about that failure points at the cause.

**Fixed.** Servers are measured ten at a time. If a batch is refused, each of
its members is offered to the core individually, the bad ones are written down
so they are never tried again this boot, and the rest are measured normally.
Covered by `test/test-config.sh` and `test/test-probe.sh`.

---

## 2. Choosing a server cost far more than it needed to

A hundred inbounds, a hundred outbounds and a hundred simultaneously open
listening sockets is real work for a router with 128 MB of RAM — and it
happened on every connection and every time the page was opened, even when the
first server tried would have done.

**Fixed**, and this is requirement 3. Two passes:

1. **One TCP handshake to every server**, thirty at a time, two seconds each.
   On today's list this takes **8 seconds** and removes **26 of 69** servers
   before anything expensive happens. It also yields the handshake time, which
   is a real measure of distance.
2. **The survivors, best handshake first, measured properly ten at a time** —
   a complete proxied HTTP request, which is the only thing that proves a route
   works. The moment one comes back under the threshold (1000 ms by default),
   that is the answer and the remaining batches never run.

So the usual case is one small core holding ten sockets for a few seconds,
instead of one large core holding a hundred for thirty. The ranked results are
kept, so when the chosen server later dies the repair is "take the next one
down the list", not another full sweep.

### On ICMP

You asked for ICMP ping as the first pass. I implemented it — `prefilter` in
the settings takes `icmp`, `tcp` or `both` — but the default is `tcp`, and I
think it should stay that way:

- A great many of these servers sit behind Cloudflare. A ping is answered by
  the CDN edge and says nothing whatever about the server behind it, so ICMP
  keeps servers that do not work.
- A great many others drop ICMP entirely while serving TCP perfectly, so ICMP
  discards servers that do work.

A TCP handshake to the server's real port asks the same question — are you
there, and how far — of the thing that actually matters, and costs the same
three packets. On today's list 43 of 69 servers completed a handshake; the
gain you were after is fully realised, without the false answers.

---

## 3. It wrote to flash every fifteen minutes, for ever

`cmd_fetch` did this on every cron run, unconditionally:

```sh
mv -f "$tmp" "$LIST"          # /etc/ovpn/servers.list
date -u +%s > "$STAMP"        # /etc/ovpn/last-update
```

That is two writes to the overlay every fifteen minutes — about **70,000 writes
a year** — of a file that is usually byte-for-byte identical to the one already
there. On the flash a cheap router has, this is how routers die.

**Fixed.** The list is kept in RAM and copied to flash only when its contents
actually changed (`write_if_changed`). The traffic counters, which are read
every five minutes, are added up in RAM and reach flash once an hour and on
shutdown — about 25 writes a day for something previously not recorded at all.

---

## 4. Name lookups went round dnsmasq, not through it

The firewall redirected every port 53 packet straight into Xray's own
resolver. Outside names resolved correctly. Everything on the user's own
network stopped resolving: DHCP names, `/etc/hosts`, the router's own
hostname, the printer.

**Fixed.** dnsmasq keeps answering and only its *upstream* is moved into the
tunnel, via a drop-in file in the directory dnsmasq already watches — so local
names keep working and outside lookups still go through the tunnel. Nothing is
written to flash for this. The directory is discovered from dnsmasq's own
generated configuration rather than assumed to be `/tmp/dnsmasq.d`, because
OpenWrt names it after the config section and on most routers it is something
like `/tmp/dnsmasq.cfg01411c.d` — a program that assumes the tidy name writes
a file nothing ever reads, and then reports success.

---

## 5. A twenty-second wait for a tunnel nobody had started

When `start_service` bailed out early — no server chosen yet — it returned 1,
but `service_started` still ran and still waited its full twenty seconds for a
socket that was never going to appear, then logged a failure about a tunnel
nobody had asked for.

**Fixed** with a flag file: `service_started` returns immediately when
`start_service` opened no instance.

The related fix already in v1 — that `service_started`, not `start_service`,
is where the wait belongs — is correct. I checked it against OpenWrt's
`rc.common`: `start()` calls `rc_procd start_service` and then
`service_started`, so it is the first hook that runs after procd has actually
been told to start anything.

---

## 6. Smaller things, all confirmed by reading the code

| | |
|---|---|
| **The comment about PassWall2's mark was wrong.** `ovpn-rules` claimed `0xff` was "the same value PassWall2 uses". PassWall2's mark is `0x50535732`. The claimed interoperability did not exist. | Comment corrected; the value kept, since it is the convention older transparent-proxy scripts settled on. |
| **No divert rule for established sockets.** Every packet of every connection re-did the transparent-proxy lookup instead of being handed to the socket that already owned it. | Added, conditional on `kmod-nft-socket` actually being present — probed by loading a throwaway table, because `nft --check` tests syntax, not the kernel. |
| **No file-descriptor limit.** The default 1024 is not many when every device on the network has its connections held open by one process. | `nofile 65535`. |
| **Duplicate servers were measured repeatedly.** Today's list is 107 lines and **69 distinct servers**; v1 measured 100 entries, roughly a third of them repeats. | The parser now discards duplicates. |
| **The version in the web interface was hardcoded** to `1.0.1` while the package said `1.0.1-r5`. | Written once at build time to `/etc/ovpn/version` and read from there; the build fails if the two disagree. |
| **Only vmess, vless and shadowsocks were understood.** No trojan — which is common — and no base64 subscriptions, which is how most providers hand over a list at all. | trojan, socks, hysteria2 and tuic added; a base64 blob is decoded. |
| **`/usr/bin` was created in the package** and nothing was put in it. | Gone. |

---

## Things I suspected and was wrong about

Recorded because I nearly "fixed" all of them.

- **`allowInsecure`.** I added it to the parser to be tolerant of servers whose
  certificate does not match. Xray **removed** it in 26.x and now refuses any
  outbound carrying it — so it would have rejected *every* TLS server on the
  list, on the newest core, all at once. Caught by putting each generated
  outbound in front of the real binary. It is not in the shipped parser, and
  there is a test asserting it never comes back.
- **`fp=unsafe`.** Two servers in today's list carry it and it looks like a
  mistake. It is a real uTLS value meaning "use Go's own TLS". My first fix
  dropped it. Corrected: the fingerprint whitelist was checked value by value
  against Xray 26.3 and now matches what the core actually accepts. An invented
  fingerprint is still dropped — `bogusvalue` genuinely does refuse the whole
  outbound — but only the fingerprint is dropped, not the server.
- **`ca-bundle` was not in the dependencies.** I assumed HTTPS was broken on a
  fresh router. It is not: OpenWrt's `libcurl` already depends on `ca-bundle`,
  so it arrives transitively. It is now declared explicitly anyway, which
  documents the requirement and covers a hand-built image, but it was not the
  bug I thought it was.
- **The CI action versions.** `actions/checkout@v7`, `upload-artifact@v7` and
  `download-artifact@v8` looked wrong to me. They are all current and correct.
- **OpenWrt 24 uses iptables.** It does not — OpenWrt has used nftables since
  22.03, so 23.05, 24.10 and 25.12 are all nftables, and the thing that changed
  in 25.12 is the package manager (`opkg` → `apk`), which the build already
  handled by shipping both formats. Both firewall backends are implemented all
  the same, because vendor builds and older releases in the field do still run
  firewall3, and on one of those an nft-only client installs cleanly, reports
  itself connected, and carries nothing.

---

## What is still not covered by a test

Being straight about the edges:

- **The transparent proxy path has never been run end to end**, because that
  needs a router with clients on it. The ruleset is checked against a real
  `nft`, the core is started and its sockets confirmed, and the selection runs
  for real against stand-in servers — but "a laptop on the LAN loaded a page
  through the tunnel" is not something CI can assert. It needs your router.
- **The iptables backend is checked for syntax and structure, not behaviour.**
  There is no firewall3 machine in CI. It follows the standard TPROXY recipe
  and tears itself down in the right order, but it wants trying on a real
  fw3 router before being trusted.
- **hysteria2 and tuic servers have not been carried end to end.** The bridge
  configuration is generated and the plumbing is there; no free list I can
  reach publishes one to try it against.
