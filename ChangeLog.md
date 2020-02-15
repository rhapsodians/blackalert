# Change Log #

## 0.26 ##

- New and updated menus
- Options for `--copy-video`, `--main-audio [TRACK]=original`
- Bug fix and upgrade to accurately determine the channel layout of "AD" and "Commentary" audio streams so the correct width (`=stereo|surround`)s set in the `--add-audio "AD"|"Commentary"` auto-generated flags.
- Addition of notes in the script to explain the above in more detail.





## 0.25 ##

- First release to be installed/distributed via GitHub
- `--add-audio` defaults to stereo even for 5.1 tracks (e.g. 5.1 Audio Description -> stereo). The channel layout per `--add-audio` track should be 5.1/stereo/mono as per the original so the `surround` parameter needs to be added as appropriate. So an Audio Description (AD) audio stream in Surround 5.1 will be added as `--add-audio "AD"=surround`. The `=<channel width>` will be added by default for clarity in all add-audio tags.
