# Windows Device Manager (prototype)

Uses Apple Mobile Device Support (from iTunes/Apple Devices) for USB drivers. Optional `libimobiledevice` command-line tool `ideviceinfo` provides device identification.

## Run
```powershell
cd windows
py -m pip install -r requirements.txt
py main.py
```

## Features currently implemented
- Detect connected device model via `ideviceinfo` when installed
- Inspect Apple Mobile Device Service
- Choose IPSW file without modifying the phone
- Save local backup preference and directory to AppData
- Display iCloud backup recommendation

**Not implemented:** creating/restoring backups, signing/installing IPA, firmware restore/downgrade, jailbreak, TrollStore, SpringBoard tweaks. Backup settings only configure future functionality. Never enter Apple ID passwords into this prototype.
