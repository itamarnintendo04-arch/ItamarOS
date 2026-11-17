# Cloud Climb — Android TV preview

This repository includes a **standalone Kotlin/Compose Android APK** that can also launch on Android TV (including Google TV televisions such as Haier), plus a smaller **Godot gameplay prototype** with its own TV export preset.

## Shared regular game and QR sign-in

The Android TV app is **not a reduced remake**. It reuses the same `CloudClimbAndroid` game implementation as the regular Android application, so levels, hearts, coins, bosses, characters, worlds, saves and multiplayer are not maintained in a separate game fork. The TV interface adds TV-friendly entry points without replacing game rules. QR sign-in from an already authenticated ItamarOS phone is the default TV onboarding route; a successful approval yields a session for the same account. Sign-in and cloud sync need end-to-end tests against the configured backend.

## What works in the Android APK preview
- 16:9 Android TV launcher entry and landscape orientation.
- Android TV/Google TV remote D-pad: left and right to move, Up to jump, Center to attack a boss.
- Bluetooth game controllers: left stick/D-pad to move, A/B to jump, X/Y to attack, Start to pause.
- Back on the TV remote toggles the pause screen.
- TV mode hides touch-only buttons and most mobile-specific screens during the game.
- Shows an expiring QR code automatically at first TV launch, requires phone-side approval and never puts bearer token/claim secret in the QR.
- After approval displays **Play Cloud Climb** and **Online Multiplayer** options; the regular game's save and progress code is used.
- Offline demo (first two stages). Sign-in, multiplayer and persistence are still experimental and need physical-device tests.
- **Game Options** exposes worlds, wardrobe, settings and other regular-game features without touch controls.
- Goal: consistent 60 FPS where TV performance permits; **120 FPS is not promised**.

## Build the standalone Android / TV APK
1. Open **GitHub → Actions → Build Cloud Climb Android and Android TV APK**.
2. Choose **Run workflow**, select the feature branch or main once merged.
3. After a successful run, open the run's **Artifacts** and retrieve the debug APK.
4. Install it only using standard, supported app-installation options on a TV you own and are allowed to configure.
5. Use the TV's D-pad or pair a compatible Bluetooth gamepad through Google TV Settings.

The APK is a **debug-signed, unverified development preview**. Build success does not prove compatibility, performance, or safety. Do not turn off device protections to install it.

## Godot version
The lightweight platformer prototype is at `game-engines/godot/CloudClimb`.
Open it in Godot 4.3+ and select the `Android TV` export preset. Set up OpenJDK 17 and the Android SDK / export templates first. The separate `org.itamaros.cloudclimb.godottv` application ID avoids overwriting the Kotlin game.

The Godot prototype has gamepad controls, a controller-friendly pause menu and automatic hiding of touch buttons when no touchscreen is present. It is **not yet feature-equivalent** with the Kotlin app and is not connected to online accounts.

## Acceptance checklist
- App appears under Apps on Google TV and opens in landscape.
- First launch shows a scannable QR, and TV login succeeds only after explicit approval on a trusted signed-in ItamarOS phone.
- After sign-in, **Play Cloud Climb** enters the full regular Android game, and Online Multiplayer is reachable.
- Offline demo starts using the TV remote, without touch.
- D-pad left/right and Up/Center move, jump and attack as expected.
- Bluetooth controller inputs work and touch buttons stay hidden.
- Back/Start pauses, and pause menu buttons can be selected.
- Game canvas fits the 16:9 screen without clipping important elements.
- Game Options can reach full-world, wardrobe and game settings using a paired controller/TV remote.
- Returning to the Google TV launcher works normally.
- Test network login only with an account you control.
