# ItamarOS version cycle

The requested public version sequence is:

`1.0 → 1.1 → 1.5 → 1.9 → 2.0 → 2.1 → 2.5 → 2.9 → 3.0 → ...`

Each major family starts with `.0`, followed by `.1`, `.5` and `.9`. Major versions increase after `.9`. The GitHub manifest contains a `version` string, with patch releases kept separate if later needed.

The web emulator (a separate deliverable) may show the same *marketing version* but is not a native OS installation. Production artifacts must specify `linux-amd64`, `windows-demo`, etc. Version numbers alone do not establish install compatibility.

The update checker watches the version manifest, never guesses a release from a filename, and only presents a downloadable native installer when one actually exists with a valid signed official GitHub Release reference. Debian software/security updates come from Debian's signed APT repositories through KDE Discover.
