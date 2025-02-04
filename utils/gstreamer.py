import sys
import argparse
import time
import gi
gi.require_version('Gst', '1.0')
gi.require_version('GstBase', '1.0')
gi.require_version('GstVideo', '1.0')
from gi.repository import Gst, GLib


class VideoStreamer:
    def __init__(self, port, input_codec, fullscreen):
        self.port = port
        self.input_codec = input_codec
        self.fullscreen = fullscreen
        self.frame_count = 0
        self.start_time = time.time()
        self.pipeline = None
        self.loop = None

    def on_new_frame(self, pad, info):
        """
        Callback function to increment frame count whenever a new frame is processed.
        """
        self.frame_count += 1
        return Gst.PadProbeReturn.OK

    def update_fps(self):
        """
        Timer callback to calculate and print FPS every second.
        """
        current_time = time.time()
        elapsed_time = current_time - self.start_time
        if elapsed_time >= 1.0:
            fps = self.frame_count / elapsed_time
            print(f"FPS: {fps:.2f}")
            self.frame_count = 0
            self.start_time = current_time
        return True

    def build_pipeline(self):
        """
        Builds the GStreamer pipeline based on the input codec and port.
        """
        # Get current timestamp for the filename
        timestamp = time.strftime("%Y-%m-%d_%H-%M-%S", time.localtime())
        output_file = f"{timestamp}.mkv"  # Dynamic filename based on current timestamp

        if self.input_codec == "h264":
            pipeline_str = (
                f"udpsrc port={self.port} ! "
                "application/x-rtp,encoding-name=H264,payload=96 ! "
                "rtph264depay ! h264parse ! nvv4l2decoder ! "
                "nvvidconv ! video/x-raw,format=I420 ! "
                "tee name=t "
                "t. ! queue ! nv3dsink name=sink sync=0 "
                "t. ! queue ! x264enc speed-preset=ultrafast tune=zerolatency ! "
                f"matroskamux ! filesink location={output_file}"
            )
        else:
            pipeline_str = (
                f"udpsrc port={self.port} ! "
                "application/x-rtp,encoding-name=H265,payload=96 ! "
                "rtph265depay ! h265parse ! nvv4l2decoder ! "
                "nvvidconv ! video/x-raw,format=I420 ! "
                "tee name=t "
                "t. ! queue ! nv3dsink name=sink sync=0 "
                "t. ! queue ! x264enc speed-preset=ultrafast tune=zerolatency ! "
                "t. ! queue ! x264enc speed-preset=ultrafast tune=zerolatency ! "
                f"matroskamux ! filesink location={output_file}"
            )

        print("Selected Pipeline:", pipeline_str)
        return Gst.parse_launch(pipeline_str)

    def on_message(self, bus, message):
        """
        Handles messages from the GStreamer pipeline.
        """
        msg_type = message.type
        if msg_type == Gst.MessageType.EOS:
            print("End-Of-Stream reached.")
            self.loop.quit()
        elif msg_type == Gst.MessageType.ERROR:
            err, debug = message.parse_error()
            print(f"Error: {err}, {debug}")
            self.loop.quit()

    def run(self):
        """
        Sets up and runs the GStreamer pipeline.
        """
        Gst.init(None)
        self.pipeline = self.build_pipeline()

        # Configure nv3dsink fullscreen if required
        sink = self.pipeline.get_by_name("sink")
        if sink and hasattr(sink.props, "fullscreen"):
            sink.set_property("fullscreen", self.fullscreen)

        # Set a probe to track frames (optional, can be omitted if performance critical)
        if sink:
            pad = sink.get_static_pad("sink")
            if pad:
                pad.add_probe(Gst.PadProbeType.BUFFER, self.on_new_frame)

        # Attach bus message handler
        bus = self.pipeline.get_bus()
        bus.add_signal_watch()
        bus.connect("message", self.on_message)

        # Start pipeline
        self.pipeline.set_state(Gst.State.PLAYING)

        # Setup FPS timer
        GLib.timeout_add(1000, self.update_fps)

        # Create and run main loop
        self.loop = GLib.MainLoop()
        try:
            print("Running...")
            self.loop.run()
        except KeyboardInterrupt:
            print("Exiting...")

        # Clean up
        self.pipeline.set_state(Gst.State.NULL)

def print_help():
    """Print help message for MKV to MP4 conversion using ffmpeg."""
    help_message = """
    You can use the `ffmpeg` tool to convert `.mkv` files to `.mp4` format with the following command:

    ffmpeg -i input.mkv -c:v copy -c:a copy output.mp4

    Explanation:
    - -i input.mkv: The input `.mkv` file.
    - -c:v copy: Copy the video stream as is (i.e., without re-encoding).
    - -c:a copy: Copy the audio stream as is (i.e., without re-encoding).
    - output.mp4: The output `.mp4` file.

    If you need to re-encode the video or audio streams, you can use the following command:

    ffmpeg -i input.mkv -c:v libx264 -c:a aac -strict experimental output.mp4

    Explanation:
    - -c:v libx264: Use the `x264` encoder to re-encode the video stream.
    - -c:a aac: Use the `AAC` encoder to re-encode the audio stream.
    - -strict experimental: Allows the use of certain experimental encoding settings (such as AAC).

    This method can help you adjust format and encoding settings during the conversion.
    """
    print(help_message)

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="NVIDIA deepstream analytics of video streams")
    parser.add_argument("port", type=int, help="UDP port of RTP video stream")
    parser.add_argument(
        "--input-codec", type=str, choices=["h264", "h265"], default="h264", help="Input codec: h264 or h265 (default: h264)"
    )
    parser.add_argument(
        "--fullscreen", type=bool, default=True, help="Enable fullscreen display (default: True)"
    )
    return parser.parse_args()

def main():
    # Parse command line arguments
    args = parse_args()

    # Create and run video streamer
    streamer = VideoStreamer(args.port, args.input_codec, args.fullscreen)
    streamer.run()

if __name__ == "__main__":
    main()
    print("deepstream done!")
    print_help()
    sys.exit(0)
