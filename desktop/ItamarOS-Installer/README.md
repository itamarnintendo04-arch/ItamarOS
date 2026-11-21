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


## ItamarOS Store 2.3 — Discover, Apps, Games, Updates, Library, Sources

The Windows installer has a native CustomTkinter store with app cards, source badges, search, individual app details, community source management, and automatic downloading of official iOS IPAs.

- **ItamarOS Official** is built in, cannot be deleted or disabled, and contains everyday apps (BrowserOS, ItamarCut, Voice Recorder, Screen Balance, Authenticator, Installer, ItamarOS) **and games**.
- Add community JSON catalogs via **Sources → Add HTTPS Community Source**; they are separate and clearly labeled *Community*, never *Official*. A source can be enabled, disabled or removed.
- **Apps** shows non-games. **Games** shows games. **Discover** shows both. **Library** contains downloaded IPAs. **Updates** shows previously downloaded entries for a manual release check, not a claim that the iPhone already installed them.
- Source JSON schema and example: `catalog/SOURCE_FORMAT.md` and `catalog/example-community-source.json`.
- Community sources are unverified. Downloads are limited, use public HTTPS, and check the IPA Bundle ID. This does **not** establish publisher trust or malware safety.
- The official first-party IPA is downloaded from `catalog/ios-apps.json` in GitHub Releases automatically; the user does not need to browse for an IPA in the store. Unsigned previews still require authorized Apple signing before installation.



## Desktop certificate sync (development)

The **Signing Certificates** screen in the desktop application imports an Apple-issued
P12 identity (password checked in memory, never stored), and optionally registers a
matching .mobileprovision file. It records public certificate metadata and local file
paths in the user's application-data folder. Removing a registration never deletes
the original certificate file.

After pairing via the existing private Wi-Fi QR/TLS companion, the iPhone can request
`GET /v1/certificates` and select an available identity. The iPhone receives only
ID, public certificate subject, expiration and availability/profile flags. It sends
the chosen ID with a normal install request. The desktop rejects invalid/unavailable
identity IDs and still requires explicit approval for installation.

**Not yet implemented:** automatic IPA re-signing using a registered P12, real
Apple Developer account sign-in, cloud-mediated background connectivity, and
guaranteed Wi-Fi installation. The existing helper can install *already-signed*
and properly provisioned IPAs when it detects the paired iPhone. Apple Devices /
iTunes Wi-Fi Sync alone does not guarantee that helper connection.

Older iPhone-local certificates are not migrated, uploaded or synchronized.
Keep your original files safely backed up and do not expose P12 credentials to a
website or third-party source.

## iPhone app prerequisite (November 21 update)

The companion Store and its **Installed** tab are features of the separately installed **ItamarOS Installer Mobile** iPhone app. A correctly signed, provisioned initial installation of that iPhone IPA is required before using mobile-triggered installs. Once paired, the iPhone requests an installation from this Windows application. Only a successful desktop installation report unlocks the Installed tab; it does not enumerate installed iOS apps.

Current automated CI produces a Windows EXE and an **unsigned** iPhone IPA. Certificate import/metadata sync does not yet auto-sign arbitrary IPAs. If Wi-Fi device detection or an Apple signing check fails, the app displays an error instead of reporting success.
