# Cloud Climb — development preview

Cloud Climb is an original platform-adventure prototype available inside ItamarOS and as a separate mobile app. It does **not** contain Crossy Road Castle code, artwork or sounds.

## Builds

- Android standalone application ID: `org.itamaros.cloudclimb`, built by [Cloud Climb Android](.github/workflows/cloud-climb-standalone.yml).
- iOS standalone bundle ID: `org.itamaros.cloudclimb`, built by [Cloud Climb iOS](.github/workflows/cloud-climb-ios.yml). Development IPA is unsigned and requires authorized signing.
- The [ItamarOS downloads page](downloads.html#cloud-climb) reveals these standalone downloads after entering the discovery code `0000`; it detects iPhone/iPad versus Android and only advertises confirmed, unexpired build artifacts.
- Cloud Climb remains playable inside the main mobile ItamarOS application's Online Rooms section.

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
