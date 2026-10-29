# ItamarOS TV Streaming: TV-only app launcher

This is a TV-specific feature of the ItamarOS demo. It is not shown on desktop, laptop, phones or tablets.

## Country detection

The application automatically **estimates the country** using `Intl.DateTimeFormat().resolvedOptions().timeZone`, then `navigator.languages` region fallback. For example, `Asia/Jerusalem` is treated as Israel. No precise location, GPS permission, external IP geolocation provider or location upload is required.

**Limitations:** A time zone may span multiple countries and may be set manually. Browser language may reflect a different country than actual location. The UI always shows the detection method and allows correcting the country manually. The list is a **regional suggestion**, not proof the streaming service is available or licensed for a particular location/device.

## Native app launching

The code attempts to launch the **installed TV application** only through vendor-approved APIs when available. A normal website cannot detect or open every application installed on the television. Never claim a native app opened unless the operating system returned success.

| TV host environment | Integration | Status |
| --- | --- | --- |
| Samsung Tizen **installed TV app** | `tizen.application.launch(applicationId)` | Implemented in `apps/tv-streaming.js` where a candidate app ID is available. IDs vary by TV year/model and may fail. |
| LG webOS **installed TV app** | `webOS.service.request('luna://com.webos.applicationManager', {method:'launch', parameters:{id}})` | Implemented when platform API and application ID exist. Permission and app installation required. |
| Android TV **native wrapper** | Explicit optional host bridge `ItamarOSTVNative.launchApp(packageName)` | JavaScript integration point only. Android TV APK and native bridge **not yet created**; no arbitrary installed-app access from an ordinary website. |
| Ordinary TV browser | No privileged application manager | Buttons explain that apps must be opened from TV Home/App Store. **No automatic website redirect**. |
| Desktop, phone, tablet | No streaming app | Hidden and blocked by UI and launcher. |

Some candidate Samsung/webOS app IDs in the module are documented by community projects and **are not guarantees** across model years. Only verified IDs are used as launch candidates, and failures are surfaced. Apps like yes+, HOT, כאן BOX and Apple TV deliberately have no unverified native IDs.

The application makes no claim of affiliation with Netflix, Disney, Apple, Google, yes, HOT or Kan. It does not bypass app-store restrictions, subscriptions, DRM, geographical blocks or content protections.

Official platform resources:
- [Samsung Tizen application API](https://developer.samsung.com/smarttv/develop/api-references/tizen-web-device-api-references/application-api.html)
- [LG webOS Application Manager](https://webostv.developer.lge.com/develop/references/application-manager)
- [Android TV app launch activity](https://developer.android.com/training/tv/get-started/create)

## Testing

The `tests/tv-streaming.cjs` test validates timezone detection, country-specific service filtering, and platform launcher calls. Real-world native opening still requires testing on physical TVs with permitted app IDs.
