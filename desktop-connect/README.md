# ItamarOS Connect for Windows and Mac

Independent Electron app: NOT an ItamarOS emulator.

## Development

Run from desktop-connect:

- npm install
- npm start
- npm run build:win (on Windows)
- npm run build:mac (on macOS)

[GitHub Actions desktop build](https://github.com/itamarnintendo04-arch/ItamarOS/actions/workflows/connect-desktop.yml)
produces unsigned Windows .exe and macOS .dmg installers.
Unsigned builds may trigger Windows SmartScreen and macOS Gatekeeper. Do not bypass
device protections; properly sign/notarize before broad distribution.

## How SMS-free desktop login works

1. The computer creates a high-entropy one-time claim secret (kept only in its main
   process) and QR code with an approval URL, NOT a session token.
2. Scan with a phone ALREADY SIGNED IN on ItamarConnect on the same website
   (its browser or installed PWA).
3. The phone explicitly approves after comparing a six-character request identifier.
4. The existing Render API validates the phone's Supabase Auth token and confirmed
   phone status. A one-use claim gives the desktop a temporary ACCESS token.
5. The desktop uses that token for allowed chat requests, protected by Supabase RLS.

No second Twilio SMS is needed when the approving phone already holds a verified
session. The QR opens an approval page with **Open ItamarOS phone app**, which
uses a native deep link into the installed iOS/Android app. A signed-in native
user must explicitly approve the matching short code. Alternatively, the same
page can approve through an already-authenticated ItamarConnect browser session.
A new web session is NOT automatically shared with the native app. Android's
current session lives in memory, so reopening a killed app may require sign-in.
Native QR approval was added after the first desktop installer build, but the
server protocol is compatible with those installers.

Sessions are TEMPORARY; they cannot refresh and are held in desktop main-process
memory. The desktop must pair again after access token expiry, app restart or sign-out.
No refresh token, SMS code, password or Twilio credential is put in the QR or app.
Render keeps unclaimed requests in memory for 3 minutes; restarts invalidate QR codes.

Privacy: granting a computer access lets that computer use the user's messaging
permissions until expiry. Approve ONLY your own computers. No end-to-end encryption.
A public release requires security review, tested RLS, spam controls, proper
moderation and signed installers.

The current desktop preview supports room listing, starting private chats,
sending text, viewing existing groups/channels and creating a profile.
Voice/video calls, attachments and full mobile feature parity are not included.
