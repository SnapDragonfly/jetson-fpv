#!/usr/bin/env python3
import os
import sys
import cv2
import torch
import time
import signal
import argparse
import psutil
import threading
import screeninfo
import numpy as np
from queue import Queue, Empty
from collections import deque
from ultralytics import YOLO
from ultralytics.engine.results import Results
from ultralytics.engine.results import Boxes
from jetson_utils import videoSource, videoOutput, Log, cudaToNumpy
from deep_sort_realtime.deepsort_tracker import DeepSort

# Global configurations
CONFIDENCE_THRESHOLD     = 0.5
MAX_QUEUE_SIZE           = 20  # Control memory usage
FRAME_RATE_ESTIMATE_CNT  = 60

# Define font color in BGR format or constants (e.g., white or yellow)
COLOR_WHITE              = (255, 255, 255)
COLOR_YELLOW             = (0, 255, 255)
COLOR_RED                = (0, 0, 255)
COLOR_BLUE               = (255, 0, 0)
COLOR_GREEN              = (0, 255, 0)

FONT_SCALE               = 0.6
FONT_THICKNESS           = 1
BOX_THICKNESS            = 1

YOLO_PREDICTION_STR      = "YOLO Prediction"

# Global controls
exit_flag = threading.Event()
exit_inference_flag = threading.Event()
frame_queue = Queue(maxsize=MAX_QUEUE_SIZE)
stats_lock = threading.Lock()

class ThreadSafeStats:
    def __init__(self):
        self.raw_fps_history = deque(maxlen=FRAME_RATE_ESTIMATE_CNT)
        self.show_fps_history = deque(maxlen=FRAME_RATE_ESTIMATE_CNT)

        self.inference_fps_history = deque(maxlen=FRAME_RATE_ESTIMATE_CNT)
        self.max_inference_time = 0
        self.min_inference_time = 9999
        self.latest_inference_time = 0

        self.tracking_fps_history = deque(maxlen=FRAME_RATE_ESTIMATE_CNT)
        self.max_tracking_time = 0
        self.min_tracking_time = 9999
        self.latest_tracking_time = 0

        self.tracking_interval_history = deque(maxlen=FRAME_RATE_ESTIMATE_CNT)

def PRINT(args, *print_args, **kwargs):
    if args.verbose:
        print(*print_args, **kwargs)

def get_least_busy_cpu():
    """Get the CPU ID with the lowest usage."""
    cpu_usage = psutil.cpu_percent(percpu=True)  # Get CPU usage for each core
    min_cpu_id = cpu_usage.index(min(cpu_usage))  # Find the least busy CPU ID
    return min_cpu_id

def bind_thread_to_cpu(cpu_id):
    """Bind the current thread to the specified CPU."""
    try:
        os.sched_setaffinity(0, {cpu_id})  # Set CPU affinity for the current process
        print(f"Thread {threading.get_native_id()} bound to CPU {cpu_id}")
    except AttributeError:
        print("CPU affinity setting is not supported on this system")

def handle_interrupt(signal_num, frame):
    exit_flag.set()
    print("YOLO start to exit ... ...")

def calculate_aspect_size(max_height, max_width, aspect_ratio=(4, 5), multiple=32):
    aspect_h, aspect_w = aspect_ratio
    factor_h = max_height // (aspect_h * multiple)
    factor_w = max_width // (aspect_w * multiple)
    factor = min(factor_h, factor_w)
    if factor <= 0:
        return 0, 0
    height = aspect_h * factor * multiple
    width = aspect_w * factor * multiple
    if height > max_height or width > max_width and factor > 0:
        factor -= 1
        height = aspect_h * factor * multiple
        width = aspect_w * factor * multiple
    return height, width

def predict_frame(model, frame, crop_height, crop_width, class_indices):
    original_height, original_width = frame.shape[:2]
    start_x = (original_width - crop_width) // 2
    start_y = (original_height - crop_height) // 2
    cropped_frame = frame[start_y:start_y + crop_height, start_x:start_x + crop_width]
    
    results = model.predict(
        source=cropped_frame,
        show=False,
        verbose=False,
        classes=class_indices,
        imgsz=[640, 640]
    )

    for result in results:
        if not hasattr(result, "boxes") or result.boxes is None:
            continue
        new_boxes = []
        for bbox in result.boxes:
            bbox_xyxy = bbox.xyxy.clone().detach().cpu().squeeze()
            if bbox_xyxy.numel() != 4:
                continue
            bbox_xyxy[0] += start_x
            bbox_xyxy[1] += start_y
            bbox_xyxy[2] += start_x
            bbox_xyxy[3] += start_y
            full_bbox = torch.tensor([*bbox_xyxy, bbox.conf.item(), bbox.cls.item()]).unsqueeze(0)
            new_boxes.append(full_bbox)
        if new_boxes:
            result.boxes = Boxes(
                torch.cat(new_boxes, dim=0).to('cuda'),
                orig_shape=(original_height, original_width)
            )
    return results

def capture_thread(args, model_info, stats):
    cpu_id = get_least_busy_cpu()  # Get the least busy CPU
    bind_thread_to_cpu(cpu_id)  # Bind the thread to the selected CPU

    input = videoSource(args.input, argv=sys.argv)
    output = videoOutput(args.output, argv=sys.argv)
    num_frames = 0
    num_frames_dropped = 0

    while not exit_flag.is_set():
        try:
            start_time = time.time()
            img = input.Capture()
            if img is None:
                continue

            # Convert and queue frame
            cv2_frame = cudaToNumpy(img)

            # Tracking parameters
            tracking_fps      = input.GetFrameRate()

            if not frame_queue.full():
                frame_queue.put((num_frames, cv2_frame, img.width, img.height, tracking_fps))
                PRINT(args, f"FRAME: put {num_frames}")
            else:
                num_frames_dropped += 1
                PRINT(args, f"FRAME: overflow {num_frames} {num_frames_dropped}")

            # Output original frame
            output.Render(img)

            # Update statistics
            with stats_lock:
                diff_time = time.time() - start_time
                if diff_time > 0:
                    stats.raw_fps_history.append(1.0 / diff_time)
            
            if not input.IsStreaming() or not output.IsStreaming():
                break

            num_frames += 1
        except Exception as e:
            print(f"Capture thread exception: {e}")
            break

    while frame_queue.qsize() != 0:
        time.sleep(1)
        print(f"Capture thread waiting {frame_queue.qsize()} frame buffer")
    print("Capture thread exited normally")
    exit_inference_flag.set()

def inference_thread(args, model_info, stats):
    cpu_id = get_least_busy_cpu()  # Get the least busy CPU
    bind_thread_to_cpu(cpu_id)  # Bind the thread to the selected CPU

    # YOLO model initialization
    model = YOLO(model_info['model_path'])
    configurable_classes = model_info['class_names']

    # DeepSort tracking initialization
    deepsort = DeepSort(max_age=10, n_init=2, max_iou_distance=0.7, nn_budget=50)

    # Configurable list of target classes to detect
    class_names = model.names  # This is likely a dictionary {index: class_name}

    # Convert class_names dict to list of class names and map them to indices
    class_indices = [index for index, name in class_names.items() if name in configurable_classes]

    print("Configured detection classes:", configurable_classes)
    print("Class indices for detection:", class_indices)

    window_initialized = False
    results = []

    tracking_interval = 1
    tracks = []

    while not exit_inference_flag.is_set() or frame_queue.qsize() != 0:
        try:
            mark_start = time.time()
            # Get frame data
            try:
                frame_id, cv2_frame, width, height, tracking_fps = frame_queue.get(timeout=0.1)
            except Empty:
                continue

            # Initialize window
            if not window_initialized:
                screen = screeninfo.get_monitors()[0]
                if screen.width <= width and screen.height <= height:
                    cv2.namedWindow(YOLO_PREDICTION_STR, cv2.WND_PROP_FULLSCREEN)
                    cv2.setWindowProperty(YOLO_PREDICTION_STR, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
                else:
                    cv2.namedWindow(YOLO_PREDICTION_STR, cv2.WND_PROP_AUTOSIZE)
                    window_x = (screen.width - width) // 2
                    window_y = (screen.height - height) // 2
                    cv2.moveWindow(YOLO_PREDICTION_STR, window_x, window_y)
                window_initialized = True

            # Perform inference
            annotated_frame = cv2_frame.copy()

            detections = []
            inference_time = 0
            if frame_id % tracking_interval != 0:
                PRINT(args, f"FRAME: deepsort {frame_id} {tracking_interval}")
            else:
                PRINT(args, f"FRAME: inference {frame_id}")
                corp_height, corp_width = calculate_aspect_size(height, width)

                # Predict using Yolo algorithm
                results = predict_frame(model, annotated_frame, corp_height, corp_width, class_indices)

                # Prepare detections for DeepSort (xywh format)
                for result in results[0].boxes.data.tolist():
                    x1, y1, x2, y2, conf, cls = map(float, result)
                    if conf < args.confidence:
                        continue
                    bbox = [x1, y1, x2 - x1, y2 - y1]  # Convert to [x, y, w, h]
                    detections.append((bbox, conf, cls))
                    PRINT(args, f"TRACKS: {frame_id} detections - {bbox[0]} {bbox[1]} {bbox[2]} {bbox[3]}")

                #print(results)
                if isinstance(results, list):
                    results = results[0]
                if hasattr(results, "speed") and "inference" in results.speed:
                    inference_time = results.speed["inference"]

            # DeepSort tracking update
            tracks = deepsort.update_tracks(detections, frame=annotated_frame)

            # Draw detect box
            if args.detect_box:
                cv2.rectangle(annotated_frame, 
                            ((width - corp_width)//2, (height - corp_height)//2),
                            ((width + corp_width)//2, (height + corp_height)//2),
                            COLOR_RED, BOX_THICKNESS)

            # Draw detection and tracking boxes
            if not tracks:
                PRINT(args, f"TRACKS: {frame_id} - No tracks")
            for track in tracks:
                ltrb = track.to_ltrb()
                x, y, w, h = map(int, ltrb)
                cls = int(track.det_class) if hasattr(track, 'det_class') else -1
                class_name = class_names.get(cls, "Unknown") if cls != -1 else "Unknown"

                if not track.is_confirmed(): # Not confirmed object
                    cv2.rectangle(annotated_frame, (x, y), (w, h), COLOR_YELLOW, BOX_THICKNESS)
                    cv2.putText(annotated_frame, f"{class_name}", (x, y - 10),
                                cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, COLOR_WHITE, FONT_THICKNESS)
                    PRINT(args, f"TRACKS: {frame_id} cls {cls} - {x} {y} {w} {h}")
                    continue

                track_id = track.track_id
                cv2.rectangle(annotated_frame, (x, y), (w, h), COLOR_GREEN, BOX_THICKNESS)
                cv2.putText(annotated_frame, f"{class_name} ID {track_id}", (x, y - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, COLOR_WHITE, FONT_THICKNESS)
                PRINT(args, f"TRACKS: {frame_id} id {track_id} - {x} {y} {w} {h}")

            # Update performance display 
            with stats_lock:
                if frame_id % tracking_interval != 0:
                    stats.latest_tracking_time = time.time() - mark_start
                    stats.tracking_fps_history.append(1.0 / stats.latest_tracking_time)

                    if stats.latest_tracking_time > stats.max_tracking_time:
                        stats.max_tracking_time = stats.latest_tracking_time
                    elif stats.latest_tracking_time < stats.min_tracking_time:
                        stats.min_tracking_time = stats.latest_tracking_time

                    PRINT(args, f"TRACKS: {frame_id} track_time {stats.latest_tracking_time}")
                else:
                    stats.latest_inference_time = inference_time/1000
                    stats.inference_fps_history.append(1.0 / stats.latest_inference_time)

                    if stats.latest_inference_time > stats.max_inference_time:
                        stats.max_inference_time = stats.latest_inference_time
                    elif stats.latest_inference_time < stats.min_inference_time:
                        stats.min_inference_time = stats.latest_inference_time

                    PRINT(args, f"TRACKS: {frame_id} inf_time {stats.latest_inference_time}")

                tracking_fps  = sum(stats.tracking_fps_history)/len(stats.tracking_fps_history) if stats.tracking_fps_history else 0
                inference_fps = sum(stats.inference_fps_history)/len(stats.inference_fps_history) if stats.inference_fps_history else 0
                raw_fps       = sum(stats.raw_fps_history)/len(stats.raw_fps_history) if stats.raw_fps_history else 0
                show_fps      = sum(stats.show_fps_history)/len(stats.show_fps_history) if stats.show_fps_history else 0
                status_text = (YOLO_PREDICTION_STR + " - "
                            + f"FPS: {raw_fps:.1f}/{tracking_fps:.1f}/{inference_fps:.1f}/{show_fps:.1f} | "
                            + f"Tracking: {stats.min_tracking_time:.3f}/{stats.latest_tracking_time:.3f}/{stats.max_tracking_time:.3f} | "
                            + f"Inference: {stats.min_inference_time:.3f}/{stats.latest_inference_time:.3f}/{stats.max_inference_time:.3f}")

                # Calculate tracking interval
                tracking_interval = max(1, int(raw_fps/inference_fps) - 1) * args.detect_ratio
                stats.tracking_interval_history.append(tracking_interval)
                tracking_interval = sum(stats.tracking_interval_history)/len(stats.tracking_interval_history) if stats.tracking_interval_history else 1

            # Display status info
            text_size = cv2.getTextSize(status_text, cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, FONT_THICKNESS)[0]
            cv2.putText(annotated_frame, status_text, 
                      (width - text_size[0] - 10, 30), 
                      cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, COLOR_WHITE, FONT_THICKNESS)

            # DEBUG: We observed that the frame interruption,
            # might be due to the queue being full and not processed in time.
            # print(f"{frame_id} ")

            # Display frame
            cv2.imshow(YOLO_PREDICTION_STR, annotated_frame)
            cv2.waitKey(1) # 1ms

            with stats_lock:
                diff_time = time.time() - mark_start
                stats.show_fps_history.append(1.0 / diff_time)
 

        except Exception as e:
            print(f"Inference thread exception: {e}")
            frame_queue.queue.clear()
            exit_flag.set()
            break
    print("Inference thread exited normally")

def main():
    if "DISPLAY" not in os.environ:
        os.environ["DISPLAY"] = ":0"

    signal.signal(signal.SIGINT, handle_interrupt)
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=str)
    parser.add_argument("output", type=str, default="file://output.mkv", nargs='?')
    parser.add_argument("--no-headless", action="store_false", dest="headless")
    parser.add_argument("--detect-box", action="store_true", dest="detect_box")
    parser.add_argument("--detect-ratio", type=int, default=2)
    parser.add_argument("--confidence", type=float, default=0.5)
    parser.add_argument("--model", type=str, default="11n")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose output")
    args = parser.parse_args()

    if args.headless:
        sys.argv.append("--headless")

    # Model configurations
    model_paths = {
        '11n': './model/yolo11n.engine',
        '5nu': './model/yolov5nu.engine',
        '8n': './model/yolov8n.engine'
    }

    class_names = [
        'person', 'car', 'motorcycle', 'bus', 'truck', 'airplane', 'boat'
    ]  # User-defined classes to detect

    stats = ThreadSafeStats()
    model_info = {
        'model_path': model_paths[args.model],
        'class_names': class_names
    }

    # Start threads
    inference_t = threading.Thread(target=inference_thread, args=(args, model_info, stats))
    capture_t = threading.Thread(target=capture_thread, args=(args, model_info, stats))

    inference_t.start()

    # Make sure the inference thread is started and ready for operation
    time.sleep(3)
    capture_t.start()

    capture_t.join()
    inference_t.join()

    cv2.destroyAllWindows()
    PRINT(args, f"FRAME: inf_min {stats.min_inference_time} ")
    PRINT(args, f"FRAME: inf_max {stats.max_inference_time} ")
    PRINT(args, f"FRAME: track_min {stats.min_tracking_time} ")
    PRINT(args, f"FRAME: track_max {stats.max_tracking_time} ")
    print("YOLO exited normally")

if __name__ == "__main__":
    main()
