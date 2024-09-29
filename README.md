# What is it for ?

This is a simple PoC (proof of concept) how to blur faces in a video using AI and ffmpeg.

# How it works

1. Decompose video into frames using ffmpeg
2. Process each frame with AI models to detect faces and blur them
3. Compose video back from frames using ffmpeg

# What you need:

* Docker

# How to use it

### Step 1: Decompose video into frames, each frame in a file with the index number:
```
# Preserve original
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -fps_mode passthrough -q:v 0 -c:v png "/data/input/frame_%10d.png"

# Scale to 640px width
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -vf "scale=640:-1" -q:v 0 -c:v png "/data/input/frame_%10d.png"

# Scale to 640px width and custom FPS
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -r 10 -vf "scale=640:-1" -q:v 0 -c:v png "/data/input/frame_%10d.png"

# Custom FPS
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -r 5 -q:v 0 -c:v png "/data/input/frame_%10d.png"

# With extra info overlay
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -r 5 -vf "drawtext=text='%{pts\:hms}':x=w-tw-10:y=h-th-10:fontcolor=white:fontsize=24" -q:v 0 -c:v png "/data/input/frame_%010d.png"
docker run -v $(pwd):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -r 5 -vf "drawtext=text='T: %{pts\:hms}':x=w-tw-10:y=h-th-100:fontcolor=white:fontsize=24,drawtext=text='IF: %{frame_num}':x=w-tw-10:y=h-th-70:fontcolor=white:fontsize=24,drawtext=text='OF: %{n}':x=w-tw-10:y=h-th-40:fontcolor=white:fontsize=24" -q:v 0 -c:v png "/data/input/frame_%010d.png"
```

### Step 2: build the docker image for the face blurer:
```
# FOR CPU
docker build -f Dockerfile --progress=plain . -t blurer

# FOR GPU 
docker build -f Dockerfile.gpu --progress=plain . -t blurer 
```

### Step 3: Process frames, detect and blur faces in each frame from the input directory:
```
# slow but accurate:
docker run --rm --gpus all -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py

# faster but less accurate:
docker run --rm --gpus all v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/depface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_fast.py

# faster but less accurate in DEBUG mode (drawing rectangles extra info around faces):
docker run --rm --gpus all -v ./app:/app -e DEBUG=1 -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/depface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_fast.py

# Multi GPU, with single GPU #0 selected:
docker run --rm --gpus all -e CUDA_VISIBLE_DEVICES=0 -e DEBUG=1 -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py 
```

Environment variables:
* `DEBUG` - if set to `1` will draw rectangles around faces and print extra info
* `THRESHOLD` - threshold for face detection, default is (see in the code)

### Step 3: Compose video back from frames:
```
docker run -v $(pwd):/data linuxserver/ffmpeg -r 50  -f image2 -s 1920x1080 -i "/data/output/frame_%10d.png.blurred.png" -vcodec libx264 -crf 20 -pix_fmt yuv420p "/data/output/video1-blurred.mp4"

docker run -v $(pwd):/data linuxserver/ffmpeg -r 30  -f image2 -s 1920x1080 -i "/data/output/frame_%10d.png.debug.png" -vcodec libx264 -crf 0 -pix_fmt yuv420p "/data/output/video8-debug.mp4"
```


# Recommended flow of work:
* Decompose video into frames
* Process frames with fast model
* Check the quality of the processing, delete frames that are not good enough
* Process frames with slow model
* Compose video back from frames 

# References:
* https://github.com/markusschmitz53/demo-face-blur

# FAQ

* Why do you break video into frames and then compose it back?
  * Because it's easier to preview the frames with a file manager if you want to check the quality of the processing.
  * Because it's easier to delete the frames with a file manager if you want to reprocess just a part of the video.
  * Because it's easier to process frames with AI models and then compose video back. Also, it's easier to debug and improve the process.
  * Bacause it's easier to parallelize processing of frames by running multiple instances of the application in parallel.

* How do I debug the container?
```
docker run --rm  -it --privileged --gpus all -v ./app:/app -v ./input:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer bash
```

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



### TensorDock remote GPU examples:

```

export TPORT=XXXX ; export THOST=XXX.XXX.XXX.XXX ; export TUSER=user ;

# inject keys
cat ~/.ssh/id_rsa.pub | ssh $TUSER@$THOST -p $TPORT "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys

# log in
ssh $TUSER@$THOST -p $TPORT"
 
# provision host
sudo apt-get install -y mc joe htop multitail docker-compose screen docker-buildx-plugin pydf iotop
nvidia-smi

sudo curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg   && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |     sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

cd /home/$TUSER
git clone https://github.com/ChieftainY2k/face-blurer.git

# upload files TO remote server
rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" ./input/video* $TUSER@$THOST:/home/$TUSER/face-blurer/input/

# download files FROM remote server
rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" $TUSER@$THOST:/home/$TUSER/face-blurer/output/ /tmp/output-$THOST/

# watch progress and GPU usage
watch -n 1 "nvidia-smi; ls output/*.lock"

```