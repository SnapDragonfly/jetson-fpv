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
import numpy as np
from jetson_utils import videoSource, videoOutput, cudaToNumpy, cudaFromNumpy, Log

# key scan control:
# If the test video plays too fast, increase this value until the video plays at a proper speed.
# Default value is `1` (no delay).
delay_time = 1

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

    def __init__(self, downSample=downSample, zoomFactor=zoomFactor, processVar=processVar, measVar=measVar, 
                 roiDiv=roiDiv, showrectROI=showrectROI, showTrackingPoints=showTrackingPoints, showUnstabilized=showUnstabilized, 
                 maskFrame=maskFrame, showFullScreen=showFullScreen, delay_time=delay_time):
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
        self.delay_time = delay_time

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

    def apply(self, cv2_frame):

        # Resize the image
        res_w_orig = cv2_frame.shape[1]
        res_h_orig = cv2_frame.shape[0]
        res_w = int(res_w_orig * self.downSample)
        res_h = int(res_h_orig * self.downSample)
        frameSize = (res_w, res_h)

        Orig = cv2_frame
        if self.downSample != 1:
            cv2_frame = cv2.resize(cv2_frame, frameSize)  # Downsample if applicable

        # Set ROI region
        top_left = [int(res_h / self.roiDiv), int(res_w / self.roiDiv)]
        bottom_right = [int(res_h - (res_h / self.roiDiv)), int(res_w - (res_w / self.roiDiv))]

        currFrame = cv2_frame
        currGray = cv2.cvtColor(currFrame, cv2.COLOR_BGR2GRAY)
        currGray = currGray[top_left[0]:bottom_right[0], top_left[1]:bottom_right[1]]  # Select ROI

        # Handle first frame image
        if self.prevFrame is None:
            self.prevOrig = cv2_frame
            self.prevFrame = cv2_frame
            self.prevGray = currGray

        # Show ROI rectangle box
        if self.showrectROI == 1:
            cv2.rectangle(self.prevOrig, (top_left[1], top_left[0]), (bottom_right[1], bottom_right[0]), color=(211, 211, 211), thickness=1)

        prevPts = cv2.goodFeaturesToTrack(self.prevGray, maxCorners=400, qualityLevel=0.01, minDistance=30, blockSize=3)
        if prevPts is not None:
            currPts, status, err = cv2.calcOpticalFlowPyrLK(self.prevGray, currGray, prevPts, None, **self.lk_params)
            assert prevPts.shape == currPts.shape
            idx = np.where(status == 1)[0]
            # Add orig video resolution pts to roi pts
            prevPts = prevPts[idx] + np.array([int(res_w_orig / self.roiDiv), int(res_h_orig / self.roiDiv)])
            currPts = currPts[idx] + np.array([int(res_w_orig / self.roiDiv), int(res_h_orig / self.roiDiv)])
            if self.showTrackingPoints == 1:
                for pT in prevPts:
                    cv2.circle(self.prevOrig, (int(pT[0][0]), int(pT[0][1])), 5, (211, 211, 211))
            if prevPts.size & currPts.size:
                m, inliers = cv2.estimateAffinePartial2D(prevPts, currPts)
            if m is None:
                m = self.lastRigidTransform
            # Smoothing
            dx = m[0, 2]
            dy = m[1, 2]
            da = np.arctan2(m[1, 0], m[0, 0])
        else:
            dx = 0
            dy = 0
            da = 0

        self.x += dx
        self.y += dy
        self.a += da
        Z = np.array([[self.x, self.y, self.a]], dtype="float")

        if self.count == 0:
            self.X_estimate = np.zeros((1, 3), dtype="float")
            self.P_estimate = np.ones((1, 3), dtype="float")
        else:
            self.X_predict = self.X_estimate
            self.P_predict = self.P_estimate + self.Q
            K = self.P_predict / (self.P_predict + self.R)
            self.X_estimate = self.X_predict + K * (Z - self.X_predict)
            self.P_estimate = (np.ones((1, 3), dtype="float") - K) * self.P_predict
            self.K_collect.append(K)
            self.P_collect.append(self.P_estimate)

        diff_x = self.X_estimate[0, 0] - self.x
        diff_y = self.X_estimate[0, 1] - self.y
        diff_a = self.X_estimate[0, 2] - self.a
        dx += diff_x
        dy += diff_y
        da += diff_a
        m = np.zeros((2, 3), dtype="float")
        m[0, 0] = np.cos(da)
        m[0, 1] = -np.sin(da)
        m[1, 0] = np.sin(da)
        m[1, 1] = np.cos(da)
        m[0, 2] = dx
        m[1, 2] = dy

        fS = cv2.warpAffine(self.prevOrig, m, (res_w_orig, res_h_orig))  # Apply magic stabilizer sauce to frame
        s = fS.shape
        T = cv2.getRotationMatrix2D((s[1] / 2, s[0] / 2), 0, self.zoomFactor)
        f_stabilized = cv2.warpAffine(fS, T, (s[1], s[0]))
        window_name = f"Video Viewer Stabilized: {res_w}x{res_h}"
        cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(window_name, res_w, res_h)  # Set window to the original size

        if self.maskFrame == 1:
            mask = np.zeros(f_stabilized.shape[:2], dtype="uint8")
            cv2.rectangle(mask, (100, 200), (1180, 620), 255, -1)
            f_stabilized = cv2.bitwise_and(f_stabilized, f_stabilized, mask=mask)
        if self.showFullScreen == 1:
            cv2.setWindowProperty(window_name, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)

        cv2.imshow(window_name, f_stabilized)

        if self.showUnstabilized == 1:
            cv2.imshow("Unstabilized ROI", self.prevGray)

        self.prevOrig = Orig
        self.prevGray = currGray
        self.prevFrame = currFrame
        self.lastRigidTransform = m
        self.count += 1

def main():

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

    try:
        args = parser.parse_known_args()[0]
    except:
        print("")
        parser.print_help()
        sys.exit(0)

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
        zoomFactor=1.0,
        processVar=0.03,
        measVar=2,
        roiDiv=4.0,
        showrectROI=0,
        showTrackingPoints=0,
        showUnstabilized=1,
        maskFrame=0,
        showFullScreen=0,
        delay_time=1
    )

    while True:
        # capture the next image
        img = input.Capture()

        if img is None: # timeout
            continue  
            
        if numFrames % 25 == 0 or numFrames < 15:
            Log.Verbose(f"Raw video:  captured {numFrames} frames ({img.width} x {img.height})")

        numFrames += 1

        cv2_frame = cudaToNumpy(img)
        stabilizer.apply(cv2_frame)

        # render the image
        output.Render(img)
        
        # update the title bar
        output.SetStatus("Raw Video | {:d}x{:d} | {:.1f} FPS".format(img.width, img.height, output.GetFrameRate()))

        # exit on input/output EOS
        if not input.IsStreaming() or not output.IsStreaming():
            break
        if cv2.waitKey(delay_time) & 0xFF == ord('q'):
            break

    # Release resources
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()

