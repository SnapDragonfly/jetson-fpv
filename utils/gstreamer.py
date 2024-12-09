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
        if self.input_codec == "h264":
            pipeline_str = (
                f"udpsrc port={self.port} ! "
                "application/x-rtp,encoding-name=H264,payload=96 ! "
                "rtph264depay ! h264parse ! nvv4l2decoder ! "
                "nv3dsink name=sink sync=0"
            )
        else:
            pipeline_str = (
                f"udpsrc port={self.port} ! "
                "application/x-rtp,encoding-name=H265,payload=96 ! "
                "rtph265depay ! h265parse ! nvv4l2decoder ! "
                "nv3dsink name=sink sync=0"
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


def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="NVIDIA deepstream analytics of video streams")
    parser.add_argument("port", type=int, help="UDP port of RTP video stream")
    parser.add_argument(
        "--input-codec", type=str, choices=["h264", "h265"], default="h265", help="Input codec: h264 or h265 (default: h265)"
    )
    parser.add_argument(
        "--fullscreen", type=bool, default=True, help="Enable fullscreen display (default: True)"
    )
    args = parser.parse_args()

    # Create and run video streamer
    streamer = VideoStreamer(args.port, args.input_codec, args.fullscreen)
    streamer.run()


if __name__ == "__main__":
    main()
    print("deepstream done!")
    sys.exit(0)

