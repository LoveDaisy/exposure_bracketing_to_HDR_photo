# Matlab Codes for Fitting Curve and Compositing HDR Image

The main script is [`main.m`](main.m).

The main script will read images in `../dataset` folder, try to align them, and then estimate curve parameters
and the image EVs. After all these, a YUV file will be saved for video encoding, and it can be encoded into
a single frame HDR video by running [`encode_hdr.sh`](../encode_hdr.sh) script, which locates at root directory.

**NOTE 1**: saving YUV file and converting between colorspaces use several functions in
[another repository](https://github.com/LoveDaisy/ColorScienceUtils) of mine. You need to clone it and add
the `matlab` folder to your path of matlab.

**NOTE 2**: the `encode_hdr.sh` uses `ffmpeg` to do the encoding. `ffmpeg` should be compiled with `libx265`,
otherwise the encoding will fail.

The total process will be like:
1. Run `main.m` in matlab, and you will get a YUV file.
2. Run `encode_hdr.sh` and you will get a `.mp4` file. That's it!
