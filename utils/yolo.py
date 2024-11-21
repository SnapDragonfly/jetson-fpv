#!/usr/bin/env python3
#
# Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#

import sys
import cv2
import time
import signal
import argparse
import threading
import numpy as np

from ultralytics import YOLO
from jetson_utils import videoSource, videoOutput, Log, cudaToNumpy

# Define font color as a parameter (e.g., white or yellow)
YOLO_SIZE  = 600
FONT_SCALE = 0.6
FONT_COLOR = (255, 255, 255)  # White color
# FONT_COLOR = (0, 255, 255)  # Uncomment for yellow text
FONT_THICKNESS = 1
BOX_THICKNESS  = 1

# thread exit control:
exit_flag = threading.Event()

# window title
window_title = "YOLO Prediction"

def handle_interrupt(signal_num, frame):
    print("yolo set exit_flag ... ...")
    exit_flag.set()

def main():
    global window_title

    # parse command line
    parser = argparse.ArgumentParser(description="View various types of video streams", 
                                    formatter_class=argparse.RawTextHelpFormatter, 
                                    epilog=videoSource.Usage() + videoOutput.Usage() + Log.Usage())

    parser.add_argument(
        "input", 
        type=str, 
        help="URI of the input stream"
    )

    parser.add_argument(
        "output",
        type=str,
        default="file://output_video.mp4",
        nargs='?',
        help="URI of the output stream (default: file://output_video.mp4)"
    )

    parser.add_argument(
        "--no-headless",
        action="store_false",
        dest="headless",
        help="Enable the OpenGL GUI window (default: headless mode is enabled)"
    )

    parser.add_argument(
        "--mode",
        type=int,
        default=3,
        dest="mode",
        help="Set the corp mode (default: 0-resize; 1-vertical-center; 2-center-640; other)"
    )

    parser.add_argument(
        "--show-predict",
        action='store_true',  # Store True if the argument is passed, otherwise False
        default=False,
        help="Set to True to show 'pfame' as the Predict box label (default: False)"
    )

    args = parser.parse_known_args()[0]
    if args.headless:
        sys.argv.append("--headless")

    signal.signal(signal.SIGINT, handle_interrupt)

    # Load the YOLO model
    model = YOLO('./model/yolo11n.engine')

    # Configurable list of target classes to detect
    class_names = model.names  # This is likely a dictionary {index: class_name}
    configurable_classes = [
        'person', 'bicycle', 'car', 'motorcycle', 'bus', 'truck', 
        'fire hydrant', 'bench', 'bird', 'cat', 'dog', 'umbrella', 
        'handbag', 'suitcase', 'backpack', 'frisbee', 'skis', 'snowboard', 
        'sports ball', 'bottle', 'wine glass', 'cup', 'knife', 'chair', 
        'couch', 'potted plant', 'bed', 'dining table', 'tv', 'laptop', 
        'microwave', 'sink', 'refrigerator', 'vase', 'scissors', 'teddy bear'
    ]  # User-defined classes to detect

    # Convert class_names dict to list of class names and map them to indices
    class_indices = [index for index, name in class_names.items() if name in configurable_classes]

    print("Configured detection classes:", configurable_classes)
    print("Class indices for detection:", class_indices)


    # create video sources & outputs
    input = videoSource(args.input, argv=sys.argv)
    output = videoOutput(args.output, argv=sys.argv)

    # Initialize variables for Windows/FPS calculation
    previous_time = time.time()
    firt_frame_check = True

    # capture frames until EOS or user exits
    numFrames = 0

    while True:
        # capture the next image
        img = input.Capture()

        if img is None: # timeout
            if exit_flag.is_set():
                print("video stabilizer ready to exit ... ...")
                break
            continue  

        # Calculate FPS
        current_time = time.time()
        elapsed_time = current_time - previous_time
        fps = 1.0 / elapsed_time if elapsed_time > 0 else 0
        previous_time = current_time

        if firt_frame_check:
            firt_frame_check = False

            cv2.namedWindow(window_title, cv2.WND_PROP_FULLSCREEN)
            cv2.setWindowProperty(window_title, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
            
        numFrames += 1

        # Perform inference on the frame using YOLO
        # Resize/crop the original frame to a maximum of YOLO_SIZE(640) pixels
        crop_width  = YOLO_SIZE
        crop_height = YOLO_SIZE
        cv2_frame = cudaToNumpy(img)

        if numFrames % 25 == 0 or numFrames < 15:
            Log.Verbose(f"video-viewer:  captured {numFrames} frames ({img.width} x {img.height})")
            
            # Set the window title with the FPS value
            window_title = f"YOLO Prediction - {img.width:d}x{img.height:d} | FPS: {fps:.2f}"
            #cv2.setWindowTitle("YOLO Prediction", window_title)

        if args.mode == 0:
            #print("Mode 0: Performing Resize")
            h, w = cv2_frame.shape[:2]

            # Calculate scale factor to resize the frame to fit the crop width while maintaining aspect ratio
            scale_factor = min(crop_width / h, crop_width / w)  # Calculate scale factor
            new_w, new_h = int(w * scale_factor), int(h * scale_factor)  # Calculate new dimensions

            # Resize the frame to fit within 640x640 without padding
            resized_frame = cv2.resize(cv2_frame, (new_w, new_h), interpolation=cv2.INTER_LINEAR)

            # Perform YOLO inference on the resized frame
            results = model.predict(source=resized_frame, show=False)

            # Iterate over the results for each detected object
            for result in results:
                boxes = result.boxes  # Detected boxes
                for box in boxes:
                    x1, y1, x2, y2 = box.xyxy[0]  # Bounding box coordinates in resized frame
                    confidence = box.conf[0]  # Confidence score
                    class_id = int(box.cls[0])  # Class ID

                    if class_id in class_indices:  # Filter by configured classes
                        # Map bounding box back to original frame dimensions
                        x1, x2 = x1 / scale_factor, x2 / scale_factor
                        y1, y2 = y1 / scale_factor, y2 / scale_factor

                        # Create label for bounding box
                        label = f"{model.names[class_id]} {confidence:.2f}"

                        # Draw the bounding box on the original frame
                        cv2.rectangle(cv2_frame, (int(x1), int(y1)), (int(x2), int(y2)), (173, 216, 230), BOX_THICKNESS)  # Light blue

                        # Draw label on the original frame
                        cv2.putText(cv2_frame, label, (int(x1), int(y1) - 10), cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, FONT_COLOR, FONT_THICKNESS)

        elif args.mode == 1:
            #print("Mode 1: Performing corp width")
            # Get the dimensions of the original frame
            frame_height, frame_width, _ = cv2_frame.shape

            # Calculate cropping coordinates for the center 640-pixel width
            start_x = max(0, (frame_width - crop_width) // 2)
            end_x = start_x + crop_width

            # Crop the central 640-pixel width
            cropped_frame = cv2_frame[:, start_x:end_x]

            # Perform YOLO prediction on the cropped frame
            results = model.predict(source=cropped_frame, show=False)

            # Map detected bounding boxes back to the original frame coordinates
            for result in results:  # Iterate over the results for each object detected
                boxes = result.boxes  # Detected boxes (each box corresponds to a detected object)
                for box in boxes:
                    x1, y1, x2, y2 = box.xyxy[0]  # Get the coordinates of the bounding box
                    confidence = box.conf[0]  # Confidence score for the detected object
                    class_id = int(box.cls[0])  # Class ID of the detected object

                    # Only process the boxes for the configured classes
                    if class_id in class_indices:
                        # Map the bounding box coordinates back to the original frame
                        x1, y1, x2, y2 = box.xyxy[0].clone()  # Clone the tensor to make it editable
                        x1 += start_x
                        x2 += start_x

                        label = f"{model.names[class_id]} {confidence:.2f}"  # Class name and confidence

                        # Draw the bounding box with a light color (e.g., light blue)
                        cv2.rectangle(cv2_frame, (int(x1), int(y1)), (int(x2), int(y2)), (173, 216, 230), BOX_THICKNESS)  # Light blue color

                        # Draw the label with a larger font and the chosen font color
                        cv2.putText(cv2_frame, label, (int(x1), int(y1) - 10), cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, FONT_COLOR, FONT_THICKNESS)  # Using FONT_COLOR

            if args.show_predict:
                # Draw a rectangle to indicate the cropped area on the original frame
                margin = 50  # Increase the margin by this amount
                cv2.rectangle(cv2_frame, (start_x-margin, 0), (end_x+margin, frame_height), (0, 255, 0), BOX_THICKNESS)  # Green rectangle

                # Add a label to indicate this is the prediction area
                cv2.putText(cv2_frame, "Predict", (start_x + 10, 30), cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, (0, 255, 0), FONT_THICKNESS)  # Green text

        elif args.mode == 2:
            #print("Mode 2: Performing corp width-height")
            # Get the dimensions of the original frame
            h, w = cv2_frame.shape[:2]

            # Calculate cropping dimensions for the center 640x640 region
            start_x = max((w - crop_width) // 2, 0)  # Ensure cropping starts within bounds
            start_y = max((h - crop_height) // 2, 0)
            end_x = min(w, start_x + crop_width)  # Ensure the rectangle does not exceed the image boundary
            end_y = min(h, start_y + crop_height)  # Ensure the rectangle does not exceed the image boundary

            # Crop the central region of the frame
            cropped_frame = cv2_frame[start_y:start_y + crop_height, start_x:start_x + crop_width]

            # Perform YOLO inference on the cropped frame
            results = model.predict(source=cropped_frame, show=False)

            # Draw the bounding boxes on the original frame, mapped from the cropped region
            for result in results:  # Iterate over the results for each object detected
                boxes = result.boxes  # Detected boxes
                for box in boxes:
                    x1, y1, x2, y2 = box.xyxy[0]  # Get the coordinates of the bounding box
                    confidence = box.conf[0]  # Confidence score for the detected object
                    class_id = int(box.cls[0])  # Class ID of the detected object

                    # Only process the boxes for the configured classes
                    if class_id in class_indices:
                        label = f"{model.names[class_id]} {confidence:.2f}"  # Class name and confidence

                        # Map bounding box coordinates back to the original frame
                        x1, y1, x2, y2 = box.xyxy[0].clone()  # Clone the tensor to make it editable
                        x1 += start_x
                        x2 += start_x
                        y1 += start_y
                        y2 += start_y

                        # Draw the bounding box with a light color (e.g., light blue)
                        cv2.rectangle(cv2_frame, (int(x1), int(y1)), (int(x2), int(y2)), (173, 216, 230), BOX_THICKNESS)  # Light blue color

                        # Draw the label with a larger font and the chosen font color
                        cv2.putText(cv2_frame, label, (int(x1), int(y1) - 10), cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, FONT_COLOR, FONT_THICKNESS)  # Using FONT_COLOR

            if args.show_predict:
                # Draw a rectangle around the cropped region with an increased width and height
                margin = 50  # Increase the margin by this amount
                cv2.rectangle(cv2_frame, (start_x - margin, start_y - margin), (end_x + margin, end_y + margin), (0, 255, 0), BOX_THICKNESS)  # Green rectangle

                # Add a label to indicate the prediction area
                cv2.putText(cv2_frame, "Predict", (start_x - margin + 10, start_y - margin - 10), cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, (0, 255, 0), FONT_THICKNESS)  # Green text

        else:
            #print(f"Other Mode: {args.mode}. Performing all")
            results = model.predict(source=cv2_frame, show=False)
            #results = model.predict(source=img, show=False)

            # Draw the bounding boxes on the image
            for result in results:  # Iterate over the results for each object detected
                boxes = result.boxes  # Detected boxes (each box corresponds to a detected object)
                for box in boxes:
                    x1, y1, x2, y2 = box.xyxy[0]  # Get the coordinates of the bounding box
                    confidence = box.conf[0]  # Confidence score for the detected object
                    class_id = int(box.cls[0])  # Class ID of the detected object

                    # Only process the boxes for the configured classes
                    if class_id in class_indices:
                        label = f"{model.names[class_id]} {confidence:.2f}"  # Class name and confidence

                        # Draw the bounding box with a light color (e.g., light blue)
                        cv2.rectangle(cv2_frame, (int(x1), int(y1)), (int(x2), int(y2)), (173, 216, 230), BOX_THICKNESS)  # Light blue color

                        # Draw the label with a larger font and the chosen font color
                        cv2.putText(cv2_frame, label, (int(x1), int(y1)-10), cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, FONT_COLOR, FONT_THICKNESS)  # Using FONT_COLOR

        # FPS text
        text_size = cv2.getTextSize(window_title, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)[0]
        text_x = img.width - text_size[0] - 10  # right
        text_y = 20  # to the top
        cv2.putText(cv2_frame, window_title, (text_x, text_y), cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, FONT_COLOR, FONT_THICKNESS)

        # Update the window title and display the frame with detections
        cv2.imshow("YOLO Prediction", cv2_frame)

        # render the image
        output.Render(img)
        
        # update the title bar
        output.SetStatus("Video Viewer | {:d}x{:d} | {:.1f} FPS".format(img.width, img.height, output.GetFrameRate()))
        
        # exit on input/output EOS
        if not input.IsStreaming() or not output.IsStreaming():
            break

        if exit_flag.is_set():
            print("yolo ready to exit ... ...")
            break

        # Exit the loop if the 'q' key is pressed
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
    print("yolo done!")
    sys.exit(0)

