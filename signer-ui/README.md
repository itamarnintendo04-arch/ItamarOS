# ItamarOS browser IPA signing

This is a **real local WebAssembly signing interface**, not a link-only button. It builds on the open-source [Sylva Signer](https://github.com/AntonP29/SylvaSigner) zsign WASM runtime at an explicitly pinned upstream commit. All IPA and signing inputs are handled by the worker in the visitor's browser. ItamarOS has no backend signing endpoint.

- The visitor must supply an app IPA they are authorized to sign, their valid Apple-issued PKCS#12 signing certificate, the certificate's password (if applicable), and a matching `.mobileprovision`.
- The certificate password refers to the **P12 certificate**, not their Apple ID account password.
- The form does not upload or persist any signing materials, nor does it bypass Apple provisioning, entitlements or trust checks.
- No shared/revoked third-party certificate or preselected dangerous payloads are offered.
- Successful signing means only that a signed IPA was generated. iPhone installation is a separate user-approved process, not automated by this website.
- Free Personal Team Apple IDs do not by themselves expose a P12/profile ready for browser signing. Users of the free account may need Apple's supported Xcode or an authorized personal development signing client.

## Build and deployment

On every relevant PR, `.github/workflows/browser-ipa-signer.yml` checks out the pinned Sylva source and compiles `signer-ui/index.html` and `signer-ui/itamaros-main.ts` against its `signIpa` API. It patches absolute worker asset paths to `/signer/wasm/`. The upstream React UI, analytics, certificate caching and remote hosting/installation flows are **not imported** into ItamarOS's new minimal frontend.

After a merge to `main`, the same workflow publishes the compiled `signer/` static directory back into this repository, including the WASM runtime and required third-party notices, so an existing static web host serves `/signer/`. Source compilation and a production static deployment must succeed before the link is usable.

The engine remains subject to MIT and third-party licenses. Preserve license files from the pinned upstream and inspect upstream security changes before deliberately upgrading the commit.

## Scope

An HTTPS web browser with WebAssembly, Web Workers and enough memory for the IPA is required. Some mobile browsers can run out of memory for large IPAs. Browser signing **does not** authenticate with Apple's developer portal and does not create provisioning profiles; it uses the user's existing legal signing credentials. Signed IPA installation is not implemented in the browser. Do not disable platform security safeguards.
