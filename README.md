References:
* https://github.com/markusschmitz53/demo-face-blur


Decompose info frames:
```
# Lossless
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -fps_mode passthrough -q:v 0 -c:v png "/data/input/frame_%10d.png"

# 20 FPS
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -r 20 -q:v 0 -c:v png "/data/input/frame_%10d.png"

# With extra info overlay
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -r 20 -vf "drawtext=text='%{pts\:hms}':x=w-tw-10:y=h-th-40:fontcolor=white:fontsize=24, drawtext=text='Frame\: %{n}':x=w-tw-10:y=h-th-10:fontcolor=white:fontsize=24" -q:v 0 -c:v png "/data/input/frame_%10d.png"

```

Process frames:
```
docker build . -t blurer 
docker run --rm -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache:/root/.deepface blurer python blur_faces_retinaface.py
```

Compose video:
```
docker run -v $(pwd):/data linuxserver/ffmpeg -r 50  -f image2 -s 1920x1080 -i "/data/output/frame_%10d.png.blurred.png" -vcodec libx264 -crf 25 -pix_fmt yuv420p "/data/output/video1-blurred.mp4"
```