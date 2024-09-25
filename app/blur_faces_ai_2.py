import cv2
import os
import sys
import numpy as np
import time

def blur_faces_in_directory(input_dir, output_dir, models_dir):
    # Ensure the output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    files = sorted(os.listdir(input_dir))

    # Filter image files
    image_files = [f for f in files if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
    total_files = len(image_files)
    processed_files = 0

    if total_files == 0:
        print("No image files found in the input directory.")
        return

    # Load the YuNet face detector
    model_path = os.path.join(models_dir, "face_detection_yunet_2023mar.onnx")
    detector = cv2.FaceDetectorYN_create(
        model=model_path,
        config="",
        input_size=(1900, 1200),  # You can adjust the input size for performance/accuracy trade-off
        score_threshold=0.5,    # Confidence threshold
        nms_threshold=0.3, # Non-maximum suppression threshold
        top_k=20, # Maximum number of detections
        backend_id=cv2.dnn.DNN_BACKEND_DEFAULT,
        target_id=cv2.dnn.DNN_TARGET_CPU
    )

    # Start time for ETA calculation
    start_time = time.time()

    # Loop through all image files in the input directory
    for idx, filename in enumerate(image_files):
        input_path = os.path.join(input_dir, filename)

        # Read the image
        image = cv2.imread(input_path)
        if image is None:
            print(f"\nCould not open or find the image: {filename}")
            continue

        # Prepare the image
        h_img, w_img, _ = image.shape
        detector.setInputSize((w_img, h_img))

        # Detect faces
        faces = detector.detect(image)

        # Start line with file name
        print(f"Processing: {input_path}", end="")
        sys.stdout.flush()

        face_count = 0  # Counter for faces in the current image

        # faces[1] contains the detection results
        if faces[1] is not None:
            for face in faces[1]:
                # Each face has 15 elements: [x1, y1, w, h, score, ...landmarks]
                x, y, w, h = face[:4]
                x = int(x)
                y = int(y)
                w = int(w)
                h = int(h)

                # Ensure coordinates are within image bounds
                x1 = max(0, x)
                y1 = max(0, y)
                x2 = min(w_img, x + w)
                y2 = min(h_img, y + h)

                # Validate dimensions
                if x1 >= x2 or y1 >= y2:
                    continue  # Skip invalid detections

                # Extract the face region
                face_roi = image[y1:y2, x1:x2]
                if face_roi.size == 0:
                    continue  # Skip if the face region is empty

                # Blur the face region
                face_roi_blurred = cv2.GaussianBlur(face_roi, (99, 99), 30)
                image[y1:y2, x1:x2] = face_roi_blurred

                # Increment face count and print a dot
                face_count += 1
                print(".", end="")
                sys.stdout.flush()

        # Save the resulting image to the output directory
        output_path = os.path.join(output_dir, filename)
        # Write image with max quality
        cv2.imwrite(output_path, image, [int(cv2.IMWRITE_JPEG_QUALITY), 100])

        # Update progress
        processed_files += 1
        elapsed_time = time.time() - start_time
        average_time_per_file = elapsed_time / processed_files
        files_left = total_files - processed_files
        eta = average_time_per_file * files_left

        percent_complete = (processed_files / total_files) * 100

        # Print completion message for the current file
        print(f" processed {processed_files}/{total_files} files ({percent_complete:.2f}% complete). "
              f"ETA: {int(eta // 60)}m {int(eta % 60)}s")
        sys.stdout.flush()

    print("Processing complete.")

if __name__ == "__main__":
    input_dir = os.getenv('INPUT_DIR', '/input')
    output_dir = os.getenv('OUTPUT_DIR', '/output')
    models_dir = os.getenv('MODELS_DIR', '/opencv_zoo/models/face_detection_yunet')

    if not input_dir or not output_dir or not models_dir:
        print("Error: INPUT_DIR, OUTPUT_DIR, or MODELS_DIR environment variables are not set.")
        sys.exit(1)

    blur_faces_in_directory(input_dir, output_dir, models_dir)
