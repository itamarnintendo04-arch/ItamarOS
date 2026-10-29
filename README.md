# ItamarOS

Experimental operating-system project and limited browser emulator.

## Web emulator
[Open ItamarOS](https://itamaros-web-emulator.onrender.com/) · [View GitHub source](https://github.com/itamarnintendo04-arch/ItamarOS) · [Official downloads](https://itamaros-web-emulator.onrender.com/downloads.html)

The `index.html` page runs locally or on Render as a static site. Files and notes persist in browser localStorage, not on a cloud server. It is a simulation, **not** a bootable OS.

The emulator includes built-in **ItamarOS Player**, **ItamarOS Games** (10 mini-games), **Itamio** (YouTube video launcher) and **Settings → Software Updates**. Ten browser games save scores and progress locally; the player includes browser-supported media controls and a [feature-by-feature VLC comparison](PLAYER_FEATURES.md).

ItamarOS publishes browser updates using the [updates branch workflow](updates/README.md): develop on `updates`, merge to `main`, and let Render deploy the new version. A GitHub version manifest drives update checks and safe automatic reloads. Native OS/app installers are not yet implemented.

The emulator includes a built-in **GitHub** app for browsing project source files and any real release assets. The downloads page queries GitHub Releases and only shows attached assets actually published. **No native installer releases are currently published.**

## Installation
[Read installation status and safety guidance](INSTALLATION.md). The `setup.html` page is a demonstration only and makes no disk changes.

## Full desktop OS
A separate [native Debian/KDE live ISO source recipe](native/README.md) is in development for ItamarOS Linux v1.1. A tested downloadable ISO is not published yet. The browser demo does not install Windows applications, create a 20GB virtual disk, or replace Windows. Mobile and TV OS installers are not yet available. A [portable Windows desktop emulator](desktop-app/README.md) has a separate CI build and may appear in GitHub Releases as an unsigned demo. Do not use an untested installer on a physical disk.

## Render
Static site: publish path `.`; build command `echo ready`.
