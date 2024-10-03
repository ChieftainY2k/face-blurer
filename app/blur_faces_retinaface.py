import os
import sys
import time
import json
import shutil
import gc
import numpy as np
import cv2
import torch
from retinaface import RetinaFace
from torchvision import transforms
import fcntl

# Set device to CUDA if available
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

def blur_face(image_tensor, x1, y1, x2, y2, blocks=5):
    if x1 >= x2 or y1 >= y2:
        raise Exception(f"Invalid blur area, {x1}, {y1}, {x2}, {y2}")

    # Apply margin
    if blur_extra_margin_percent:
        x_margin = int((x2 - x1) * blur_extra_margin_percent)
        y_margin = int((y2 - y1) * blur_extra_margin_percent)
        x1 = max(0, x1 - x_margin)
        y1 = max(0, y1 - y_margin)
        x2 = min(image_tensor.shape[2], x2 + x_margin)
        y2 = min(image_tensor.shape[1], y2 + y_margin)

    face_roi = image_tensor[:, y1:y2, x1:x2]
    h, w = face_roi.shape[1:]

    # Calculate padding to make dimensions divisible by 'blocks'
    h_pad = (-h) % blocks
    w_pad = (-w) % blocks

    # Pad the face ROI if necessary
    if h_pad > 0 or w_pad > 0:
        face_roi = torch.nn.functional.pad(face_roi, (0, w_pad, 0, h_pad), mode='reflect')

    # Compute the size of each block
    h_padded, w_padded = face_roi.shape[1:]
    block_size_h = h_padded // blocks
    block_size_w = w_padded // blocks

    # Reshape and compute the mean color for each block
    face_roi = face_roi.unfold(1, block_size_h, block_size_h).unfold(2, block_size_w, block_size_w)
    face_roi = face_roi.contiguous().view(3, blocks, blocks, block_size_h, block_size_w)
    face_roi = face_roi.mean(dim=[3, 4], keepdim=True)
    face_roi = face_roi.expand(-1, -1, -1, block_size_h, block_size_w)
    face_roi = face_roi.contiguous().view(3, h_padded, w_padded)

    # Crop to original size
    face_roi = face_roi[:, :h, :w]
    image_tensor[:, y1:y2, x1:x2] = face_roi

def draw_frame(image_tensor, x1, y1, x2, y2, score, my_score_threshold, color_above=(0, 255, 0), color_below=(0, 0, 255)):
    color = torch.tensor(color_above if score >= my_score_threshold else color_below, device=device, dtype=torch.float32) / 255.0
    # Draw rectangle (approximate using tensor operations)
    thickness = 4
    image_tensor[:, y1:y1+thickness, x1:x2] = color.view(3, 1, 1)
    image_tensor[:, y2-thickness:y2, x1:x2] = color.view(3, 1, 1)
    image_tensor[:, y1:y2, x1:x1+thickness] = color.view(3, 1, 1)
    image_tensor[:, y1:y2, x2-thickness:x2] = color.view(3, 1, 1)
    # Optionally, add score text (requires more complex operations)

def process_other_frames(origin_idx, idx_from, idx_to, image_files, my_output_dir, image_tensor, my_score_threshold_decimal,
                         my_score_threshold, my_is_debug_mode):
    image_is_modified = False
    print(f", checking metadata #{idx_from}-#{idx_to}", end="", flush=True)
    for idx in range(idx_from, idx_to):
        prev_filename = image_files[idx]
        prev_metadata_path = os.path.join(my_output_dir, "metadata", f"{prev_filename}.{my_score_threshold_decimal}.metadata.json")

        # Wait for the file to be available
        if not os.path.exists(prev_metadata_path):
            print(f", waiting for metadata from #{idx}...", end="", flush=True)
            while not os.path.exists(prev_metadata_path):
                print(f".", end="", flush=True)
                time.sleep(5)

        with open(prev_metadata_path, 'r') as json_file:
            prev_face_data = json.load(json_file)

        if prev_face_data is None:
            raise Exception(f", metadata file {prev_metadata_path} is empty")

        if prev_face_data:
            data_length = len(prev_face_data)
            print(f", #F{idx + 1}({data_length})", end="", flush=True)
            for face in prev_face_data:
                position = face['position']
                score = face['score']
                x1 = position['x1']
                y1 = position['y1']
                x2 = position['x2']
                y2 = position['y2']
                if score >= my_score_threshold:
                    blur_face(image_tensor, x1, y1, x2, y2)
                if my_is_debug_mode:
                    # Define colors based on how many frames back
                    intensity = 255 - (abs(origin_idx - idx)) * 16
                    intensity = max(intensity, 0)
                    color_above_threshold = (0, intensity, 0)
                    color_below_threshold = (0, 0, intensity)
                    draw_frame(image_tensor, x1, y1, x2, y2, score, my_score_threshold, color_above_threshold,
                               color_below_threshold)
                image_is_modified = True
    return image_is_modified

def find_image_files(directory):
    image_files_list = []
    index = 1
    while True:
        file_name = f"frame_{index:010}.png"
        file_path = os.path.join(directory, file_name)
        if os.path.exists(file_path):
            image_files_list.append(file_name)
        else:
            break
        index += 1
    return image_files_list

def blur_faces_in_directory(input_dir, output_dir, is_debug_mode, score_threshold):
    # Ensure the output and metadata directories exist
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(os.path.join(output_dir, "metadata"), exist_ok=True)

    image_files_list = find_image_files(input_dir)
    total_files_count = len(image_files_list)
    processed_files = 0
    files_checked = 0
    file_check_times = []
    percent_changes = []
    time_changes = []

    if total_files_count == 0:
        raise Exception("No image files found in the input directory.")

    fps = 0
    eta_hours = 0
    eta_minutes = 0
    eta_seconds = 0
    percent_complete = 0

    for idx, filename in enumerate(image_files_list):
        start_loop_time = time.time()
        files_checked += 1
        check_time = time.time()

        # Append current check time and ensure we only keep the last 100 entries
        file_check_times.append(check_time)
        if len(file_check_times) > 100:
            file_check_times.pop(0)

        # Record percent complete and time
        percent_complete = (files_checked / total_files_count) * 100
        percent_changes.append(percent_complete)
        time_changes.append(check_time)

        # Keep only data from the last 20 seconds
        while time_changes and (check_time - time_changes[0]) > 20:
            time_changes.pop(0)
            percent_changes.pop(0)

        input_path = os.path.join(input_dir, filename)
        metadata_path = os.path.join(output_dir, "metadata", f"{filename}.{score_threshold_decimal}.metadata.json")
        output_path = os.path.join(output_dir, filename)
        if is_debug_mode:
            output_path += ".debug.png"
        else:
            output_path += ".blurred.png"

        lock_path = os.path.join(output_dir, filename) + ".lock"

        print()
        print(f"[#{idx}]", end="", flush=True)
        print(f"[FPS: {fps:05.2f}]", end="", flush=True)
        print(f"[ETA: {eta_hours:02}h {eta_minutes:02}m {eta_seconds:02}s]", end="", flush=True)
        print(f"[{percent_complete:05.2f}%]", end="", flush=True)
        print(f"[{files_checked:010}/{total_files_count:010}]", end="", flush=True)
        print(f"[{input_path}][{output_path}]", end="", flush=True)

        fd_lock = None
        try:
            try:
                fd_lock = os.open(lock_path, os.O_CREAT | os.O_WRONLY)
                fcntl.flock(fd_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                if fd_lock:
                    os.close(fd_lock)
                    fd_lock = None
                print(f", frame is locked, skipping", end="", flush=True)
                continue

            if is_pass1 and os.path.exists(metadata_path):
                print(f", metadata file exists, skipping processing for pass 1", end="", flush=True)
                continue

            if is_pass2 and os.path.exists(output_path):
                print(f", {output_path} already exists, skipping for pass 2", end="", flush=True)
                continue

            # Read the current image
            image = cv2.imread(input_path)
            if image is None:
                raise Exception(f", could not open or find the image: {filename}")
            image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

            # Convert image to tensor and move to GPU
            image_tensor = torch.from_numpy(image_rgb).permute(2, 0, 1).to(device, dtype=torch.float32) / 255.0

            retina_threshold = score_threshold
            if is_debug_mode:
                retina_threshold = 0.01  # Use a lower threshold for debug mode

            image_is_modified = False
            if is_pass2:
                blurs_applied_prev = False
                blurs_applied_next = False
                if (look_back > 0) and (idx > 0):
                    blurs_applied_prev = process_other_frames(
                        idx,
                        max(0, idx - look_back), idx,
                        image_files_list, output_dir, image_tensor,
                        score_threshold_decimal, score_threshold, is_debug_mode
                    )
                if (look_ahead > 0) and (idx < total_files_count - 1):
                    blurs_applied_next = process_other_frames(
                        idx,
                        idx + 1, min(total_files_count, idx + look_ahead + 1),
                        image_files_list, output_dir, image_tensor,
                        score_threshold_decimal, score_threshold, is_debug_mode
                    )
                image_is_modified = blurs_applied_prev or blurs_applied_next

            # Load metadata
            metadata_data = None
            if os.path.exists(metadata_path):
                with open(metadata_path, 'r') as json_file:
                    metadata_data = json.load(json_file)

            if metadata_data is not None:
                print(f", metadata found", end="", flush=True)
                detected_faces = None
            else:
                print(f", detecting[{retina_threshold}][{score_threshold}]", end="", flush=True)
                detection_start_time = time.time()
                detected_faces = RetinaFace.detect_faces(image_rgb, threshold=retina_threshold)
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
                    x2 = min(image_tensor.shape[2], x2)
                    y2 = min(image_tensor.shape[1], y2)

                    detected_faces_data.append({
                        'score': float(score),
                        'score_threshold': float(score_threshold),
                        'position': {'x1': int(x1), 'y1': int(y1), 'x2': int(x2), 'y2': int(y2)}
                    })

                    if is_pass2:
                        if score >= score_threshold:
                            blur_face(image_tensor, x1, y1, x2, y2)
                        if is_debug_mode:
                            draw_frame(image_tensor, x1, y1, x2, y2, score, score_threshold)
                        image_is_modified = True

                    detected_faces_count += 1

                print(f", {detected_faces_count} face(s)", end="", flush=True)
            else:
                print(f", no faces detected", end="", flush=True)

            if not metadata_data:
                print(f", saving metadata", end="", flush=True)
                json_output_path_tmp = metadata_path + ".tmp"
                with open(json_output_path_tmp, 'w') as json_file:
                    json.dump(detected_faces_data, json_file, indent=4)
                os.rename(json_output_path_tmp, metadata_path)
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
                            blur_face(image_tensor, x1, y1, x2, y2)
                        if is_debug_mode:
                            draw_frame(image_tensor, x1, y1, x2, y2, score, score_threshold)
                        image_is_modified = True

            if is_pass2:
                tmp_output_path = output_path + ".tmp.png"
                save_start_time = time.time()
                if image_is_modified:
                    # Save the image
                    print(f", saving frame", end="", flush=True)
                    image_output = (image_tensor * 255).permute(1, 2, 0).cpu().numpy().astype(np.uint8)
                    image_output_bgr = cv2.cvtColor(image_output, cv2.COLOR_RGB2BGR)
                    cv2.imwrite(tmp_output_path, image_output_bgr)
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

        # Clear GPU memory
        del image_tensor
        torch.cuda.empty_cache()
        gc.collect()
        print(f", completed.", end="", flush=True)

    print()
    print("Processing complete.")

if __name__ == "__main__":
    input_dir = os.getenv('INPUT_DIR', '/input')
    output_dir = os.getenv('OUTPUT_DIR', '/output')
    is_debug_mode = os.getenv('DEBUG', '').lower() in ['1', 'true', 'yes']

    blur_extra_margin_percent = os.getenv('BLUR_EXTRA')
    blur_extra_margin_percent = float(blur_extra_margin_percent) if blur_extra_margin_percent else 0.3

    look_ahead = os.getenv('BLUR_AHEAD')
    look_ahead = int(look_ahead) if look_ahead else 5

    look_back = os.getenv('BLUR_BACK')
    look_back = int(look_back) if look_back else 10

    process_mode = os.getenv('MODE', 'pass1')  # pass1, pass2
    if process_mode not in ['pass1', 'pass2']:
        raise Exception("Error: MODE environment variable must be set to 'pass1' or 'pass2'.")

    is_pass1 = process_mode == 'pass1'
    is_pass2 = process_mode == 'pass2'

    score_threshold = os.getenv('THRESHOLD')
    score_threshold = float(score_threshold) if score_threshold else 0.1
    score_threshold_decimal = int(score_threshold * 1000)

    # Call the main processing function
    blur_faces_in_directory(input_dir, output_dir, is_debug_mode, score_threshold)
