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
    files_checked = 0
    file_check_times = []
    percent_changes = []  # Store percent complete over time
    time_changes = []  # Store timestamps of these percent changes

    if total_files == 0:
        print("No image files found in the input directory.", flush=True)
        return

    # Loop through all image files in the input directory
    for idx, filename in enumerate(image_files):
        files_checked += 1
        check_time = time.time()
        file_check_times.append(check_time)

        # Record percent complete and time
        percent_complete = (files_checked / total_files) * 100
        percent_changes.append(percent_complete)
        time_changes.append(check_time)

        # Keep only data from the last 20 seconds
        while time_changes and (check_time - time_changes[0]) > 20:
            time_changes.pop(0)
            percent_changes.pop(0)

        input_path = os.path.join(input_dir, filename)

        if debug_mode:
            output_path = os.path.join(output_dir, filename) + ".debug.png"
        else:
            output_path = os.path.join(output_dir, filename) + ".blurred.png"

        # Skip if the output file already exists
        if os.path.exists(output_path):
            print(f", skipping as {output_path} already exists", flush=True)
            continue

        # Lock file management omitted for brevity

        # Read the image and detect faces (omitted for brevity)
        # ...

        # Update processed_files count
        processed_files += 1

        # Calculate FPS if at least 100 files have been checked
        if len(file_check_times) >= 100:
            total_time_in_fps = file_check_times[-1] - file_check_times[0]
            if total_time_in_fps > 0:
                fps = len(file_check_times) / total_time_in_fps
            else:
                fps = float('inf')
        else:
            fps = 0

        # Calculate dynamic ETA based on the percent change in the last 20 seconds
        if len(percent_changes) >= 2:
            percent_change_rate = (percent_changes[-1] - percent_changes[0]) / (time_changes[-1] - time_changes[0])
            if percent_change_rate > 0:
                time_left_seconds = (100 - percent_complete) / percent_change_rate
            else:
                time_left_seconds = float('inf')  # To handle the case of no progress

            eta_hours = int(time_left_seconds // 3600)
            eta_minutes = int((time_left_seconds % 3600) // 60)
            eta_seconds = int(time_left_seconds % 60)

            # Print dynamic ETA
            print(f", ETA: {eta_hours}h {eta_minutes}m {eta_seconds}s", end="", flush=True)

        # Print completion message for the current file
        if len(file_check_times) >= 100:
            print(f", {processed_files}/{total_files} files ({percent_complete:.2f}%). FPS: {fps:.2f}.", flush=True)
        else:
            print(f", {processed_files}/{total_files} files ({percent_complete:.2f}%). ", flush=True)

    print("Processing complete.")
