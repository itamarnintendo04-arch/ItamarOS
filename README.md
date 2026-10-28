# ItamarOS

Experimental operating-system project and limited browser emulator.

## Web emulator
[Open ItamarOS](https://itamaros-web-emulator.onrender.com/) · [View GitHub source](https://github.com/itamarnintendo04-arch/ItamarOS) · [Official downloads](https://itamaros-web-emulator.onrender.com/downloads.html)

The `index.html` page runs locally or on Render as a static site. Files and notes persist in browser localStorage, not on a cloud server. It is a simulation, **not** a bootable OS.

The emulator includes a built-in **GitHub** app for browsing project source files and any real release assets. The downloads page queries GitHub Releases and only shows attached assets actually published. **No native installer releases are currently published.**

## Installation
[Read installation status and safety guidance](INSTALLATION.md). The `setup.html` page is a demonstration only and makes no disk changes.

## Full desktop OS
A separate Debian/KDE-based ISO build is planned. The browser demo does not install Windows applications, create a 20GB virtual disk, or replace Windows. Mobile and TV installers are not yet available. Do not use an untested installer on a physical disk.

## Render
Static site: publish path `.`; build command `echo ready`.
