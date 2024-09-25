# face-blurer


Decompose info frames:
```
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -fps_mode passthrough  -q:v 0 "/data/output/frame_%08d.png"
```

Process frames:
```
docker build . -t blurer 
docker run --rm -v ./app:/app -v ./input:/input:ro -v ./output:/output blurer python blur_faces_ai_2.py
```

Compose video:
```
docker run -v $(pwd):/data linuxserver/ffmpeg -r 50  -f image2 -s 1920x1080 -i "/data/output/frame_%08d.png" -vcodec libx264 -crf 25 -pix_fmt yuv420p "/data/output/video.mp4"
```