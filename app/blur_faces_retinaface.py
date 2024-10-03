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
    color = torch.tensor(color_above if score >= my_score_threshold else color_below, device=device, dtype=torch.uint8)
    # Draw rectangle (approximate using tensor operations)
    image_tensor[:, y1:y1+4, x1:x2] = color.view(3, 1, 1)
    image_tensor[:, y2-4:y2, x1:x2] = color.view(3, 1, 1)
    image_tensor[:, y1:y2, x1:x1+4] = color.view(3, 1, 1)
    image_tensor[:, y1:y2, x2-4:x2] = color.view(3, 1, 1)

def process_other_frames(origin_idx, idx_from, idx_to, image_files, my_output_dir, image_tensor, my_score_threshold_decimal,
                         my_score_threshold, my_is_debug_mode):
    image_is_modified = False
    for idx in range(idx_from, idx_to):
        prev_filename = image_files[idx]
        prev_metadata_path = os.path.join(my_output_dir, "metadata", f"{prev_filename}.{my_score_threshold_decimal}.metadata.json")

        # Wait for the file to be available
        while not os.path.exists(prev_metadata_path):
            time.sleep(1)

        with open(prev_metadata_path, 'r') as json_file:
            prev_face_data = json.load(json_file)

        if prev_face_data is None:
            raise Exception(f"Metadata file {prev_metadata_path} is empty")

        if prev_face_data:
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
                    # Define colors based on frame index difference
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
    if total_files_count == 0:
        raise Exception("No image files found in the input directory.")

    for idx, filename in enumerate(image_files_list):
        input_path = os.path.join(input_dir, filename)
        metadata_path = os.path.join(output_dir, "metadata", f"{filename}.{score_threshold_decimal}.metadata.json")
        output_path = os.path.join(output_dir, f"{filename}.blurred.png") if not is_debug_mode else os.path.join(output_dir, f"{filename}.debug.png")

        # Check if output already exists
        if is_pass2 and os.path.exists(output_path):
            continue

        # Read the image and convert to tensor
        image = cv2.imread(input_path)
        if image is None:
            raise Exception(f"Could not open or find the image: {filename}")
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        image_tensor = torch.from_numpy(image_rgb).permute(2, 0, 1).to(device, dtype=torch.float32) / 255.0

        # Detection threshold
        retina_threshold = 0.01 if is_debug_mode else score_threshold

        # Load or compute metadata
        if os.path.exists(metadata_path):
            with open(metadata_path, 'r') as json_file:
                metadata_data = json.load(json_file)
            detected_faces = None
        else:
            detected_faces = RetinaFace.detect_faces(image_rgb, threshold=retina_threshold)
            metadata_data = []

        # Process detected faces
        if detected_faces:
            for face_id, face_info in detected_faces.items():
                facial_area = face_info['facial_area']
                x1, y1, x2, y2 = facial_area
                score = face_info['score']

                x1 = max(0, x1)
                y1 = max(0, y1)
                x2 = min(image_tensor.shape[2], x2)
                y2 = min(image_tensor.shape[1], y2)

                metadata_data.append({
                    'score': float(score),
                    'score_threshold': float(score_threshold),
                    'position': {'x1': int(x1), 'y1': int(y1), 'x2': int(x2), 'y2': int(y2)}
                })

                if is_pass2 and score >= score_threshold:
                    blur_face(image_tensor, x1, y1, x2, y2)
                if is_debug_mode:
                    draw_frame(image_tensor, x1, y1, x2, y2, score, score_threshold)

        # Save metadata if not already saved
        if not os.path.exists(metadata_path):
            with open(metadata_path, 'w') as json_file:
                json.dump(metadata_data, json_file, indent=4)

        # Process other frames for pass 2
        image_is_modified = False
        if is_pass2:
            if look_back > 0 and idx > 0:
                image_is_modified |= process_other_frames(
                    idx, max(0, idx - look_back), idx,
                    image_files_list, output_dir, image_tensor,
                    score_threshold_decimal, score_threshold, is_debug_mode
                )
            if look_ahead > 0 and idx < total_files_count - 1:
                image_is_modified |= process_other_frames(
                    idx, idx + 1, min(total_files_count, idx + look_ahead + 1),
                    image_files_list, output_dir, image_tensor,
                    score_threshold_decimal, score_threshold, is_debug_mode
                )

        # Save the image
        if is_pass2:
            image_output = (image_tensor * 255).permute(1, 2, 0).cpu().numpy().astype(np.uint8)
            image_output_bgr = cv2.cvtColor(image_output, cv2.COLOR_RGB2BGR)
            cv2.imwrite(output_path, image_output_bgr)

        # Clear GPU memory
        del image_tensor
        torch.cuda.empty_cache()
        gc.collect()

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
