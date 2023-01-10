# Matlab Codes for Fitting Curve and Compositing HDR Image

The main script is `main.m`.

The main script will read images in `../dataset` folder, try to align them, and then estimate curve parameters
and the image EVs. After all these, a YUV file will be saved for video encoding, and it can be encoded into
a single frame HDR video by running `encode_hdr.sh` script, which locates at root directory.

**NOTE**: the `encode_hdr.sh` uses `ffmpeg` to do the encoding. `ffmpeg` should be compiled with `libx265`,
otherwise the encoding will fail.

The total process will be like:
1. Run `main.m` in matlab, and get a YUV file.
2. Run `encode_hdr.sh` and you will get a `.mp4` file. That's it!
