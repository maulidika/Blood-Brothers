#!/bin/sh
# Stage 3: MP4 (H.264, video-only) -> Ogg Theora (only video format Godot 4 plays natively).
# usage: stage3_video.sh <src_dir_with_mp4> <out_dir>
set -e
for n in opening_01 opening_02; do
  ffmpeg -y -loglevel error -i "$1/$n.mp4" -an -c:v libtheora -q:v 10 -pix_fmt yuv420p -fps_mode passthrough "$2/$n.ogv"
done
