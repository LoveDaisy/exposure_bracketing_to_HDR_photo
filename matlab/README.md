# Matlab Codes for Fitting Curve and Compositing HDR Image

The main script is `main.m`.

The main script will read images in `../dataset` folder, try to align them, and then estimate curve parameters
and the image EVs. After all these, it will save a YUV file for video encoding, and it can be encoded into
a single frame HDR video by running `encode_hdr.sh` script.