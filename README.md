# What is it for ?

This is a simple example of how to blur faces in a video using AI and ffmpeg.

# How it works

1. Decompose video into frames using ffmpeg
2. Process each frame with deepface to detect faces and blur them
3. Compose video back from frames using ffmpeg

# What you need:

* Docker

# How to use it

### Decompose video into frames, each frame with index number:
```
# Preserve original
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -fps_mode passthrough -q:v 0 -c:v png "/data/input/frame_%10d.png"

#Scale to 640px width
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -vf "scale=640:-1" -q:v 0 -c:v png "/data/input/frame_%10d.png"

#Scale to 640px width and custom FPS
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -r 10 -vf "scale=640:-1" -q:v 0 -c:v png "/data/input/frame_%10d.png"

# Custom FPS
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -r 5 -q:v 0 -c:v png "/data/input/frame_%10d.png"

# With extra info overlay
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -r 5 -vf "drawtext=text='%{pts\:hms}':x=w-tw-10:y=h-th-10:fontcolor=white:fontsize=24" -q:v 0 -c:v png "/data/input/frame_%010d.png"
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -r 5 -vf "drawtext=text='T: %{pts\:hms}':x=w-tw-10:y=h-th-100:fontcolor=white:fontsize=24,drawtext=text='IF: %{frame_num}':x=w-tw-10:y=h-th-70:fontcolor=white:fontsize=24,drawtext=text='OF: %{n}':x=w-tw-10:y=h-th-40:fontcolor=white:fontsize=24" -q:v 0 -c:v png "/data/input/frame_%010d.png"
```

### Process frames, detect and blur faces in each frame from the input directory:
```
docker build . -t blurer 

# slow but accurate:
docker run --rm -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache:/root/.deepface blurer python blur_faces_retinaface.py

# faster but less accurate:
docker run --rm -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/depface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_retinaface_batch.py

# faster but less accurate in DEBUG mode (showing faces but not blurring them, useful for debugging):
docker run --rm -v ./app:/app -e DEBUG=1 -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/depface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_retinaface_batch.py 
```

### Compose video back from frames:
```
docker run -v $(pwd):/data linuxserver/ffmpeg -r 50  -f image2 -s 1920x1080 -i "/data/output/frame_%10d.png.blurred.png" -vcodec libx264 -crf 25 -pix_fmt yuv420p "/data/output/video1-blurred.mp4"
```

# References:
* https://github.com/markusschmitz53/demo-face-blur



# Examples:

### Source video: 
https://www.youtube.com/watch?v=Debjcl5z9Dw 

### Source frames:

![image](https://github.com/user-attachments/assets/1cfc54bc-e62b-4494-8317-2470775c180c)

### Face blurer in action:

![image](https://github.com/user-attachments/assets/4cc09d54-09f7-47e6-b5de-1a0902cbc26e)


### Processed frames:

![image](https://github.com/user-attachments/assets/d8c5ded2-f60c-4651-abb7-6275118f069b)


### Processed frames (DEBUG MODE):

![image](https://github.com/user-attachments/assets/355871dd-30da-48b8-b89d-58f6a950331a)

