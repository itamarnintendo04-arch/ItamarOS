# ItamarOS Games – touch, illustrations, offline sounds and GIFs

## Browser and desktop games (16 listings)

- Directional controls in 2048 and Snake now accept direct touch/mouse swipes on the board; keyboard arrow support remains for accessibility and desktops.
- The Snake board is redrawn with a friendly cartoon head, eyes, green segments, and two-cherry fruit illustration, instead of plain rectangles. Steering ignores 180-degree reversals.
- Tic-Tac-Toe and Memory also accept pointer interactions in addition to tapping. Connect Four supports dropping by tapping a column or dragging a colored disc across the board. Number, math, word and reaction games already use touch inputs/buttons instead of directional keys.
- Each game displays an ItamarOS-created colorful SVG illustration; Memory, 2048, Connect Four and other boards receive colorful styling.
- Game sounds are genuine **Kenney Interface Sounds (CC0 1.0)** sourced from [Kenney](https://kenney.nl/assets/interface-sounds) through [Calinou's CC0 game asset mirror](https://github.com/Calinou/kenney-interface-sounds). Five small WAV sound samples are embedded as Base64 within `apps/game-fx.js` to work offline without sharing play statistics or fetching an external website. Sounds include tap, move, collect, win and error. Sound is user-controllable via **Sounds on/off** and the local preference key `itamaros-game-sound`. Original artwork and code are part of ItamarOS; sound samples remain CC0. Credit to Kenney is optional under CC0, but maintained here for clarity.

The desktop offline pack includes `apps/game-fx.js`, and the PWA service worker pre-caches it for offline use. Only start sounds in response to user-initiated game actions; browsers may mute audio until first interaction.

## Web ItamarOS Player

The playlist picker accepts `image/*`, including animated GIFs and still images. Selecting a GIF displays it as an `<img>` element (GIFs animate through the browser image decoder), not as video. Image playback hides video-only controls where possible; taking an image screenshot uses the canvas if allowed. Audio/video continue through HTML media APIs. Local File data uses object URLs that are revoked on removal/close.

## Native apps

- Apple (iOS/iPadOS, macOS): Files/Photos image selections now recognize animated GIF data and display animations through native ImageIO + UIKit/AppKit display views. To avoid excessive memory use, iOS playback limits file size and decoded frame count.
- Android: `NativeMediaPreview` uses `ImageDecoder` + `AnimatedImageDrawable` on Android 9+ for GIF animation; earlier devices use a static preview fallback.
- Native iOS and Android: 2048 and Snake use touch/drag instead of four directional arrows, Snake displays a cartoon head and cherry, and games have colorful graphics. Connect Four supports drag-to-column in addition to tapping.

**Differences:** Browser games provide the bundled Kenney sounds. Native iOS/Android builds currently provide their own illustrations and gesture controls but do not yet bundle the browser WAV sound engine. Do not represent native apps as having the same audio effects until native audio is integrated and tested.

## Testing

The source repository includes JS syntax/smoke tests, Apple Xcode builds and Android Gradle builds in GitHub Actions. GIF decoding and gestures depend on device capabilities; physical-device QA is still needed before calling every supported format fully verified.
