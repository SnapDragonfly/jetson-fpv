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
import screeninfo
import numpy as np

from collections import deque
from ultralytics import YOLO
from ultralytics.engine.results import Results
from jetson_utils import videoSource, videoOutput, Log, cudaToNumpy

# Define font color as a parameter (e.g., white or yellow)
FONT_SCALE = 0.6
FONT_COLOR = (255, 255, 255)  # White color
# FONT_COLOR = (0, 255, 255)  # Uncomment for yellow text
FONT_THICKNESS = 1
BOX_THICKNESS  = 1

FRAME_SKIP_CNT = 25
fps_window = deque(maxlen=FRAME_SKIP_CNT)

# thread exit control:
exit_flag = threading.Event()

# window title
window_title = "YOLO Prediction"

# path for interpolate tracking method
paths        = []

def display_help():
    """
    Displays a formatted help message for the command-line arguments.
    """
    help_message = """
Usage: python yolo.py [options] <input> [output]

Description:
    View various types of video streams.

Positional arguments:
    input               URI of the input stream
    output              URI of the output stream (default: file://output_video.mp4)

Optional arguments:
    --no-headless       Enable the OpenGL GUI window (default: headless mode is enabled)
    --interpolate       Enable the frame interpolated (default: interpolate is disabled)
    --model <str>       Set the model to use (default: 11n; options: 11n, 5nu, 8n, 8s)
    -h, --help          Show this help message and exit.

Examples:
    python yolo.py "file://input_video.mp4" "file://output_video.mp4"
    python yolo.py "rtsp://camera_stream" --no-headless --model 8n
"""
    print(help_message)

def handle_interrupt(signal_num, frame):
    print("yolo set exit_flag ... ...")
    exit_flag.set()

def interpolate(model, frame, paths, class_indices):
    tracker = model.predictor.trackers[0]
    tracks = [t for t in tracker.tracked_stracks if t.is_activated]
    # Apply Kalman filter to get predicted locations
    tracker.multi_predict(tracks)
    tracker.frame_id += 1
    boxes = [np.hstack([t.xyxy, t.track_id, t.score, t.cls]) for t in tracks]

    # Update frame_id in tracks
    def update_fid(t, fid):
        t.frame_id = fid
    [update_fid(t, tracker.frame_id) for t in tracks]

    if not boxes:
        return None

    # If paths is empty or None, pass None for the current path
    current_path = None if not paths else paths[-1]

    return Results(frame, current_path, model.names, np.array(boxes))

def interpolate_frame(frame_id, start_frame, stride, model, frame, class_indices):
    global paths  # Declare `paths` as a global variable
    results = []  # Initialize a list to store results

    # Log.Verbose(f"YOLO: paths = {paths}, frame_id = ({frame_id})")

    # Check if interpolation is needed
    if frame_id % stride != 0 and frame_id >= start_frame:
        # Interpolation mode
        result = interpolate(model, frame, None if not paths else paths[-1], class_indices)
        if result is not None:
            results.append(result)
    else:
        # Normal tracking mode
        tracked_results = model.track(frame, persist=True, verbose=True, classes=class_indices, imgsz=[320, 320])
        results.extend(tracked_results)  # Add all tracked results

    # Update the `paths` list
    for result in results:
        if result.path is not None:
            if paths is None:
                paths = []  # Initialize the `paths` list
            paths.append(result.path)
            Log.Verbose(f"YOLO: paths updated with result.path = ({result.path})")

    return results

def predict_frame(frame_id, model, frame, class_indices):
    results = model.predict(source=frame, show=False, verbose=False, classes=class_indices, imgsz=[320, 320])
    return results

def capture_image(input):
    while True:
        try:
            # Attempt to capture the next image
            img = input.Capture()

            # If capture is successful, return the image
            if img is not None:
                return img

        except Exception as e:
            # Catch any other exceptions and log them
            print(f"Unexpected error: {e}")
            
            # Optionally, break the loop or handle it differently
            return None  # Return None on error

    return None  # Return None if failed to capture after retries

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
        "--interpolate",
        action="store_true",
        dest="interpolate",
        help="Enable interpolate frame (default: interpolate is disabled)"
    )

    parser.add_argument(
        "--model",
        type=str,
        default="11n",
        dest="model",
        help="Set the model 11n(default)/5nu/8n"
    )

    args = parser.parse_known_args()[0]
    if args.headless:
        sys.argv.append("--headless")

    signal.signal(signal.SIGINT, handle_interrupt)

    # Load the YOLO model
    if args.model == "11n":
        model = YOLO('./model/yolo11n.engine')
    elif args.model == "5nu":
        model = YOLO('./model/yolov5nu.engine')
    elif args.model == "8n":
        model = YOLO('./model/yolov8n.engine')
    else:
        raise ValueError(f"Unsupported model: {args.model}. Please choose from 11n, 5nu, or 8n.")
        display_help()
        sys.exit(1)

    # Configurable list of target classes to detect
    class_names = model.names  # This is likely a dictionary {index: class_name}
    configurable_classes = [
        'person', 'bicycle', 'car', 'motorcycle', 'bus', 
        'truck', 'bench', 'bird', 'cat', 'dog', 
        'chair', 'couch', 'bed', 'dining table', 'tv', 
        'laptop', 'bottle', 'cup'
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

    # interpolate method tracking objects
    stride      = 3
    start_frame = 5

    while True:
        # capture the next image
        img = capture_image(input)

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

        fps_window.append(fps)
        avg_fps = sum(fps_window) / len(fps_window)

        if firt_frame_check:
            firt_frame_check = False

            # Get the current screen resolution
            screen = screeninfo.get_monitors()[0]  # Assuming the first monitor
            screen_width = screen.width
            screen_height = screen.height

            # Calculate the image dimensions
            img_width = img.width
            img_height = img.height
            
            # Check if the screen resolution is large enough for full screen
            if screen_width <= img_width and screen_height <= img_height:
                cv2.namedWindow(window_title, cv2.WND_PROP_FULLSCREEN)
                cv2.setWindowProperty(window_title, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
                Log.Verbose(f"YOLO:  Full screen {screen_width} x {screen_height}")
            else:
                #cv2.namedWindow(window_title, cv2.WND_PROP_FULLSCREEN)
                #cv2.namedWindow(window_title, cv2.WND_PROP_NORMAL)
                cv2.namedWindow(window_title, cv2.WND_PROP_AUTOSIZE)

                # Calculate the center position if image size is smaller than the screen
                window_x = (screen_width - img_width) // 2
                window_y = (screen_height - img_height) // 2
                cv2.moveWindow(window_title, window_x, window_y)
                Log.Verbose(f"YOLO:  Image size ({img.width} x {img.height})")
            
        numFrames += 1

        # Perform inference on the frame using YOLO
        cv2_frame = cudaToNumpy(img)

        if numFrames % FRAME_SKIP_CNT == 0 or numFrames < 15:
            Log.Verbose(f"YOLO:  captured {numFrames} frames ({img.width} x {img.height})")
            
            # Set the window title with the FPS value
            window_title = f"YOLO Prediction - {img.width:d}x{img.height:d} | FPS: {avg_fps:.2f}"
            #cv2.setWindowTitle("YOLO Prediction", window_title)

        if args.interpolate:
            # Interpolate if we reach start_frame and the current frame is not divisible by stride
            results = interpolate_frame(numFrames, start_frame, stride, model, cv2_frame, class_indices)
        else:
            # Predict using Yolo algorithm
            results = predict_frame(numFrames, model, cv2_frame, class_indices)

        if len(results) > 0 and hasattr(results[0], 'plot'):
            annotated_frame = results[0].plot()
        else:
            annotated_frame = cv2_frame.copy()
        
        # FPS text
        text_size = cv2.getTextSize(window_title, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)[0]
        text_x = img.width - text_size[0] - 10  # right
        text_y = 20  # to the top
        cv2.putText(annotated_frame, window_title, (text_x, text_y), cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, FONT_COLOR, FONT_THICKNESS)

        # Update the window title and display the frame with detections
        cv2.imshow("YOLO Prediction", annotated_frame)

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
    import sys
    if "--help" in sys.argv or "-h" in sys.argv:
        display_help()
        sys.exit(0)

    main()
    print("yolo done!")
    sys.exit(0)

