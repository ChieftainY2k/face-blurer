import cv2
import os
import sys
import numpy as np  # Add this line to import numpy

def blur_faces_in_directory(input_dir, output_dir, models_dir):
    # Ensure the output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    files = sorted(os.listdir(input_dir))

    # Load the DNN face detector model
    model_path = os.path.join(models_dir, "res10_300x300_ssd_iter_140000.caffemodel")
    config_path = os.path.join(models_dir, "deploy.prototxt")

    net = cv2.dnn.readNetFromCaffe(config_path, model_path)

    # Loop through all files in the input directory
    for filename in files:
        input_path = os.path.join(input_dir, filename)

        # Check if it's an image file (you can extend this with more file types)
        if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            # Read the image
            print(f"Processing: {input_path}", end="")
            sys.stdout.flush()
            image = cv2.imread(input_path)
            if image is None:
                print(f"Could not open or find the image: {filename}")
                continue

            # Prepare the image for DNN face detection
            (h, w) = image.shape[:2]
            blob = cv2.dnn.blobFromImage(cv2.resize(image, (300, 300)), 1.0,
                                         (300, 300), (104.0, 177.0, 123.0))

            # Set the input to the network
            net.setInput(blob)
            detections = net.forward()

            # Loop over the detections
            for i in range(0, detections.shape[2]):
                confidence = detections[0, 0, i, 2]

                # Filter out weak detections by ensuring the confidence is above a threshold
                if confidence > 0.5:  # Adjust the threshold for more accurate results
                    box = detections[0, 0, i, 3:7] * np.array([w, h, w, h])  # np is used here
                    (startX, startY, endX, endY) = box.astype("int")

                    # Ensure the bounding box is within the image
                    if startX < 0 or startY < 0 or endX >= w or endY >= h:
                        continue

                    # Blur the face region
                    face = image[startY:endY, startX:endX]
                    face = cv2.GaussianBlur(face, (99, 99), 30)
                    image[startY:endY, startX:endX] = face
                    print(".", end="")
                    sys.stdout.flush()

            # Save the resulting image to the output directory
            output_path = os.path.join(output_dir, filename)
            # Write image with max quality
            cv2.imwrite(output_path, image, [int(cv2.IMWRITE_JPEG_QUALITY), 100])
            print(f" done.")
            sys.stdout.flush()

if __name__ == "__main__":
    input_dir = os.getenv('INPUT_DIR', '/input')
    output_dir = os.getenv('OUTPUT_DIR', '/output')
    models_dir = os.getenv('MODELS_DIR', '/models')

    if not input_dir or not output_dir or not models_dir:
        print("Error: INPUT_DIR, OUTPUT_DIR, or MODELS_DIR environment variables are not set.")
        sys.exit(1)

    blur_faces_in_directory(input_dir, output_dir, models_dir)
