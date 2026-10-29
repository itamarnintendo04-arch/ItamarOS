# ItamarOS desktop demo security: antivirus alert under investigation

**Status: Windows EXE distribution is paused while an Avast malware detection report is investigated.**

A user reported that **Avast Antivirus identified an ItamarOS Windows desktop demo executable as malicious**. The precise filename, SHA-256, alert ID and detection name are not available yet, so the issue cannot currently be classified as a false positive or confirmed malware. Do **not** run, restore, whitelist or exclude any blocked file, and do **not** disable antivirus protections.

## Next checks for maintainers

1. Record the **exact filename**, Avast **detection name / alert ID**, exact URL used for download, and SHA-256 computed on the downloaded file. These data identify which release/build triggered the warning.
2. Confirm the file actually originated from the intended official GitHub Release, not an altered third-party mirror. A checksum matching a release does not prove it is safe.
3. Review the exact source and locked dependencies used to build the detected binary, build workflow logs, Electron sandboxing, auto-update behavior, and installer behavior.
4. Independently scan the actual artifact with multiple current reputable engines and examine findings. Never dismiss a positive detection solely because other scanners do not report it. Do not upload sensitive data or personal files.
5. Fix any reproducible malicious or suspicious behavior, and **sign** future Windows packages using an authorized publisher's code-signing certificate if possible. Signing alone is not a safety guarantee.
6. Only after independent checks suggest a mistaken detection may the publisher report a potential **false positive** with the sample and evidence to [Avast's official submission form](https://support.avast.com/article/258/).
7. Keep the demo EXE download on hold until a release has passed security review. The browser demo remains available without a Windows executable.

## Build and release policy

- The `desktop-app` GitHub Actions workflow may create **test artifacts with SHA-256 checksums**, but must **not auto-publish unsigned EXE binaries** as public GitHub Releases.
- No automatic file installation, antivirus bypass, automatic allowlisting, UAC bypass or signing check circumvention is permitted.
- Existing historic release assets are not automatically verified and may still be reachable on GitHub. The official downloads page should not present them as safe executable downloads.
- A production downloadable binary should have a documented source commit, publisher identity, reproducible build inputs, independent review, published checksums and an authentic signature when available. Antivirus still may report legitimate or malicious software despite these steps.

## If you already downloaded the file

Leave it quarantined, and do not attempt to bypass the security warning. Share only the alert text / detection name and filename with the maintainer, not private files or passwords.
