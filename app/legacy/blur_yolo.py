import cv2
import os
import sys
import numpy as np
import time
import fcntl
import shutil
from ultralytics import YOLO  # Import YOLOv8

def blur_people_in_directory(input_dir, output_dir):
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
        print("No image files found in the input directory.", flush=True)
        return

    model = YOLO('yolov8x.pt')

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

        if debug_mode:
            output_path = os.path.join(output_dir, filename) + ".debug.png"
        else:
            output_path = os.path.join(output_dir, filename) + ".blurred.png"

        print(f"* [FPS: {fps:05.2f}]", end="", flush=True)
        print(f"[ETA: {eta_hours:02}h {eta_minutes:02}m {eta_seconds:02}s]", end="", flush=True)
        print(f"[{percent_complete:05.2f}%]", end="", flush=True)
        print(f"[{files_checked:010}/{total_files:010}]", end="", flush=True)
        print(f" {input_path} -> {output_path}", end="", flush=True)

        if os.path.exists(output_path):
            print(f", skipping as {output_path} already exists", flush=True)
            continue

        lock_path = output_path + '.lock'
        try:
            fd_lock = os.open(lock_path, os.O_CREAT | os.O_WRONLY)
            fcntl.flock(fd_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print(f", skipping as file {lock_path} is locked", flush=True)
            continue

        try:
            image = cv2.imread(input_path)
            if image is None:
                print(f", could not open or find the image: {filename}", flush=True)
                continue

            print(", detecting", end="", flush=True)
            detection_start_time = time.time()

            # Perform person detection using YOLOv8
            results = model(image)
            detection_end_time = time.time()
            detection_time = detection_end_time - detection_start_time
            print(f" ({detection_time:.2f}s)", end="", flush=True)

            person_count = 0

            if results:
                print(f", ", end="", flush=True)
                for result in results:
                    for box in result.boxes:
                        class_id = int(box.cls[0])  # Get the class ID
                        if class_id != 0:  # 0 corresponds to 'person' in COCO dataset
                            continue

                        # Get bounding box coordinates and confidence score
                        x1, y1, x2, y2 = map(int, box.xyxy[0])  # YOLOv8 returns boxes in [x1, y1, x2, y2] format
                        score = box.conf.item()
                        if score < score_threshold:
                            continue
                        print(f"[{score:.2f}+]", end="", flush=True)

                        x1 = max(0, x1)
                        y1 = max(0, y1)
                        x2 = min(image.shape[1], x2)
                        y2 = min(image.shape[0], y2)

                        if x1 >= x2 or y1 >= y2:
                            print(" , ERROR: invalid detection", end="", flush=True)
                            continue

                        person_roi = image[y1:y2, x1:x2]
                        if person_roi.size == 0:
                            print(" , ERROR: person_roi is empty", end="", flush=True)
                            continue

                        # Blur the detected person region
                        person_roi_blurred = cv2.GaussianBlur(person_roi, (99, 99), 30)
                        image[y1:y2, x1:x2] = person_roi_blurred

                        if debug_mode:
                            color = (0, 255, 0) if score >= score_threshold else (0, 0, 255)
                            cv2.rectangle(image, (x1, y1), (x2, y2), color, 4)
                            text = f"{score:.2f}"
                            text_y = y2 + 20
                            if text_y > image.shape[0]:
                                text_y = y1 - 10
                            cv2.putText(image, text, (x1, text_y), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

                        person_count += 1

            print(f", {person_count} person(s)", end="", flush=True)

            tmp_output_path = output_path + ".tmp.png"

            save_start_time = time.time()
            if results:
                # Save the image
                print(f", saving frame", end="", flush=True)
                cv2.imwrite(tmp_output_path, image)
            else:
                # copy file from input to output
                print(f", copying file", end="", flush=True)
                shutil.copyfile(input_path, tmp_output_path)

            save_time = time.time() - save_start_time
            print(f" ({save_time:.2f}s)", end="", flush=True)

            # Rename the temporary output file to the final output file
            os.rename(tmp_output_path, output_path)

            processed_files += 1
        finally:
            try:
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
            eta_seconds = int((time_left_seconds % 60))

        print(f", completed.", flush=True)

    print("Processing complete.")

if __name__ == "__main__":
    # Retrieve environment variables or set default paths
    input_dir = os.getenv('INPUT_DIR', '/input')
    output_dir = os.getenv('OUTPUT_DIR', '/output')
    # Initialize variables from environment variables or defaults
    debug_mode = os.getenv('DEBUG', '').lower() in ['1', 'true', 'yes']
    score_threshold = float(os.getenv('THRESHOLD', 0.90))

    blur_people_in_directory(input_dir, output_dir)
