import cv2
import os
import sys
import numpy as np
import time
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
        print("No image files found in the input directory.")
        sys.stdout.flush()
        return

    # Start time for ETA calculation
    start_time = time.time()

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
        print(f"* processing: {input_path} to {output_path}", end="")
        sys.stdout.flush()

        # skip if the output file already exists
        if os.path.exists(output_path):
            print(f", skipping as {output_path} already exists")
            sys.stdout.flush()
            continue

        # Read the image
        image = cv2.imread(input_path)
        if image is None:
            print(f", could not open or find the image: {filename}")
            sys.stdout.flush()
            exit(1)

        print(", detecting", end="")
        sys.stdout.flush()
        detection_start_time = time.time()
        faces = RetinaFace.detect_faces(image)
        detection_end_time = time.time()
        detection_time = detection_end_time - detection_start_time
        print(f" ({detection_time:.2f}s)", end="")
        sys.stdout.flush()

        face_count = 0  # Counter for faces in the current image

        if faces:
            for face_id, face_info in faces.items():
                # Each face_info contains 'facial_area' and 'landmarks'
                facial_area = face_info['facial_area']
                x1, y1, x2, y2 = facial_area

                # Ensure coordinates are within image bounds
                x1 = max(0, x1)
                y1 = max(0, y1)
                x2 = min(image.shape[1], x2)
                y2 = min(image.shape[0], y2)

                # Validate dimensions
                if x1 >= x2 or y1 >= y2:
                    print(" , warning: invalid detection", end="")
                    sys.stdout.flush()
                    continue  # Skip invalid detections

                # Extract the face region
                face_roi = image[y1:y2, x1:x2]
                if face_roi.size == 0:
                    print(" , warning: empty region", end="")
                    sys.stdout.flush()
                    continue  # Skip if the face region is empty

                # Blur the face region
                face_roi_blurred = cv2.GaussianBlur(
                  face_roi, # Input image
                  (99, 99),  # Kernel size
                  30) # SigmaX
                image[y1:y2, x1:x2] = face_roi_blurred

                # Increment face count and print a dot
                face_count += 1
                #print(".", end="")
                #sys.stdout.flush()

        print(f", {face_count} face(s)", end="")
        print(f", saving", end="")
        sys.stdout.flush()
        #cv2.imwrite(output_path, image, [int(cv2.IMWRITE_JPEG_QUALITY), 100])
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
              f"ETA: {eta_days}d {eta_hours}h {eta_minutes}m")
        sys.stdout.flush()

    print("Processing complete.")

if __name__ == "__main__":
    input_dir = os.getenv('INPUT_DIR', '/input')
    output_dir = os.getenv('OUTPUT_DIR', '/output')
    debug_mode = os.getenv('DEBUG', '')

    if not input_dir or not output_dir:
        print("Error: INPUT_DIR or OUTPUT_DIR environment variables are not set.")
        sys.exit(1)

    blur_faces_in_directory(input_dir, output_dir)