# Linux-Mint-ESM-Security-App-Updates
Get the top 5 Ubuntu Pro ESM App Security Updates in Linux Mint
# Local builds for five image and media tools on Linux Mint

Mint (and Ubuntu) freeze a lot of software for years. That is the point of an LTS. For some programs the freeze also means security fixes stop arriving through the normal updater. Ubuntu Pro often provides the latest security builds of certain apps only to their "pro" subscribers. That can be a problem for heavily used apps and formats like ImageMagick, FFmpeg, Exiv2, libheif (format), and LibRaw.

The idea is that you can get up-to or better app updates than Ubuntu Pro releases for Ubuntu dependent distros like Linux Mint.

This script compiles five of the top "Ubuntu Pro" apps and installs them in `/opt/local-security`, and tells `apt` to leave the distro copies alone.

## Why these five

They all read files you did not create. A bad JPEG, a bad video, a camera RAW, a HEIC from a phone, or a PDF-turned-image can hit a decoder bug. Those bugs are not theoretical; they show up as CVEs every few months. The theory here is that Ubuntu and evrything downstream ignores the CVE's on important, high usage software. 

"I want different apps to be updated!" Just look at what updated apps "Ubuntu Pro" provides and then use this script as framework for updating other apps. I was just really motivated to get an updated ImageMagick, your needs may be different.

| Program | What it is for |
|---|---|
| **ImageMagick** | Convert, resize, and inspect images. Thumbnailers and scripts call it a lot. |
| **FFmpeg** | Decode and encode video and audio. |
| **Exiv2** | Read and write photo metadata (EXIF/IPTC/XMP). |
| **libheif** | HEIC and AVIF, the formats phones actually produce now. |
| **LibRaw** | Camera RAW files (CR2, NEF, ARW, and so on). |

If you never run these tools yourself, something else on the machine still might: a photo manager, a “convert this upload” script, a batch resize, a media converter. ImageMagick gets used by many other apps.

## Why Mint will not just update them

On Ubuntu, packages sit in **Main** or **Universe**.

- **Main** gets five years of security updates from Canonical on an LTS, no subscription.
- **Universe** is everything else. Canonical does not promise those updates unless you attach **Ubuntu Pro** (ESM Apps). The patched packages then come from `esm.ubuntu.com`, not from the public archive.

ImageMagick, FFmpeg, Exiv2, libheif, and LibRaw are in Universe on Ubuntu 24.04, which is what Mint 22 is built on. Mint points `apt` at Ubuntu’s public archives. It does not ship Ubuntu Pro, and Canonical does not support Pro on Mint.

So the copy Mint installed is the version from 2024 (or whenever that LTS froze), plus whatever rare community upload happened to land. Canonical may have a patched build. It lives behind a token Mint does not use.

Ubuntu Pro also does not give you a new major version. On 24.04 their ImageMagick is still 6.9.12 with extra patches glued on. The script below installs current upstream instead, which is newer than that.

## What the script actually does

`mint-local-security.sh` is not a secret mirror of Ubuntu Pro. It does the same kind of work a distro packager does, locally:

1. Installs compilers and `-dev` libraries with `apt`.
2. Clones a **pinned** upstream tag for each project (not “whatever is on main today”).
3. Builds with `--prefix=/opt/local-security`.
4. Puts `/opt/local-security/bin` first on `PATH` via `/etc/profile.d/local-security.sh`.
5. Registers `/opt/local-security/lib` with the dynamic linker.
6. Holds the matching Ubuntu package names and pins them at priority `-1`, so `apt upgrade` will not install or refresh those names.

Pinned versions right now:

- ImageMagick `7.1.2-30`
- FFmpeg `n9.0.1`
- Exiv2 `v0.28.8`
- libheif `v1.23.2`
- LibRaw `0.22.2`

Those numbers live at the top of the script. Change a tag and run the script again to rebuild that component.

The first run takes a while. FFmpeg and ImageMagick are large compiles. Later runs skip a tool if the recorded tag already matches.

## What it does not do

Programs Mint already installed that **link** Ubuntu’s libraries keep using Ubuntu’s libraries. Pix, xviewer, PHP’s Imagick module, Darktable talking to `libraw.so` in `/usr/lib` — those processes do not magically switch to `/opt`. Only commands you run that resolve to `/opt/local-security/bin/...` use the new builds.

If you need those desktop apps on the same code, that is a separate rebuild of each app. This script does not do that.

## Install

You need a working network, several gigabytes free, and root.

```bash
chmod +x mint-local-security.sh undo-mint-local-security.sh
sudo ./mint-local-security.sh
```

When it finishes, open a new terminal (or `source /etc/profile.d/local-security.sh`) and check:

```bash
sudo ./mint-local-security.sh status
which magick ffmpeg exiv2 heif-dec raw-identify
magick -version
ffmpeg -version
```

`which` should show `/opt/local-security/bin/...`.

## Day to day

Use the tools as usual (`magick`, `ffmpeg`, `exiv2`, `heif-dec`, `raw-identify`, `simple_dcraw`). Update Manager will skip the held package names. Other Mint updates will continue as normal.

To move to a newer upstream release later, edit the tag at the top of `mint-local-security.sh` and run `sudo ./mint-local-security.sh` again.

## Undo

```bash
sudo ./undo-mint-local-security.sh
```

That script:

- deletes the apt pin file
- `apt-mark unhold` on the five tools
- removes `/etc/profile.d/local-security.sh`
- removes `/etc/ld.so.conf.d/local-security.conf` and runs `ldconfig`
- deletes `/opt/local-security`

It does not uninstall Mint’s original packages. After a new terminal session, `which magick` is the distro binary again (if it was installed), and `apt` is allowed to touch those names.

`sudo ./mint-local-security.sh uninstall` does the same work if you only have the installer.

## Files

- [mint-local-security.sh](mint-local-security.sh) — build, install, hold
- [undo-mint-local-security.sh](undo-mint-local-security.sh) — reverse it
