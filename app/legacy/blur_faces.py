import cv2
import os
import sys

def blur_faces_in_directory(input_dir, output_dir, models_dir, models):
    # Ensure the output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    files = sorted(os.listdir(input_dir))

    # Cache the face_cascade objects for each model
    face_cascades = {}
    for model in models:
        model_path = os.path.join(models_dir, model)
        face_cascades[model] = cv2.CascadeClassifier(model_path)

    # Loop through all files in the input directory
    for filename in files:
        input_path = os.path.join(input_dir, filename)

        # Check if it's an image file (you can extend this with more file types)
        if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            # Read the image
            print(f"Processing: {input_path}",end="")
            sys.stdout.flush()
            image = cv2.imread(input_path)
            if image is None:
                print(f"Could not open or find the image: {filename}")
                continue

            # Process the image with each cached face_cascade
            for model, face_cascade in face_cascades.items():
                # Convert the image to grayscale for face detection
                gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

                # Detect faces in the image
                faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(20, 20))

                # Loop over each face and apply a blur
                if len(faces) > 0:
                  for (x, y, w, h) in faces:
                      print(".",end="")
                      sys.stdout.flush()
                      face = image[y:y+h, x:x+w]
                      face = cv2.GaussianBlur(face, (99, 99), 30)
                      image[y:y+h, x:x+w] = face
                  break


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

    # Static list of models to cycle through
    models = [
        "haarcascade_frontalface_alt.xml",
        "haarcascade_frontalface_alt2.xml",
        "haarcascade_frontalface_alt_tree.xml",
        "haarcascade_frontalface_default.xml",
        "haarcascade_lefteye_2splits.xml",
        "haarcascade_profileface.xml",
        "haarcascade_eye_tree_eyeglasses.xml",
        "haarcascade_eye.xml",
        "haarcascade_mcs_nose.xml",
        "haarcascade_mcs_eyepair_big.xml",
        "haarcascade_mcs_eyepair_small.xml",
        "haarcascade_mcs_leftear.xml",
        "haarcascade_mcs_lefteye.xml",
        "haarcascade_mcs_mouth.xml",
        "haarcascade_mcs_rightear.xml",
        "haarcascade_mcs_righteye.xml",
        "haarcascade_righteye_2splits.xml",
        "haarcascade_smile.xml",
        #"haarcascade_upperbody.xml"
        #"haarcascade_lowerbody.xml",
        #"haarcascade_mcs_upperbody.xml",
        #"haarcascade_fullbody.xml",
    ]

    blur_faces_in_directory(input_dir, output_dir, models_dir, models)