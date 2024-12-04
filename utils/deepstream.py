import argparse
import time
import gi
gi.require_version('Gst', '1.0')
gi.require_version('GstBase', '1.0')
gi.require_version('GstVideo', '1.0')
from gi.repository import Gst, GLib

frame_count = 0
start_time = time.time()  # Initialize start_time globally

def on_new_frame(pad, info):
    """
    Callback function to increment frame count whenever a new frame is processed.
    """
    global frame_count
    frame_count += 1
    return Gst.PadProbeReturn.OK

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="NVIDIA deepstream analytics of video streams", 
                                     formatter_class=argparse.RawTextHelpFormatter)

    parser.add_argument(
        "port", 
        type=int,  # Use int for numeric ports
        help="UDP port of RTP video stream"
    )

    # Adding --input-codec argument for codec selection
    parser.add_argument(
        "--input-codec", 
        type=str,  
        choices=["h264", "h265"],  # Ensure only h264 or h265 can be chosen
        default="h265",  # Default to h265 if not specified
        help="Codec to be used for input stream: 'h264' or 'h265' (default: 'h265')"
    )

    # Adding --fullscreen argument for full screen display
    parser.add_argument(
        "--fullscreen", 
        type=bool, 
        default=True,  # Default to True for fullscreen
        help="Enable or disable fullscreen display (default: True)"
    )

    args = parser.parse_args()

    # Define the GStreamer pipeline with the provided port
    pipeline_h265_str = (
        f"udpsrc port={args.port} ! "
        "application/x-rtp,encoding-name=H265,payload=96 ! "
        "rtph265depay ! "
        "h265parse ! "
        "nvv4l2decoder ! "
        "nvvidconv ! "
        "xvimagesink"
    )

    pipeline_h264_str = (
        f"udpsrc port={args.port} ! "
        "application/x-rtp,encoding-name=H264,payload=96 ! "
        "rtph264depay ! "
        "h264parse ! "
        "nvv4l2decoder ! "
        "nvvidconv ! "
        "xvimagesink"
    )

    # Select the appropriate pipeline based on the input codec
    if args.input_codec == "h264":
        selected_pipeline = pipeline_h264_str
    else:
        selected_pipeline = pipeline_h265_str

    # Print the selected pipeline for testing
    print("Selected Pipeline:", selected_pipeline)

    # Initialize GStreamer
    Gst.init(None)

    # Create the GStreamer pipeline
    pipeline = Gst.parse_launch(selected_pipeline)

    # Get the xvimagesink element from the pipeline
    xvimagesink = pipeline.get_by_name("xvimagesink0")
    
    # Set a probe on the video sink to detect frame samples
    if xvimagesink:
        pad = xvimagesink.get_static_pad("sink")
        pad.add_probe(Gst.PadProbeType.BUFFER, on_new_frame)

    # Debug: List all elements in the pipeline
    print("Pipeline elements:")
    for element in pipeline.iterate_elements():
        print(f"- {element.get_name()}")

    # Check if xvimagesink was found
    if xvimagesink is None:
        print("Error: Could not find xvimagesink in the pipeline.")
    else:
        # No fullscreen property for xvimagesink, so we just display it in windowed mode
        pass

    # FPS calculation
    global frame_count
    global start_time  # Declare start_time as global
    frame_count = 0

    def update_fps():
        global frame_count
        global start_time  # Declare start_time as global
        current_time = time.time()
        elapsed_time = current_time - start_time
        if elapsed_time >= 1.0:
            fps = frame_count / elapsed_time
            # Update window title with FPS
            print(f"FPS: {fps:.2f}")
            frame_count = 0
            start_time = current_time
        return True

    # Set a timer to update FPS every second
    GLib.timeout_add(1000, update_fps)

    # Define a function to handle pipeline messages
    def on_message(bus, message):
        msg_type = message.type
        if msg_type == Gst.MessageType.EOS:
            print("End-Of-Stream reached.")
            loop.quit()
        elif msg_type == Gst.MessageType.ERROR:
            err, debug = message.parse_error()
            print(f"Error: {err}, {debug}")
            loop.quit()

    # Get the pipeline's bus and set up a message handler
    bus = pipeline.get_bus()
    bus.add_signal_watch()
    bus.connect("message", on_message)

    # Start playing the pipeline
    pipeline.set_state(Gst.State.PLAYING)

    # Create a GLib MainLoop to keep the program running
    loop = GLib.MainLoop()

    try:
        print("Running...")
        loop.run()
    except KeyboardInterrupt:
        print("Exiting...")

    # Clean up on exit
    pipeline.set_state(Gst.State.NULL)

if __name__ == "__main__":
    import sys
    if "--help" in sys.argv or "-h" in sys.argv:
        display_help()
        sys.exit(0)

    main()
    print("deepstream done!")
    sys.exit(0)
