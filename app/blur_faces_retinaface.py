import cv2
import os
import sys
import numpy as np
import time
import fcntl
import shutil
import json
import gc
from retinaface import RetinaFace

def blur_face(image, x1, y1, x2, y2):
    face_roi = image[y1:y2, x1:x2]
    face_roi_blurred = cv2.GaussianBlur(face_roi, (99, 99), 30)
    image[y1:y2, x1:x2] = face_roi_blurred

def draw_frame(image, x1, y1, x2, y2, score, score_threshold, color_above=(0, 255, 0), color_below=(0, 0, 255)):
    color = color_above if score >= score_threshold else color_below
    cv2.rectangle(image, (x1, y1), (x2, y2), color, 4)
    score_percent = score * 100
    text = f"{score_percent:.2f}%"
    text_y = y2 + 20
    if text_y > image.shape[0]:
        text_y = y1 - 10
    cv2.putText(image, text, (x1, text_y), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

def process_previous_frames(idx, image_files, output_dir, image, score_threshold_decimal, score_threshold, is_debug_mode):
    prev_blurs_applied = False
    max_prev_frames = 10
    for i in range(1, max_prev_frames + 1):
        if idx >= i:
            prev_idx = idx - i
            prev_filename = image_files[prev_idx]
            prev_metadata_path = os.path.join(output_dir, prev_filename) + f".{score_threshold_decimal}.metadata.json"
            if os.path.exists(prev_metadata_path):
                with open(prev_metadata_path, 'r') as json_file:
                    prev_face_data = json.load(json_file)
                if prev_face_data:
                    print(f", found blurs from {prev_idx}", end="", flush=True)
                    for face in prev_face_data:
                        position = face['position']
                        score = face['score']
                        x1 = position['x1']
                        y1 = position['y1']
                        x2 = position['x2']
                        y2 = position['y2']
                        if score >= score_threshold:
                            blur_face(image, x1, y1, x2, y2)
                        if is_debug_mode:
                            # Define colors based on how many frames back
                            intensity = 128 - (i - 1) * 16
                            intensity = max(intensity, 0)
                            color_above = (0, intensity, 0)
                            color_below = (0, 0, intensity)
                            draw_frame(image, x1, y1, x2, y2, score, score_threshold, color_above, color_below)
                        prev_blurs_applied = True
    return prev_blurs_applied

def blur_faces_in_directory(input_dir, output_dir, is_debug_mode, score_threshold):
    # Ensure the output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    files = sorted(os.listdir(input_dir))

    # Filter image files
    image_files = [f for f in files if f.lower().endswith(('.png', '.jpg', '.jpeg'))]

    fps = 0
    eta_hours = 0
    eta_minutes = 0
    eta_seconds = 0
    percent_complete = 0

    total_files = len(image_files)
    processed_files = 0
    files_checked = 0
    file_check_times = []  # Stores times for the last 100 file checks
    percent_changes = []  # Store percent complete over time
    time_changes = []     # Store timestamps of these percent changes

    if total_files == 0:
        raise Exception("No image files found in the input directory.")

    # Loop through all image files in the input directory
    for idx, filename in enumerate(image_files):
        start_loop_time = time.time()
        files_checked += 1
        check_time = time.time()

        # Append current check time and ensure we only keep the last 100 entries
        file_check_times.append(check_time)
        if len(file_check_times) > 100:
            file_check_times.pop(0)

        # Record percent complete and time
        percent_complete = (files_checked / total_files) * 100
        percent_changes.append(percent_complete)
        time_changes.append(check_time)

        # Keep only data from the last 20 seconds
        while time_changes and (check_time - time_changes[0]) > 20:
            time_changes.pop(0)
            percent_changes.pop(0)

        input_path = os.path.join(input_dir, filename)

        metadata_path = os.path.join(output_dir, filename) + f".{score_threshold_decimal}.metadata.json"
        if is_debug_mode:
            output_path = os.path.join(output_dir, filename) + ".debug.png"
        else:
            output_path = os.path.join(output_dir, filename) + ".blurred.png"

        print()
        print(f"* [FPS: {fps:05.2f}]", end="", flush=True)
        print(f"[ETA: {eta_hours:02}h {eta_minutes:02}m {eta_seconds:02}s]", end="", flush=True)
        print(f"[{percent_complete:05.2f}%]", end="", flush=True)
        print(f"[{files_checked:010}/{total_files:010}]", end="", flush=True)
        print(f"[{input_path}][{output_path}]", end="", flush=True)

        fd_lock = None
        try:

            lock_path = output_path + '.lock'
#             if os.path.exists(metadata_path):
#                 print(f", skipping as file {lock_path} exists", end="", flush=True)
#                 continue
            try:
                fd_lock = os.open(lock_path, os.O_CREAT | os.O_WRONLY)
                fcntl.flock(fd_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                os.close(fd_lock)
                fd_lock = None
                print(f", skipping as file {lock_path} is locked", end="", flush=True)
                continue

            if is_pass1:
                if os.path.exists(metadata_path):
                    print(f", metadata file exists, skipping processing for pass 1", end="", flush=True)
                    continue

            if is_pass2:
                if os.path.exists(output_path):
                    print(f", {output_path} already exists, skipping for pass 2", end="", flush=True)
                    continue

            # Read the current image
            image = cv2.imread(input_path)
            if image is None:
                raise Exception(f", could not open or find the image: {filename}")

            retina_threshold = score_threshold
            if is_debug_mode:
                # Use a lower threshold for debug mode
                retina_threshold = 0.01

            # Process previous frames
            if is_pass2:
                prev_blurs_applied = process_previous_frames(
                    idx, image_files, output_dir, image,
                    score_threshold_decimal, score_threshold, is_debug_mode
                )

            #load metadata
            metadata_data = None
            if os.path.exists(metadata_path):
                with open(metadata_path, 'r') as json_file:
                    metadata_data = json.load(json_file)

            if metadata_data:
                print(f", metadata found", end="", flush=True)
                detected_faces = None
            else:
                print(f", detecting[{retina_threshold}][{score_threshold}]", end="", flush=True)
                detection_start_time = time.time()
                detected_faces = RetinaFace.detect_faces(image, threshold=retina_threshold)
                detection_end_time = time.time()
                detection_time = detection_end_time - detection_start_time
                print(f" ({detection_time:.2f}s)", end="", flush=True)

            detected_faces_count = 0
            detected_faces_data = []

            if detected_faces:
                print(f", ", end="", flush=True)
                for face_id, face_info in detected_faces.items():
                    facial_area = face_info['facial_area']
                    x1, y1, x2, y2 = facial_area
                    score = face_info['score']
                    if score >= score_threshold:
                        print(f"[{score:.2f}+]", end="", flush=True)
                    else:
                        print(f"[{score:.2f}-]", end="", flush=True)

                    x1 = max(0, x1)
                    y1 = max(0, y1)
                    x2 = min(image.shape[1], x2)
                    y2 = min(image.shape[0], y2)

                    extra_percentage = 0.3
                    x1 = max(0, x1 - int((x2 - x1) * extra_percentage))
                    y1 = max(0, y1 - int((y2 - y1) * extra_percentage))
                    x2 = min(image.shape[1], x2 + int((x2 - x1) * extra_percentage))
                    y2 = min(image.shape[0], y2 + int((y2 - y1) * extra_percentage))

                    if x1 >= x2 or y1 >= y2:
                        raise Exception(f"Invalid face area, {x1}, {y1}, {x2}, {y2}")

                    if is_pass2:
                        if score >= score_threshold:
                            blur_face(image, x1, y1, x2, y2)
                        if is_debug_mode:
                            draw_frame(image, x1, y1, x2, y2, score, score_threshold)

                    detected_faces_data.append({
                        'score': float(score),
                        'score_threshold': float(score_threshold),
                        'position': {'x1': int(x1), 'y1': int(y1), 'x2': int(x2), 'y2': int(y2)}
                    })

                    detected_faces_count += 1

                print(f", {detected_faces_count} face(s)", end="", flush=True)
            else:
                print(f", no faces detected", end="", flush=True)

            if not metadata_data:
                print(f", saving metadata", end="", flush=True)
                json_output_path = os.path.join(output_dir, filename) + f".{score_threshold_decimal}.metadata.json"
                json_output_path_tmp = json_output_path + ".tmp"
                with open(json_output_path_tmp, 'w') as json_file:
                    json.dump(detected_faces_data, json_file, indent=4)
                os.rename(json_output_path_tmp, json_output_path)
            else:
                if is_pass2:
                    print(f", blurring from metadata", end="", flush=True)
                    for face in metadata_data:
                        position = face['position']
                        score = face['score']
                        x1 = position['x1']
                        y1 = position['y1']
                        x2 = position['x2']
                        y2 = position['y2']
                        if score >= score_threshold:
                            blur_face(image, x1, y1, x2, y2)
                        if is_debug_mode:
                            draw_frame(image, x1, y1, x2, y2, score, score_threshold)
                        prev_blurs_applied = True

            if is_pass2:

                tmp_output_path = output_path + ".tmp.png"
                save_start_time = time.time()
                if detected_faces or prev_blurs_applied:
                    # Save the image
                    print(f", saving frame", end="", flush=True)
                    cv2.imwrite(tmp_output_path, image)
                else:
                    # Copy file from input to output
                    print(f", copying file", end="", flush=True)
                    shutil.copyfile(input_path, tmp_output_path)

                os.rename(tmp_output_path, output_path)
                save_time = time.time() - save_start_time
                print(f" ({save_time:.2f}s)", end="", flush=True)

            processed_files += 1

        finally:
            try:
                if fd_lock:
                    os.close(fd_lock)
                    os.remove(lock_path)
            except OSError as e:
                print(f", warning: cannot remove lock file {lock_path}: {e}", flush=True)

        # Calculate FPS if at least 2 files have been checked
        if len(file_check_times) >= 2:
            total_time_in_fps = file_check_times[-1] - file_check_times[0]
            if total_time_in_fps > 0:
                fps = len(file_check_times) / total_time_in_fps
            else:
                fps = float('inf')
        else:
            fps = 0

        # Calculate dynamic ETA
        if len(percent_changes) >= 2:
            percent_change_rate = (percent_changes[-1] - percent_changes[0]) / (time_changes[-1] - time_changes[0])
            if percent_change_rate > 0:
                time_left_seconds = (100 - percent_complete) / percent_change_rate
                time_left_seconds = max(time_left_seconds, 0)
            else:
                time_left_seconds = float('inf')

            eta_hours = int(time_left_seconds // 3600)
            eta_minutes = int((time_left_seconds % 3600) // 60)
            eta_seconds = int(time_left_seconds % 60)

        del image
        gc.collect()
        print(f", completed.", end="", flush=True)

    print("Processing complete.")

if __name__ == "__main__":
    input_dir = os.getenv('INPUT_DIR', '/input')
    output_dir = os.getenv('OUTPUT_DIR', '/output')
    is_debug_mode = os.getenv('DEBUG', '').lower() in ['1', 'true', 'yes']

    process_mode = os.getenv('MODE', 'pass2') # pass1, pass2
    if process_mode not in ['pass1', 'pass2']:
        raise Exception("Error: MODE environment variable must be set to 'pass1' or 'pass2'.")
        sys.exit(1)

    is_pass1 = process_mode == 'pass1'
    is_pass2 = process_mode == 'pass2'

    score_threshold = os.getenv('THRESHOLD')
    if score_threshold:
        score_threshold = float(score_threshold)
    else:
        score_threshold = 0.20

    score_threshold_decimal = int(score_threshold * 1000)

    # Call the main processing function
    blur_faces_in_directory(input_dir, output_dir, is_debug_mode, score_threshold)
