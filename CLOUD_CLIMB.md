# Cloud Climb — development preview

Cloud Climb is an original platform-adventure prototype available inside ItamarOS and as a separate mobile app. It does **not** contain Crossy Road Castle code, artwork or sounds.

## Artwork and standalone app icons

- [Cloud Climb illustrated cover](assets/branding/cloud-climb-cover.svg) appears on the secret-game entry and downloads page.
- [Cloud Climb vector icon](assets/branding/cloud-climb-icon.svg) is the master icon asset.
- Android uses a dedicated Cloud Climb vector launcher drawable rather than the ItamarOS app logo.
- The standalone iOS build renders a 1024x1024 PNG app icon from the vector graphic before compiling; the IPA still requires valid signing.

## Standalone welcome screen and font

- Android and iPhone standalone apps present a Cloud Climb sky-and-cloud welcome screen with the title **Cloud Climb By ItamarOS** in the bundled **Fredoka** display font, a prominent **Sign in with ItamarOS** action, and a separate **Play Offline Demo** action.
- The ItamarOS account link and QR alternative are unchanged and still require deliberate approval in the signed-in ItamarOS application. Offline demo progress is local and is not automatically merged into the online account.
- Fredoka is bundled for offline use from the Google Fonts project under the SIL Open Font License; see [the font license](assets/fonts/Fredoka-OFL.txt).

## Playable characters and original graphics

- The English-only character wardrobe now supports **23 original characters**: free Cloud Scout, 12 regular characters in Character Orb for 500 earned game coins each, and 10 mystery characters earned by collecting the five blue-door cubes in each world.
- The regular character names are Sky Fox, Nimbus Cat, Breeze Bunny, Rain Penguin, Star Pup, Cloud Bear, Comet Owl, Mist Koala, Aurora Dragon, Kite Frog, Moon Bat and Sun Lion.
- Equipping a character changes the playable mascot's colors, scarf and accessories on the iPhone and Android stage. Available characters have selectable cards; locked heroes cannot be equipped.
- The equipped choice is kept locally: per account in ItamarOS, and separately in each offline demo. Online ownership is fetched from the existing server; no paid currency or premium loot boxes are added.
- This is an original Cloud Climb game, not a copy of another studio's copyrighted characters or artwork.

## Builds

- Android standalone application ID: `org.itamaros.cloudclimb`, built by [Cloud Climb Android](.github/workflows/cloud-climb-standalone.yml).
- iOS standalone bundle ID: `org.itamaros.cloudclimb`, built by [Cloud Climb iOS](.github/workflows/cloud-climb-ios.yml). Development IPA is unsigned and requires authorized signing.
- The [ItamarOS downloads page](downloads.html#cloud-climb) reveals these standalone downloads after entering the discovery code `0000`; it detects iPhone/iPad versus Android and only advertises confirmed, unexpired build artifacts.
- Cloud Climb remains playable inside the main mobile ItamarOS application's Online Rooms section.

## Same-device ItamarOS sign-in (no QR)

- The standalone Android and iOS apps offer **Continue with ItamarOS · No QR**.
- Cloud Climb creates a short-lived pairing request with the existing HTTPS broker, then opens the trusted ItamarOS app via `itamaros://cloud-climb?request=...`.
- Only the non-secret request ID is included in the app link. The claim secret remains inside Cloud Climb. Tokens and passwords are never sent through the URL.
- ItamarOS shows the matching 6-character request prefix and requires explicit device confirmation (Android secure device credential; iPhone Face ID/Touch ID). After approval, use **Return to Cloud Climb** or switch back manually; the waiting app claims the request and loads online room access.
- The existing QR route remains available for linking from another device.
- **Prototype limits:** this reuses the current memory-backed broker that transfers a temporary account bearer session. Neither QR nor app-link sign-in is an OAuth/PKCE implementation; do not treat this as a production security review. The apps must both be installed and the main ItamarOS app must have an authenticated account.

## Gameplay mechanics (preview)

- Three hearts, +10 earned coins on each completed level, and a three-hit boss at stages 30, 60, 90, etc.
- A missing heart can be restored for **100 earned coins** at 10-stage checkpoints; the one before a boss is displayed before that boss, not after it.
- **Character Orb:** buy a random **unowned** normal character for **500 earned game coins**. There are 12 regular characters in the initial pool. The price is not real currency, there are no paid coin bundles, and completing the regular pool disables further purchases.
- **Blue door cubes:** ten worlds, five distinct blue doors per world. Enter each hidden door to receive its cube. The fifth blue cube in a world awards `mystery_world_N`, a unique mystery character for that world.
- **Colored cubes:** **ten total**, awarded once each following bosses 30, 60, ..., 300. The eligible stage is randomly distributed across the next 1–3 completed stages, stable for an account in online mode. Ten colored cubes unlock Secret World 11.
- One optional world-unlock key per 100 completed levels, redeemable for any still-locked normal world.
- The command console inside the game supports `/help`, `/stats`, `/world N`, `/pause`, `/resume`, `/theme day`, `/theme twilight`, and `/room`.
- English UI. Supported controllers can hide on-screen movement controls automatically, with a settings toggle.
- Online mode shares the existing ItamarOS Supabase rooms and authenticated account progression. A separately signed-in Cloud Climb app uses the same 10-character multiplayer room codes as the built-in version.
- Offline previews have local saves but do **not** automatically merge game currency, characters, or collectibles into online accounts.

## Technical and security limitations

This is a **developer prototype**, not a multiplayer production release. Android builds are debug packages and iOS development IPAs are unsigned. Compiling is not equivalent to a successful install or play test on real devices.

The authenticated Supabase API protects account inventory and makes 500-coin purchases atomic, but the current game still reports level progress and player positions from clients. Until gameplay and proximity are validated authoritatively by a game server, it is **not cheat-resistant**; do not enable paid game currency or publicly traded items.

QR pairing requires a currently signed-in ItamarOS device and local owner confirmation. The legacy pairing broker still transfers a short-lived bearer session, so use it only for private development until replaced by a stronger OAuth/PKCE authorization code or equivalent device-bound session exchange.
