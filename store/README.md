# ItamarOS Store — installer metadata design

The browser Store currently links to official developer sites and saves suggestions locally. **No backend scanner has been deployed.**

## Proposed ingestion pipeline

1. Accept HTTPS installer URLs from trusted official publishers, with human review of user suggestions.
2. Download the actual EXE/MSI with strict size limits, timeouts, HTTPS validation, redirect checks, and private-network/SSRF protections.
3. Store downloads in isolated temporary storage; never execute untrusted installers during metadata extraction.
4. Compute SHA-256 and file size. Parse PE version resources, icons, publisher and Authenticode signatures for EXE, or MSI properties and embedded assets for MSI.
5. Look up languages and official age ratings from trustworthy publisher/catalog sources. **Do not invent an age rating or languages when the file does not provide them.**
6. Perform malware scanning and manual review before listing. A valid signature or antivirus scan is not proof of safety.
7. Persist metadata and update approved listings on a schedule; never auto-publish user-submitted binaries.
8. Serve metadata and approved download links via an authenticated API. Respect publishers' distribution rights and prefer linking to official downloads.

## Limitations

An EXE's resources may be missing, misleading or packed. The EXE may be a downloader rather than the full app. EXE/MSI files are Windows formats; the Linux desktop build would need a compatibility layer such as Wine, and compatibility is not guaranteed.

The web emulator cannot install or execute EXE/MSI files.
