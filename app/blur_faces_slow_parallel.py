import cv2
import os
import sys
import numpy as np
import time
import torch
from retinaface import RetinaFace

def blur_faces_in_directory(input_dir, output_dir):
    # Ensure the output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    files = sorted(os.listdir(input_dir))

    # Filter image files
    image_files = [f for f in files if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
    total_files = len(image_files)
    processed_files = 0

    if total_files == 0:
        print("No image files found in the input directory.", flush=True)
        return

    # Start time for ETA calculation
    start_time = time.time()

    # Set up multi-GPU processing
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = RetinaFace().to(device)
    model = torch.nn.DataParallel(model)

    # Loop through all image files in the input directory
    for idx, filename in enumerate(image_files):

        input_path = os.path.join(input_dir, filename)

        if debug_mode:
            # add debug.png to the output path if debug mode is enabled
            output_path = os.path.join(output_dir, filename) + ".debug.png"
        else:
            # add processed.png to the output path if debug mode is disabled
            output_path = os.path.join(output_dir, filename) + ".blurred.png"

        # Start line with file name
        print(f"* processing: {input_path} to {output_path}", end="", flush=True)

        # skip if the output file already exists
        if os.path.exists(output_path):
            print(f", skipping as {output_path} already exists", flush=True)
            continue

        # Read the image
        image = cv2.imread(input_path)
        if image is None:
            print(f", could not open or find the image: {filename}", flush=True)
            exit(1)

        print(", detecting", end="", flush=True)
        detection_start_time = time.time()
        faces = model(image)  # Use the model for face detection
        detection_end_time = time.time()
        detection_time = detection_end_time - detection_start_time
        print(f" ({detection_time:.2f}s)", end="", flush=True)

        face_count = 0  # Counter for faces in the current image

        if faces:
            print(f", ", end="", flush=True)
            for face_id, face_info in faces.items():
                facial_area = face_info['facial_area']
                x1, y1, x2, y2 = facial_area

                score = face_info['score']
                print(f"[{score:.2f}+]", end="", flush=True)

                # Ensure coordinates are within image bounds
                x1 = max(0, x1)
                y1 = max(0, y1)
                x2 = min(image.shape[1], x2)
                y2 = min(image.shape[0], y2)

                # Validate dimensions
                if x1 >= x2 or y1 >= y2:
                    print(" , ERROR: invalid detection", end="", flush=True)
                    exit(1)

                # Extract the face region
                face_roi = image[y1:y2, x1:x2]
                if face_roi.size == 0:
                    throw ("Error: face_roi is empty")

                # Blur the face region
                face_roi_blurred = cv2.GaussianBlur(
                  face_roi, # Input image
                  (99, 99),  # Kernel size
                  30) # SigmaX
                image[y1:y2, x1:x2] = face_roi_blurred

                if debug_mode:
                    # Draw a rectangle around the face
                    color = (0, 255, 0) if score >= score_threshold else (0, 0, 255)
                    cv2.rectangle(image, (x1, y1), (x2, y2), color, 4)
                    text = f"{score:.2f}"
                    text_y = y2 + 20
                    if text_y > image.shape[0]:
                        text_y = y1 - 10
                    cv2.putText(image, text, (x1, text_y), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

                # Increment face count and print a dot
                face_count += 1

        print(f", {face_count} face(s)", end="")
        print(f", saving", end="", flush=True)
        cv2.imwrite(output_path, image)

        # Update progress
        processed_files += 1
        elapsed_time = time.time() - start_time
        average_time_per_file = elapsed_time / processed_files
        files_left = total_files - processed_files
        eta = average_time_per_file * files_left

        # Calculate days, hours, and minutes
        eta_days = int(eta // (24 * 3600))
        eta_hours = int((eta % (24 * 3600)) // 3600)
        eta_minutes = int((eta % 3600) // 60)

        percent_complete = (processed_files / total_files) * 100

        # Print completion message for the current file
        print(f", {processed_files}/{total_files} files ({percent_complete:.2f}%). "
              f"ETA: {eta_days}d {eta_hours}h {eta_minutes}m", flush=True)

    print("Processing complete.")

if __name__ == "__main__":
    input_dir = os.getenv('INPUT_DIR', '/input')
    output_dir = os.getenv('OUTPUT_DIR', '/output')
    debug_mode = os.getenv('DEBUG', '')
    score_threshold = float(os.getenv('THRESHOLD', 0.90))

    if not input_dir or not output_dir:
        print("Error: INPUT_DIR or OUTPUT_DIR environment variables are not set.")
        sys.exit(1)

    blur_faces_in_directory(input_dir, output_dir)