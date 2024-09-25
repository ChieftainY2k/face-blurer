# face-blurer


```
ffmpeg.exe -i "c:/cygwin64/tmp/input1.mp4" -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -fps_mode passthrough -q:v 0 "c:/cygwin64/tmp/FRAME_%08d.png"
```

```
docker build . -t blurer 
docker run --rm -v ./app:/app -v ./input:/input:ro -v ./output:/output -v ./models:/models:ro blurer python blur_faces_ai_2.py
```