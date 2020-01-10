# Change Log #

## 0.25 ##

- First release to be installed/distributed via GitHub
- `--add-audio` defaults to stereo even for 5.1 tracks (e.g. 5.1 Audio Description -> stereo). The channel layout per `--add-audio` track should be 5.1/stereo/mono as per the original so the `surround` parameter needs to be added as appropriate. So an Audio Description (AD) audio stream in Surround 5.1 will be added as `--add-audio "AD"=surround`
