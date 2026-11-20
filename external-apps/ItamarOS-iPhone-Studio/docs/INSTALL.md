# Installing the iOS app

GitHub Actions builds an **unsigned IPA**. It cannot be installed directly on a stock iPhone.

To install, sign the IPA using an authorized Apple development account and a compatible signing/install workflow, or build and run from Xcode with a personal team. Never upload Apple ID passwords to GitHub secrets or third-party signing sites.

The app exports an icon image for an Apple Shortcuts Home Screen shortcut. It cannot directly change other apps' installed labels/icons. A SpringBoard tweak is a separate, unimplemented component requiring a verified compatible jailbreak.

Before any device modification, complete and verify an iCloud backup.
