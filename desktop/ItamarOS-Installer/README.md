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
