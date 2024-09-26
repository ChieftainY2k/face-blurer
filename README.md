References:
* https://github.com/markusschmitz53/demo-face-blur


Decompose info frames:
```
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -fps_mode passthrough -q:v 0 -c:v png "/data/input/frame_%10d.png"
```

Process frames:
```
docker build . -t blurer 
docker run --rm -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache:/root/.deepface blurer python blur_faces_retinaface.py
```

Compose video:
```
docker run -v $(pwd):/data linuxserver/ffmpeg -r 50  -f image2 -s 1920x1080 -i "/data/output/frame_%10d.png.blurred.jpg" -vcodec libx264 -crf 25 -pix_fmt yuv420p "/data/output/video1-blurred.mp4"
```