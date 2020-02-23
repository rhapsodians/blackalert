# Change Log #

## 0.27 ##
- Interactive `ffprobe` information now contains `.profile` which gives more detail on various codecs including DTS

## 0.26 ##

- Updated to include new options from `other-transcode` v0.3
- New and updated menus
- Moved from `ffprobe` only metadata-based command generation to `ffprobe` plus optional override functionality - makes future batching easier including items like `--copy-video`, variations of using `=original` etc.
- EAC-3 (Dolby Digital+) now the default for all audio
- Options for `--copy-video`, `--main-audio [TRACK]=original`, `--add-audio all=original`, bitrate overrides, optionally disable subtitle forced burn-ins and ability to revert to 640 EAC3 surround, 256 AAC stereo and 128AAC mono.
- Bug fix and upgrade to accurately determine the channel layout of "AD" and "Commentary" audio streams so the correct width (`=stereo|surround`)s set in the `--add-audio "AD"|"Commentary"` auto-generated flags.
- Lots of minor tweaks and bug-fixes


## 0.25 ##

- First release to be installed/distributed via GitHub
- `--add-audio` defaults to stereo even for 5.1 tracks (e.g. 5.1 Audio Description -> stereo). The channel layout per `--add-audio` track should be 5.1/stereo/mono as per the original so the `surround` parameter needs to be added as appropriate. So an Audio Description (AD) audio stream in Surround 5.1 will be added as `--add-audio "AD"=surround`. The `=<channel width>` will be added by default for clarity in all add-audio tags.
