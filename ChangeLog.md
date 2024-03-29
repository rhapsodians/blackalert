# Change Log #

## 0.37 ##
_11 February 2022_
- updated copyright to 2022
- switched to SSD (D:) for rips and transcodes
- Updates for `other-transcode` v0.10.0 including:
  - replaced `--x264-avbr` with the new constant bitrate formula `--x264-cbr`
  - added 10-bit HEVC h/w only pipeline for faster VC-1 transcodes (default to QSV remains so this is an optional override)
  - standardised on `ffmpeg 5.0` or better for GPU-only pipeline content.


## 0.36 ##
_20 June 2021_
- Updates for `other-transcode` v0.9.0 including:
  - New 10-bit HEVC default used "--hevc --nvenc-recommended --nvenc-cq 27"
  - Optional use of the previous 10-bit HEVC default "--hevc --preset p5 --nvenc-spatial-aq --nvenc-lookahead 32"
  - Addition of optional H.264 version of the new CQ 27 formula as an override for QSV
  - Updated audio options from `other-transcode 0.9.0` (e.g. replacement of `--eac3 --aac-stereo` with `--eac3-aac` and replacing `--aac-stereo` with `--aac-only`
  - Added an optional override to the CQ value (27) from 1-51
- Replaced Dropbox with OneDrive for all post-processing cloud storage



## 0.35 ##
_11 June 2021_
- Bug fix to correctly generate a stereo track for non-4K movies with conditions. Swapped `if [ ${str05VideoHeight}="2160" ]` for `if [ ${str05VideoHeight} -eq 2160 ]`
- Swapped over to new IP ranges from NAS mounts
- Change `--target 576p=1500` to `--target 1500` for DVDs as this height isn't supported by `other-transcode`
- Add in an option for 480p updated targets
- Changed the methodology to extract forced subtitle checks from using the stream title ("Forced") to using the forced flag setting (`str05SubtitleForcedPresence` from `.disposition.forced`)
- Added a new audio option to `--add-audio <Index>` for occasional usage whilst also maintaining mono|stereo|surround space (overriding the default stereo in `other-transcode`)



## 0.34 ##
_2 February 2021_
- Updates for `other-transcode` v0.7.0
- Added new `ffprobe .width` variable
- Restored previous default bitrates for video/audio streams (by passing new, lower defaults)
- Removed additional stereo track from 4K/HDR transcodes
- Add new option to override VC-1 defaults from QSV to 10-bit HEVC 
- Separated out and variable-ised core default arguments 
- Fixed audio choice bug where QSV overrides were not being correctly applied.
- Added variable for `other-transcode` for Mac and PC to quickly add in beta test versions or revert to normal gem-installed versions
- Removed `--qsv-decoder` from the QSV defaults and replaced it with `--cuda` to eliminate a large audio offset (`Delay Relative to Video`) of up to -172ms.
- Replaced `/Volumes/E` with the `/Volumes/IP` address - change after updating to macOS Big Sur 11.2


## 0.33 ##
_12 December 2020_
- Back to `other-transcode` as Don released 0.4.0 and 0.5.0 (with the Nvidia presets)
- Changed QSV from HEVC to AVC defaults (`--qsv --qsv-decode --preset veryslow`)
- Promoted QSV to the main menu and moved CopyVideo to the submenu
- Added automatic codec folder generation/sorting in post processing (e.g. HEVC content -> HEVC folder, QSV content -> QSV folder)
- QSV now the default for all VC-1 content
- Replaced the older `arrHwTranscodeRbCommand` variable with `arrOtherTranscodeRbCommand`
- Added encoder-specific logs location separation. For example:  QSV content -> Dropbox's "Logs (QSV)" folder whereas HEVC goes to "Logs"
- Fixed bug where mono/stereo/2.1 DTS-HD MA (and other high quality) tracks were using AAC instead of EAC3 (`--all-eac3` was not being added).
- Added `--rc-bufsize 3` to the HEVC defaults
- Added `--max-muxing-queue-size 1024` to the defaults


## 0.32 ##
_28 October 2020_
- Minor path typos for folder naming function
- Removed sleep in folder naming function
- Changed Mac test HD from "4TB" to "3TB" after drive failure.
- Added "pretend" checks/creation when run in test mode to standardise build-out
- `mv` command was failing ... added double quotes
- For 4K forced-subtitling, changed `--add-subtitle "Forced"` to `--add-subtitle auto` so that the default subtitle and forced flags were auto-set.
- Removed quotes from `--add-audio` and `--add-subtitle` strings to ensure both `call` commands and those run on the CLI act in the same way. Quotes lead to `--add-audio "AD"=surround` being processed as surround within a `call` command but as stereo (incorrectly) if run from the commandline.
- Added in logic to handle `pcm_s24le` audio tracks
- Temporary usage of `beta_other-transcode` and using the `--preset p5 --nvenc-lookahead 32 --nvenc-spatial-aq` default.
- Updated locations with `beta_other-transcode` instead of `other-transcode`
- Added an option not to copy raw and transcoded mkv files to the targets - due to IO bug in WSL2
- Added override file functionality from Dropbox into the batch processing


## 0.31 ##
_28 August 2020_
- WSL mount bug fixes
- added HDR post-processing
- fixed the "Season 0" folder where the zero was missing
- Added in a test move (`mv`) location
- Add pcm_s24le as a valid audio codec for mono - used for "It Happened One Night (1934)"
- Post-processing: if the raw source target is the same "E" drive as ready-for-transcoding, swap the copy to a move.
- 4K/HDR - check to ensure `--deinterlace` is not included due to the lack  .streams[0].field_order not being set for 2160p content
- If you choose to active "- Disable forced subtitle burn-in" in the menu choices, the Forced subsitle stream is now embedded automatically (usually, it's excluded).
- New 3.5" HDD archive for raw content: two new drives will be added for archiving. These will be exFAT-formatted drives for on-site/off-site archives. Once post-transcoding clean-up starts, the raw source will be copied to each drive.


## 0.30 ##
_17 July 2020_
- Change automation for the transcode logs, JSON Summaries, command/override files to store them on Dropbox instead of on a NAS mount point.


## 0.29 ##
_27 June 2020_
- Changed Channel layout logic to channel count for better identification in assigning `--all-eac3`
- This also fixes `--add-audio 1=stereo` being added to raw stereo or mono sources.
- Minor modifications to Default Audio checking


## 0.28 ##
_21 April 2020_
- Added menu options for Intel QSV and Apple VideoToolbox overrides
- Updated QSV and VT interactive text
- Updated Ubuntu/WSL mount points for Plex and Media NAS mounts
- Added `--cuvid` by default. Nvidia drivers from 20 April do not have the same AVC/MPEG2 penalty as before (approx 10-15% slowdown on FPS). By having CUVID decoding, the decode-Cudu-encode stream stays on the GPU. It also addresses an issue with VC-1 where decoding is done by `-hwaccel auto` which moves decoding to QSV (possibly the original root cause of the slowdown). This means that AVC, MPEG2 and VC-1 all have similar 130-135fps transcodes on the GTX1660
- Moved bitrate options to the audio submenus
- Added a new commands.sh output instead of Windows batch (.bat) if `--vt` (macOS VideoToolbox) is included/chosen for any source movie/TV show.
- Updated `stream_summary.sh` with improvement from Martin P


## 0.27 ##
_28 February 2020_
- Interactive `ffprobe` information now contains `.profile` which gives more detail on various codecs including DTS
- Options for `--pass-dts` and `--keep-ac3-stereo` added (simplified mode only, added to the end of the commandline)
- Added dates to the ChangeLog.md file.
- Added `stream_summary.sh` to the project.
- Fixed incorrect identification of default audio, forced subtitle and title due to the inclusion of Profile in various `ffprobe`/`jq` queries. Each of the above were incremented by one additional field.
- Added new bitrate overrides for surround, stereo and mono as menu options.
- Upgaded hash-bang to `#!/usr/bin/env bash`


## 0.26 ##
_18 February 2020_
- Updated to include new options from `other-transcode` v0.3
- New and updated menus
- Moved from `ffprobe` only metadata-based command generation to `ffprobe` plus optional override functionality - makes future batching easier including items like `--copy-video`, variations of using `=original` etc.
- EAC-3 (Dolby Digital+) now the default for all audio
- Options for `--copy-video`, `--main-audio [TRACK]=original`, `--add-audio all=original`, bitrate overrides, optionally disable subtitle forced burn-ins and ability to revert to 640 EAC3 surround, 256 AAC stereo and 128AAC mono.
- Bug fix and upgrade to accurately determine the channel layout of "AD" and "Commentary" audio streams so the correct width (`=stereo|surround`)s set in the `--add-audio "AD"|"Commentary"` auto-generated flags.
- Lots of minor tweaks and bug-fixes


## 0.25 ##
_10 January 2020_
- First release to be installed/distributed via GitHub
- `--add-audio` defaults to stereo even for 5.1 tracks (e.g. 5.1 Audio Description -> stereo). The channel layout per `--add-audio` track should be 5.1/stereo/mono as per the original so the `surround` parameter needs to be added as appropriate. So an Audio Description (AD) audio stream in Surround 5.1 will be added as `--add-audio "AD"=surround`. The `=<channel width>` will be added by default for clarity in all add-audio tags.
