#!/usr/bin/env python3
# Author: lida2003
#
# Thanks to:
# - https://github.com/ejowerks/wfb-stabilizer
# - https://github.com/tipoman9/wfb-stabilizer
# - https://github.com/dusty-nv/jetson-utils
#

import sys
import cv2
import argparse
import time
import signal
import threading
import numpy as np
from jetson_utils import videoSource, videoOutput, cudaToNumpy, cudaFromNumpy, Log

# key scan control:
# If the test video plays too fast, increase this value until the video plays at a proper speed.
# Default value is `1` (no delay).
delay_time = 1

# thread exit control:
exit_flag = threading.Event()

class Stabilizer:
    #################### USER VARS ######################################

    # Stabilization latency control:
    # Decreases latency at the cost of accuracy. Set `downSample` to 1.0 for full resolution (no downsampling).
    # Example: `downSample = 0.5` reduces the resolution to half, making it faster but more jittery.
    downSample = 1.0

    # Zoom factor for stabilization:
    # Controls how much the image is zoomed to avoid seeing the frame bounce. 
    # `zoomFactor = 1.0` means no zoom, while smaller values zoom in more.
    zoomFactor = 0.9

    # Smoothing parameters:
    # `processVar` and `measVar` control the smoothing of the stabilization process.
    # `processVar` is the process noise covariance (controls the stability of predictions).
    # `measVar` is the measurement noise covariance (controls how much measurements are trusted).
    # Start with `processVar = 0.03` and `measVar = 2` for good results, adjust as needed.
    processVar = 0.03
    measVar = 2

    # Full screen display:
    # Set to `1` to display the stabilized video in full screen.
    # Set to `0` for a normal windowed view.
    showFullScreen = 0

    ######################## Region of Interest (ROI) ###############################

    # Region of Interest (ROI) settings:
    # `roiDiv` defines the size of the ROI. A larger value reduces the area used for stabilization.
    # For example, `roiDiv = 4.0` means the ROI is 1/4 of the original image size.
    roiDiv = 4.0

    # ROI display settings:
    # Set to `1` to display a rectangle around the Region of Interest in the frame.
    # Set to `0` to hide the rectangle.
    showrectROI = 0

    # Tracking points display:
    # Set to `1` to show tracking points found in the frame.
    # Set to `0` to hide them.
    showTrackingPoints = 0

    # Unstabilized frame display:
    # Set to `1` to show the unstabilized ROI in a separate window (in grayscale).
    # Set to `0` to hide this window.
    showUnstabilized = 0

    # Wide-angle frame masking:
    # Set to `1` to mask out extreme edges of the wide-angle camera frame (useful for fisheye lenses).
    # Set to `0` to disable masking.
    maskFrame = 0

    # stabilized algorithm enable/disable:
    # Set to `True` to enable the algorithm.
    # Set to `False` to disable the algorithm.
    useStabilizer = True

    def __init__(self, downSample=downSample, zoomFactor=zoomFactor, processVar=processVar, measVar=measVar, 
                 roiDiv=roiDiv, showrectROI=showrectROI, showTrackingPoints=showTrackingPoints, showUnstabilized=showUnstabilized, 
                 maskFrame=maskFrame, showFullScreen=showFullScreen, useStabilizer=useStabilizer):
        self.downSample = downSample
        self.zoomFactor = zoomFactor
        self.processVar = processVar
        self.measVar = measVar
        self.roiDiv = roiDiv
        self.showrectROI = showrectROI
        self.showTrackingPoints = showTrackingPoints
        self.showUnstabilized = showUnstabilized
        self.maskFrame = maskFrame
        self.showFullScreen = showFullScreen
        self.useStabilizer = useStabilizer

        # Initialize variables for stabilization
        self.lk_params = dict(winSize=(15, 15), maxLevel=3, criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 10, 0.03))
        self.count = 0
        self.a = 0
        self.x = 0
        self.y = 0
        self.Q = np.array([[self.processVar] * 3])
        self.R = np.array([[self.measVar] * 3])
        self.K_collect = []
        self.P_collect = []
        self.prevFrame = None
        self.prevOrig = None
        self.lastRigidTransform = None

    def toggle(self):
        self.useStabilizer = not self.useStabilizer  # Toggle the value between True and False
        print("Video stabilizer toggle ... ...", self.useStabilizer)

    def stabilize_ejowerks(self, cv2_frame):

        start_time = time.time()  # Start timing execution

        # Resize the image
        res_w_orig = cv2_frame.shape[1]  # Original width of the frame
        res_h_orig = cv2_frame.shape[0]  # Original height of the frame
        res_w = int(res_w_orig * self.downSample)  # Width after downsampling
        res_h = int(res_h_orig * self.downSample)  # Height after downsampling
        frameSize = (res_w, res_h)  # New frame size as a tuple

        Orig = cv2_frame  # Store the original frame
        if self.downSample != 1:
            # Downsample the frame if the downsample factor is not 1
            cv2_frame = cv2.resize(cv2_frame, frameSize)

        # Set Region of Interest (ROI) dimensions
        top_left = [int(res_h / self.roiDiv), int(res_w / self.roiDiv)]  # Top-left corner of ROI
        bottom_right = [int(res_h - (res_h / self.roiDiv)), int(res_w - (res_w / self.roiDiv))]  # Bottom-right corner of ROI

        currFrame = cv2_frame  # Current frame
        currGray = cv2.cvtColor(currFrame, cv2.COLOR_BGR2GRAY)  # Convert current frame to grayscale
        currGray = currGray[top_left[0]:bottom_right[0], top_left[1]:bottom_right[1]]  # Crop to ROI

        # Handle the first frame initialization
        if self.prevFrame is None:
            self.prevOrig = cv2_frame  # Store original frame
            self.prevFrame = cv2_frame  # Store frame for future reference
            self.prevGray = currGray  # Store grayscale version of frame

        # Display the ROI rectangle on the original frame if enabled
        if self.showrectROI == 1:
            cv2.rectangle(self.prevOrig, (top_left[1], top_left[0]), (bottom_right[1], bottom_right[0]), color=(211, 211, 211), thickness=1)

        # Detect good features to track in the previous frame
        prevPts = cv2.goodFeaturesToTrack(self.prevGray, maxCorners=400, qualityLevel=0.01, minDistance=30, blockSize=3)
        if prevPts is not None:
            # Calculate optical flow to track feature points in the current frame
            currPts, status, err = cv2.calcOpticalFlowPyrLK(self.prevGray, currGray, prevPts, None, **self.lk_params)
            assert prevPts.shape == currPts.shape  # Ensure shapes match
            idx = np.where(status == 1)[0]  # Get indices of successfully tracked points
            # Offset points to match original resolution
            prevPts = prevPts[idx] + np.array([int(res_w_orig / self.roiDiv), int(res_h_orig / self.roiDiv)])
            currPts = currPts[idx] + np.array([int(res_w_orig / self.roiDiv), int(res_h_orig / self.roiDiv)])
            if self.showTrackingPoints == 1:
                # Display tracking points on the previous original frame
                for pT in prevPts:
                    cv2.circle(self.prevOrig, (int(pT[0][0]), int(pT[0][1])), 5, (211, 211, 211))
            if prevPts.size & currPts.size:
                # Estimate affine transformation between frames
                m, inliers = cv2.estimateAffinePartial2D(prevPts, currPts)
            if m is None:
                m = self.lastRigidTransform  # Use last transformation if current is invalid
            # Extract translation and rotation from transformation matrix
            dx = m[0, 2]
            dy = m[1, 2]
            da = np.arctan2(m[1, 0], m[0, 0])  # Rotation angle
        else:
            # Default transformations if no points were detected
            dx = 0
            dy = 0
            da = 0

        # Update cumulative transformations
        self.x += dx
        self.y += dy
        self.a += da
        Z = np.array([[self.x, self.y, self.a]], dtype="float")  # Observation vector

        # Initialize Kalman filter parameters if it's the first iteration
        if self.count == 0:
            self.X_estimate = np.zeros((1, 3), dtype="float")  # Estimated state vector
            self.P_estimate = np.ones((1, 3), dtype="float")  # Estimated error covariance
        else:
            # Predict the next state and error covariance
            self.X_predict = self.X_estimate
            self.P_predict = self.P_estimate + self.Q
            # Compute Kalman gain
            K = self.P_predict / (self.P_predict + self.R)
            # Update the estimate with measurements
            self.X_estimate = self.X_predict + K * (Z - self.X_predict)
            self.P_estimate = (np.ones((1, 3), dtype="float") - K) * self.P_predict
            self.K_collect.append(K)  # Store Kalman gain for analysis
            self.P_collect.append(self.P_estimate)  # Store error covariance

        # Compute smoothed transformations
        diff_x = self.X_estimate[0, 0] - self.x
        diff_y = self.X_estimate[0, 1] - self.y
        diff_a = self.X_estimate[0, 2] - self.a
        dx += diff_x
        dy += diff_y
        da += diff_a
        m = np.zeros((2, 3), dtype="float")  # Create a new transformation matrix
        m[0, 0] = np.cos(da)
        m[0, 1] = -np.sin(da)
        m[1, 0] = np.sin(da)
        m[1, 1] = np.cos(da)
        m[0, 2] = dx
        m[1, 2] = dy

        # Apply affine transformation for stabilization
        fS = cv2.warpAffine(self.prevOrig, m, (res_w_orig, res_h_orig))
        s = fS.shape
        # Apply zoom transformation
        T = cv2.getRotationMatrix2D((s[1] / 2, s[0] / 2), 0, self.zoomFactor)
        f_stabilized = cv2.warpAffine(fS, T, (s[1], s[0]))

        # Apply masking if enabled
        if self.maskFrame == 1:
            mask = np.zeros(f_stabilized.shape[:2], dtype="uint8")
            cv2.rectangle(mask, (100, 200), (1180, 620), 255, -1)
            f_stabilized = cv2.bitwise_and(f_stabilized, f_stabilized, mask=mask)

        end_time = time.time()  # End timing execution
        elapsed_time_ms = (end_time - start_time) * 1000  # Calculate elapsed time in milliseconds
        #print(f"Code block execution time: {elapsed_time_ms:.3f} ms")
        fps = 1000 / elapsed_time_ms  # Calculate FPS

        # Display the stabilized frame
        window_name = "Video Viewer Stabilized"
        if self.showFullScreen == 1:
            cv2.setWindowProperty(window_name, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)

        cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(window_name, res_w, res_h)  # Resize the window
        if self.useStabilizer:
            cv2.setWindowTitle(window_name, f"Video Viewer Stabilized: {res_w}x{res_h} | FPS: {fps:.2f}")
            cv2.imshow(window_name, f_stabilized)  # Show stabilized frame
        else:
            cv2.setWindowTitle(window_name, f"Video Viewer Unstabilized: {res_w}x{res_h} | FPS: {fps:.2f}")
            cv2.imshow(window_name, currFrame)  # Show original frame

        # Display unstabilized ROI if enabled
        if self.showUnstabilized == 1:
            cv2.imshow("Unstabilized ROI", self.prevGray)

        # Update previous frame data
        self.prevOrig = Orig
        self.prevGray = currGray
        self.prevFrame = currFrame
        self.lastRigidTransform = m  # Store last transformation matrix
        self.count += 1  # Increment frame count


    def stabilize_cuda(self, cv2_frame):

        start_time = time.time()  # Start timing execution

        # Resize the image
        res_w_orig = cv2_frame.shape[1]  # Original width of the frame
        res_h_orig = cv2_frame.shape[0]  # Original height of the frame
        res_w = int(res_w_orig * self.downSample)  # Width after downsampling
        res_h = int(res_h_orig * self.downSample)  # Height after downsampling

        Orig = cv2_frame  # Store the original frame
        if self.downSample != 1:
            #cv2_frame = cv2.resize(cv2_frame, (res_w, res_h))  # Downsample if applicable
            # Use CUDA for resizing to improve performance
            gpu_frame = cv2.cuda_GpuMat()
            gpu_frame.upload(cv2_frame)  # Upload frame to GPU
            gpu_frame_resized = cv2.cuda.resize(gpu_frame, (res_w, res_h))
            cv2_frame = gpu_frame_resized.download()  # Download back to CPU

        # Set Region of Interest (ROI) dimensions
        top_left = [int(res_h / self.roiDiv), int(res_w / self.roiDiv)]  # Top-left corner of ROI
        bottom_right = [int(res_h - (res_h / self.roiDiv)), int(res_w - (res_w / self.roiDiv))]  # Bottom-right corner of ROI

        currFrame = cv2_frame  # Current frame

        #currGray = cv2.cvtColor(currFrame, cv2.COLOR_BGR2GRAY)  # Convert current frame to grayscale
        # Use CUDA for grayscale conversion
        gpu_frame = cv2.cuda_GpuMat()
        gpu_frame.upload(currFrame)  # Upload frame to GPU
        gpu_gray = cv2.cuda.cvtColor(gpu_frame, cv2.COLOR_BGR2GRAY)
        currGray = gpu_gray.download()  # Download back to CPU

        currGray = currGray[top_left[0]:bottom_right[0], top_left[1]:bottom_right[1]]  # Crop to ROI

        # Handle the first frame initialization
        if self.prevFrame is None:
            self.prevOrig = cv2_frame  # Store original frame
            self.prevFrame = cv2_frame  # Store frame for future reference
            self.prevGray = currGray  # Store grayscale version of frame

        # Display the ROI rectangle on the original frame if enabled
        if self.showrectROI == 1:
            cv2.rectangle(self.prevOrig, (top_left[1], top_left[0]), (bottom_right[1], bottom_right[0]), color=(211, 211, 211), thickness=1)

        # Detect good features to track in the previous frame
        prevPts = cv2.goodFeaturesToTrack(self.prevGray, maxCorners=400, qualityLevel=0.01, minDistance=30, blockSize=3)
        if prevPts is not None and len(prevPts) > 0:
            # Calculate optical flow to track feature points in the current frame
            currPts, status, err = cv2.calcOpticalFlowPyrLK(self.prevGray, currGray, prevPts, None, **self.lk_params)

            assert prevPts.shape == currPts.shape  # Ensure shapes match
            idx = np.where(status == 1)[0]  # Get indices of successfully tracked points
            # Offset points to match original resolution
            prevPts = prevPts[idx] + np.array([int(res_w_orig / self.roiDiv), int(res_h_orig / self.roiDiv)])
            currPts = currPts[idx] + np.array([int(res_w_orig / self.roiDiv), int(res_h_orig / self.roiDiv)])
            if self.showTrackingPoints == 1:
                # Display tracking points on the previous original frame
                for pT in prevPts:
                    cv2.circle(self.prevOrig, (int(pT[0][0]), int(pT[0][1])), 5, (211, 211, 211))
            if prevPts.size & currPts.size:
                # Estimate affine transformation between frames
                m, inliers = cv2.estimateAffinePartial2D(prevPts, currPts)
            m = self.lastRigidTransform if m is None else m # Use last transformation if current is invalid
            # Extract translation and rotation from transformation matrix
            dx = m[0, 2]
            dy = m[1, 2]
            da = np.arctan2(m[1, 0], m[0, 0])  # Rotation angle
        else:
            # Default transformations if no points were detected
            dx = 0
            dy = 0
            da = 0

        # Update cumulative transformations
        self.x += dx
        self.y += dy
        self.a += da
        Z = np.array([[self.x, self.y, self.a]], dtype="float")  # Observation vector

        # Initialize Kalman filter parameters if it's the first iteration
        if self.count == 0:
            self.X_estimate = np.zeros((1, 3), dtype="float")  # Estimated state vector
            self.P_estimate = np.ones((1, 3), dtype="float")  # Estimated error covariance
        else:
            # Predict the next state and error covariance
            self.X_predict = self.X_estimate
            self.P_predict = self.P_estimate + self.Q
            # Compute Kalman gain
            K = self.P_predict / (self.P_predict + self.R)
            # Update the estimate with measurements
            self.X_estimate = self.X_predict + K * (Z - self.X_predict)
            self.P_estimate = (np.ones((1, 3), dtype="float") - K) * self.P_predict
            self.K_collect.append(K)  # Store Kalman gain for analysis
            self.P_collect.append(self.P_estimate)  # Store error covariance

        # Compute smoothed transformations
        dx += self.X_estimate[0, 0] - self.x
        dy += self.X_estimate[0, 1] - self.y
        da += self.X_estimate[0, 2] - self.a
        # Create a new transformation matrix
        m = np.array([[np.cos(da), -np.sin(da), dx],
                    [np.sin(da), np.cos(da), dy]], dtype="float")

        # Apply affine transformation for stabilization
        #fS = cv2.warpAffine(self.prevOrig, m, (res_w_orig, res_h_orig))
        # Use CUDA for affine transformations
        gpu_prev_orig = cv2.cuda_GpuMat()
        gpu_prev_orig.upload(self.prevOrig)
        gpu_fs = cv2.cuda.warpAffine(gpu_prev_orig, m, (res_w_orig, res_h_orig))
        fS = gpu_fs.download()  # Download stabilized frame back to CPU

        s = fS.shape
        # Apply zoom transformation
        #T = cv2.getRotationMatrix2D((s[1] / 2, s[0] / 2), 0, self.zoomFactor)
        #f_stabilized = cv2.warpAffine(fS, T, (s[1], s[0]))
        # Use CUDA for zoom application
        gpu_fs.upload(fS)
        T = cv2.getRotationMatrix2D((s[1] / 2, s[0] / 2), 0, self.zoomFactor)
        gpu_f_stabilized = cv2.cuda.warpAffine(gpu_fs, T, (s[1], s[0]))
        f_stabilized = gpu_f_stabilized.download()

        # Apply masking if enabled
        if self.maskFrame == 1:
            #mask = np.zeros(f_stabilized.shape[:2], dtype="uint8")
            #cv2.rectangle(mask, (100, 200), (1180, 620), 255, -1)
            #f_stabilized = cv2.bitwise_and(f_stabilized, f_stabilized, mask=mask)
            # Use CUDA for mask application
            mask = np.zeros(f_stabilized.shape[:2], dtype="uint8")
            cv2.rectangle(mask, (100, 200), (1180, 620), 255, -1)
            gpu_mask = cv2.cuda_GpuMat()
            gpu_mask.upload(mask)
            gpu_f_stabilized.upload(f_stabilized)
            gpu_masked = cv2.cuda.bitwise_and(gpu_f_stabilized, gpu_f_stabilized, mask=gpu_mask)
            f_stabilized = gpu_masked.download()

        end_time = time.time()  # End timing execution
        elapsed_time_ms = (end_time - start_time) * 1000  # Calculate elapsed time in milliseconds
        #print(f"Code block execution time: {elapsed_time_ms:.3f} ms")
        fps = 1000 / elapsed_time_ms  # Calculate FPS

        # Display the stabilized frame
        window_name = "Video Viewer Stabilized"

        cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(window_name, res_w, res_h)  # Resize the window
        if self.useStabilizer:
            cv2.setWindowTitle(window_name, f"Video Viewer Stabilized: {res_w}x{res_h} | FPS: {fps:.2f}")
            cv2.imshow(window_name, f_stabilized)  # Show stabilized frame
        else:
            cv2.setWindowTitle(window_name, f"Video Viewer Unstabilized: {res_w}x{res_h} | FPS: {fps:.2f}")
            cv2.imshow(window_name, currFrame)  # Show original frame

        # Display unstabilized ROI if enabled
        if self.showUnstabilized == 1:
            cv2.imshow("Unstabilized ROI", self.prevGray)

        if self.showFullScreen == 1:
            cv2.setWindowProperty(window_name, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)

        # Update previous frame data
        self.prevOrig = Orig
        self.prevGray = currGray
        self.prevFrame = currFrame
        self.lastRigidTransform = m  # Store last transformation matrix
        self.count += 1  # Increment frame count

def display_help():
    help_message = """
View various types of video streams

Usage:
    stabilizer.py <input> [output] [--no-headless]

Positional Arguments:
    input               URI of the input stream
    output              URI of the output stream (default: file://output_video.mp4)

Optional Arguments:
    --no-headless       Enable the OpenGL GUI window (default: headless mode is enabled)

Description:
    This script allows viewing various types of video streams, optionally processing them
    and saving to an output file. The program supports headless mode by default, but the
    GUI can be enabled using the --no-headless option.

For more information about the supported input/output URIs and advanced logging, refer to:
    videoSource.Usage(), videoOutput.Usage(), Log.Usage()
"""
    print(help_message)


def handle_interrupt(signal_num, frame):
    print("video stabilizer set exit_flag ... ...")
    exit_flag.set()

def main():
    signal.signal(signal.SIGINT, handle_interrupt)
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

    args = parser.parse_known_args()[0]
    if args.headless:
        sys.argv.append("--headless")

    # create video sources & outputs
    input = videoSource(args.input, argv=sys.argv)
    output = videoOutput(args.output, argv=sys.argv)

    # capture frames until EOS or user exits
    numFrames = 0

    # Initialize Stabilizer with user-defined parameters
    stabilizer = Stabilizer(
        downSample=1.0,
        zoomFactor=0.98,
        processVar=0.03,
        measVar=2,
        roiDiv=3.5,
        showrectROI=0,
        showTrackingPoints=0,
        showUnstabilized=0,
        maskFrame=0,
        showFullScreen=1,
        useStabilizer=True
    )

    while True:
        # capture the next image
        img = input.Capture()

        if img is None: # timeout
            if exit_flag.is_set():
                print("video stabilizer ready to exit ... ...")
                break
            continue  
            
        if numFrames % 25 == 0 or numFrames < 15:
            Log.Verbose(f"Raw video:  captured {numFrames} frames ({img.width} x {img.height})")

        numFrames += 1

        cv2_frame = cudaToNumpy(img)
        stabilizer.stabilize_cuda(cv2_frame)

        # render the image
        output.Render(img)
        
        # update the title bar
        output.SetStatus("Raw Video | {:d}x{:d} | {:.1f} FPS".format(img.width, img.height, output.GetFrameRate()))

        # exit on input/output EOS or quit by user
        if not input.IsStreaming() or not output.IsStreaming():
            break

        if exit_flag.is_set():
            print("video stabilizer ready to exit ... ...")
            break

        key = cv2.waitKey(delay_time) & 0xFF  # Capture the key press once
        if chr(key).lower() == 'q':  # Convert the key to lowercase for case-insensitive comparison
            print("Video stabilizer ready to quit ... ...")
            break
        elif chr(key).lower() == 's':  # Convert the key to lowercase for case-insensitive comparison
            stabilizer.toggle()

    # Release resources
    cv2.destroyAllWindows()

if __name__ == "__main__":
    import sys
    if "--help" in sys.argv or "-h" in sys.argv:
        display_help()
        sys.exit(0)

    main()
    print("video stabilizer done!")
    sys.exit(0)