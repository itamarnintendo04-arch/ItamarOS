# ItamarOS Installer — Windows 10/11

An ItamarOS-branded desktop catalog and iPhone IPA installer, built with Python and CustomTkinter and packaged as an EXE through GitHub Actions.

## Supported functions
- Automatic discovery of ItamarOS GitHub repositories and the latest published release for every iOS app; refreshes every five minutes.
- A new public repo with the topic itamaros-ios appears automatically; known iOS projects appear even before they publish an IPA.
- Download signed IPA assets from official repositories, check SHA-256 digest where provided, and validate IPA metadata and code-signature files.
- Find USB-connected iPhones through the device helper and Apple Mobile Device Service; select a device and install an already signed IPA.
- Specific error messages for USB cables, Trust requests, drivers, unsigned IPA files and provisioning.

## Required for installation
1. Windows 10/11, iTunes for Windows (Apple Mobile Device Support), and a USB-connected iPhone with Trust enabled.
2. The external device helper: run py -m pip install --user pymobiledevice3 in Windows Terminal and restart the app.
3. A properly signed IPA with provisioning valid for the connected device.

## Wi-Fi Companion — Windows Installer 2.2

1. Install the Windows EXE from the official Wi-Fi Installer GitHub Release.
2. For the initial device trust pairing, connect the iPhone to the computer with USB, unlock the phone and tap **Trust This Computer**.
3. In **Apple Devices for Windows** open your iPhone, choose the General tab, enable **Show this iPhone when on Wi-Fi**, then click **Apply**. If using the older iTunes app, choose the iPhone > Summary > **Sync with this iPhone over Wi-Fi**. These are Apple-specific pairing/device transport settings — they do not create the ItamarOS application server.
4. Connect Windows and iPhone to the same trusted private Wi-Fi network. Open **ItamarOS Installer → Wi-Fi Companion → Start secure Wi-Fi server**. Permit the app's Windows Firewall local/private network access when asked, but do not expose the port to the public internet.
5. In **ItamarOS Installer Mobile → Wi-Fi** (or an integrated non-game ItamarOS app's Settings), tap **Scan pairing QR from computer**. The QR contains a 10-minute, eight-digit pairing code and an ephemeral TLS certificate fingerprint. The first-party companion uses fingerprint-pinned HTTPS and Bonjour to discover this server. Private signing certificates and P12 passwords never travel over this server.
6. Select the iPhone detected by the computer. Choose an official app in the Wi-Fi companion and press **Install**. Confirm on the PC. The PC automatically resolves the official app's IPA from the main-repository registry and GitHub Release; no manual IPA browse/upload is needed. The server verifies its Bundle ID.
7. If the release IPA is unsigned, the request ends with **Signing required** and the PC saves the official IPA under Downloads. Sign it using your own authorized Apple-issued credentials and a matching provisioning profile. This tool does NOT automatically use the certificate saved on the iPhone for desktop signing.
8. Once a properly signed IPA is available, Apple's supported device installation helper may install it if it detects the paired device. On some iOS / Windows configurations Wi-Fi synchronization may be available but the third-party device helper may still need USB for installation; Wi-Fi Sync does not guarantee remote app installation.

**Security:** The companion server is off until the user enables it from the Windows app; it binds only as part of the active computer session and stops with the app. Tokens expire, pairing codes rotate, and individual requests must be approved on the Windows desktop. The server never exposes P12 files, passwords, local IPA file contents or arbitrary filesystem paths. Do not share the computer's pairing QR or join unknown Wi-Fi networks.

**Architecture:** `lan_bridge.py` provides temporary local TLS + Bonjour + pairing; `official_catalog.py` loads the official `catalog/ios-apps.json` and verified release files; `WiFiCompanion.swift` implements secure QR pairing and discovery on supported iOS apps. The Downloads website lists official GitHub Release IPA URLs and does not store any P12 certificate.

## Apple ID
Apple ID sign-in is NOT configured in this version. The app NEVER asks for Apple ID passwords. Official Sign in with Apple requires Apple Services ID and an ItamarOS server-side OAuth callback. Signing IPA files is separate from Apple account login. The app catalog works without Apple sign-in.

## New releases
On an official public repository in the itamarnintendo04-arch account, add the topic itamaros-ios and publish a versioned GitHub Release with a signed IPA. ItamarOS Installer will discover the app and its latest release automatically. Apps without installable IPAs are shown as not available.

## Build
GitHub → ItamarOS → Actions → Build ItamarOS Installer (Windows). The completed run contains the EXE artifact.

## Local
Install dependencies: python -m pip install -r requirements.txt
Run: python main.py
Tests: python -m unittest discover -s tests -v

Not affiliated with or endorsed by Apple.
