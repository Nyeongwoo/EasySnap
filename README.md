# EasySnap
A simple video frame extractor for macOS.

## Requirements
- macOS 13.5 or later

## Usage
Since EasySnap is not code-signed yet, you need to run the following command
in Terminal before opening the app for the first time:

```bash
xattr -cr /Applications/EasySnap.app
```

Then open the app normally.

## Third-Party Licenses
This app bundles [FFmpeg](https://ffmpeg.org), which is licensed under the
[LGPL v2.1 or later](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html).
FFmpeg source code is available at https://ffmpeg.org/download.html
