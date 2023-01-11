#!/bin/sh

if [[ $# -eq 0 ]]; then
    echo "USAGE: $0 <filename>_<widxhei>_<pix-fmt>_<type>.yuv"
    echo "<filename>: a string"
    echo "<widxhei>:  width and height, e.g. 1920x1080"
    echo "<pix-fmt>:  pixel format, e.g. yuv420p, yuv444p16le"
    echo "<type>:     hlg or pq or 709"
    echo "This script always encode with tv range and libx265."
    exit -1
fi

file=$1
name=""

if [[ "${file}" =~ ^(.+)_[0-9]+x[0-9]+_.*$ ]]; then
    name=${BASH_REMATCH[1]}
    echo "Filename: ${name}"
fi

if [[ "${file}" =~ ^.*_([0-9]+)x([0-9]+)_(yuv4[0-9a-zA-Z]+)_([0-9a-zA-Z]+)\.yuv$ ]]; then
    width=${BASH_REMATCH[1]}
    height=${BASH_REMATCH[2]}
    pix_fmt=${BASH_REMATCH[3]}
    type=${BASH_REMATCH[4]}
    echo "Frame size: ${width}x${height}"
    echo "Pixel format: ${pix_fmt}"
    echo "Data type: ${type}"
else
    echo "Cannot parse filename! Make sure it follows naming rules."
    exit -1
fi

if [ "${type}" = "pq" ]; then
    trc=smpte2084
    pri=bt2020
    space=bt2020nc
    out_pix_fmt=yuv420p10le
elif [ "${type}" = "hlg" ]; then
    trc=arib-std-b67
    pri=bt2020
    space=bt2020nc
    out_pix_fmt=yuv420p10le
elif [ "${type}" = "709" ]; then
    trc=bt709
    pri=bt709
    space=bt709
    out_pix_fmt=yuv420p
else
    echo "Data type ${type} cannot be recognized!"
    exit -1
fi

output_file="${name}_${type}.mp4"

which ffmpeg.exe
if [[ $? -eq 0 ]]; then
    bin=ffmpeg.exe
else
    bin=ffmpeg
fi

# ffmpeg cmd inspired by this article:
# https://stackoverflow.com/questions/69251960/how-can-i-encode-rgb-images-into-hdr10-videos-in-ffmpeg-command-line

${bin} \
    -hide_banner -loglevel verbose \
    -sws_flags print_info+accurate_rnd+bitexact+full_chroma_int \
    -vcodec rawvideo -f rawvideo \
    -color_range tv -pix_fmt ${pix_fmt} \
    -r 1 -s ${width}x${height} \
    -i "${file}" \
    -c:v libx265 \
    -color_range tv \
    -color_trc ${trc} \
    -color_primaries ${pri} \
    -colorspace ${space} \
    -pix_fmt ${out_pix_fmt} \
    -crf 0 -tag:v hvc1 \
    "${output_file}" -y

echo "input: ${file}"
echo "output: ${output_file}"