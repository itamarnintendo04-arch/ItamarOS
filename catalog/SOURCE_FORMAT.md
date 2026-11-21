# ItamarOS Store — Community Source JSON format

Official ItamarOS source: `https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/catalog/ios-apps.json`.

**The official source is built in and cannot be removed or impersonated. It includes ALL first-party iOS apps: games, BrowserOS, Screen Balance, ItamarCut, Voice Recorder, ItamarOS Authenticator, and ItamarOS Installer.**

To add a third-party source, host a JSON document over public **HTTPS**, with a content length below 450 KB, using the schema below. Sources are opt-in and **not verified or endorsed** by ItamarOS. The importer performs field, URL, extension and Bundle ID checks, but these checks **do not prove that a third-party IPA is trustworthy**.

```json
{
  "schema_version": 1,
  "name": "Example Community Source",
  "apps": [
    {
      "id": "example-notes",
      "name": "Example Notes",
      "description": "Example listing. Replace with your own signed or unsigned iPhone app.",
      "category": "Productivity",
      "bundle_id": "com.example.notes",
      "version": "1.0.0",
      "developer": "Example Developer",
      "icon_url": "https://example.com/assets/notes-icon.png",
      "screenshots": [
        "https://example.com/assets/notes-screen.png"
      ],
      "download_url": "https://example.com/releases/ExampleNotes.ipa",
      "release_url": "https://example.com/releases/1.0",
      "requires_signing": true
    }
  ]
}
```

Required top-level fields: `schema_version` set to `1`, `apps` (array of at most 200 entries). Optional: `name` (source display name).

Required app fields: `id`, `name`, `description`, `category`, `bundle_id`, and `download_url` (public HTTPS URL ending in `.ipa`). Optional: `version`, `developer`, `icon_url`, `screenshots` (up to 6 public HTTPS image URLs), `release_url`, `requires_signing`.

The official registry has a separate trusted format using `release_tag` and `asset_name`; those become GitHub Release URLs **only for the immutable built-in official source**. Community sources cannot become official by setting a JSON field.

Download behavior: manual user approval, HTTPS only, limited size, IPA structure and expected Bundle ID checks, and export of the downloaded file. A user-provided P12/password is **never** posted to community source servers. An unsigned IPA requires an authorized Apple certificate and matching provisioning. On iPhone, downloading or signing an IPA does not install it. Use Apple-approved distribution or a supported paired device installer. There is no automatic silent install, sideload trust bypass, or promise that an arbitrary source is safe.

**Windows**: Add sources under Sources → Add Source. Their lists are separately labeled Community and cannot overwrite official app IDs. **iPhone**: Store → Sources → Add Community Source. Sources are saved locally per device.
