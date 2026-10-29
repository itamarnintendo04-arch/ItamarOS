# ItamarOS Player – VLC feature review

This is an **independent browser-based media player**, not the VLC/libVLC engine. It does **not** implement all VLC features.

The checklist below tracks the major capabilities described in the official [VideoLAN feature reference](https://www.videolan.org/vlc/features.html) and [libVLC documentation](https://www.videolan.org/vlc/libvlc.html). Platform APIs determine whether the browser implementations work.

| VLC capability | ItamarOS Player web status | Detail |
|---|---|---|
| Local audio/video playback | Implemented when supported by browser | File picker, drag-and-drop, <video> controls |
| Direct web media URL | Partial | HTTP(S) URL to a directly playable resource; site and codec restrictions apply |
| Play/pause/stop | Partial | Play/pause and clear playlist; no permanent file library |
| Seek / jump | Implemented | Native seek bar, ±10 seconds |
| Previous/next | Implemented | Playlist traversal |
| Playback speed | Implemented | 0.25×–4× (browser support may cap) |
| Volume | Implemented | Range control |
| Repeat one | Partial | A–B loop for a segment, playlist looping for all tracks |
| Repeat playlist | Implemented | Loop control |
| Shuffle playlist | Implemented | Random next track |
| Playlists | Implemented, session-only | Add files/URLs, reorder, remove; local file permissions don't survive reload |
| Subtitle files | Partial | External SRT and WebVTT, browser text track rendering |
| Subtitle on/off | Implemented | External text track |
| Subtitle timing/sync | Partial | ±0.25s cue adjustments, depends on text-track API |
| Subtitle formats SSA/ASS/DVD/embedded | Not implemented | Embedded track access differs by browser |
| Multiple subtitle tracks | Not implemented | A single external subtitle file |
| Multiple audio track selection | Not implemented | Browsers rarely expose consistent audioTracks |
| Audio equalizer | Implemented | 10-band Web Audio API filters and presets |
| Audio filters | Partial | Equalizer only; other VLC audio effects missing |
| Video color filters | Implemented | Brightness, contrast, saturation |
| Rotate/mirror/zoom | Implemented | CSS visual transforms |
| Aspect-ratio adjustments | Partial | Display settings; not a video transcoder |
| Deinterlacing, advanced shader filters | Not implemented | Requires specialized decoding/rendering engine |
| Fullscreen | Implemented where supported | Browser fullscreen API |
| Picture-in-picture | Implemented where supported | Browser PiP API |
| Snapshots | Implemented for local/approved media | Canvas export to PNG; CORS protects foreign video |
| Video/screen recording | Partial | Records supported media element streams with MediaRecorder, not desktop/device capture |
| A–B repeat | Implemented | Set A, set B, clear |
| Media information | Partial | Name, runtime, video dimensions and speed |
| Audio CD/DVD/Blu-ray/menu playback | Not implemented | Browser cannot directly access media/disc systems |
| Video CD / ISOs | Not implemented | Native capabilities required |
| Universal VLC codecs (MKV/AVI/WMV/MPEG, etc.) | Not implemented | Actual supported codecs/containers come from the browser |
| Hardware decoding / HDR / HEVC / 360° | Browser/device dependent | No VLC-specific decoder or renderer |
| Network protocols RTSP/RTP/UDP/SMB/FTP/DLNA/UPnP | Not implemented | Browser URL player is not a protocol gateway |
| HLS/DASH adaptive streaming | Browser dependent | Only when the browser has built-in support; no JS HLS/DASH library |
| Chromecast/AirPlay/remote casting | Not implemented | No built-in casting integration |
| Transcode/convert/export codecs | Not implemented | MediaRecorder may record supported streams, not convert arbitrary media |
| Audio device selection/passthrough | Not implemented | Browser API/device-dependent; no HDMI/SPDIF passthrough |
| Webcam capture, TV tuners, streaming output | Not implemented | Would need permissions/native APIs or server |
| Media library/metadata/cover art | Partial | Temporary session playlist; browser media info only |
| Extensions/plugins/skins | Not implemented | Future architecture required |
| Subtitle fonts and advanced styles | Browser dependent | Native text-track rendering |
| Accessibility and keyboard | Partial | Native browser controls; Space and arrow seek shortcuts |

## Why a 100% VLC clone is not available in the browser
VLC uses native media engines and hardware integrations, multiple container demuxers and codecs, local-network protocol stacks, disc access, and plugins. A browser-only static site cannot safely or reliably reproduce every one of them. A future **native ItamarOS Player** could integrate a legally compliant libVLC build or another native engine, with platform-specific packaging and licensing review.

## User privacy
Local files are played via browser object URLs. This implementation does not upload selected files to Render. Remote URLs requested by the user are contacted directly by the browser. Audio/video playlist files are not silently retained on the server.

## Known browser issues
- Website media URLs may fail due to CORS, authentication, DRM, or an unsupported codec.
- Screenshots cannot export pixels from tainted cross-origin videos.
- Recording may be unavailable on Safari/iOS or for protected streams.
- Some mobile browsers do not support fullscreen/PiP or MediaRecorder for all streams.
- Offline use requires the static assets to have been cached during an earlier online visit.
