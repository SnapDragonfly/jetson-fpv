#!/usr/bin/env python3

import sys
sys.path.append('./')
from pathlib import Path
from os import environ

import configparser
import argparse

import gi
gi.require_version('Gst', '1.0')
from gi.repository import GLib, Gst

from ctypes import *
import time
import sys
import math
import platform
from common.platform_info import PlatformInfo
from common.bus_call import bus_call
from common.FPS import PERF_DATA
from common.source_bin import create_rtp_h265_source_bin
from common.source_bin import create_rtp_h264_source_bin
from common.source_bin import create_source_bin
import re

import pyds
import os

if "DISPLAY" not in os.environ:
    os.environ["DISPLAY"] = ":0"

no_display = False
silent = False

codec_h264 = True
perf_data = None
measure_latency = False

MAX_DISPLAY_LEN=64
PGIE_CLASS_ID_VEHICLE = 0
PGIE_CLASS_ID_BICYCLE = 1
PGIE_CLASS_ID_PERSON = 2
PGIE_CLASS_ID_ROADSIGN = 3
MUXER_OUTPUT_WIDTH=1920
MUXER_OUTPUT_HEIGHT=1080
MUXER_BATCH_TIMEOUT_USEC = 33000
TILED_OUTPUT_WIDTH=1920
TILED_OUTPUT_HEIGHT=1080
GST_CAPS_FEATURES_NVMM="memory:NVMM"
OSD_PROCESS_MODE= 0
OSD_DISPLAY_TEXT= 1

DEEPSTREAM_TEST_PGIE_CONFIG = "dstest3_pgie_config.txt"

# pgie_src_pad_buffer_probe  will extract metadata received on tiler sink pad
# and update params for drawing rectangle, object information etc.
def pgie_src_pad_buffer_probe(pad, info, u_data):
    frame_number = 0
    num_rects = 0
    got_fps = False
    gst_buffer = info.get_buffer()
    if not gst_buffer:
        print("Unable to get GstBuffer ")
        return
    # Retrieve batch metadata from the gst_buffer
    # Note that pyds.gst_buffer_get_nvds_batch_meta() expects the
    # C address of gst_buffer as input, which is obtained with hash(gst_buffer)

    # Enable latency measurement via probe if environment variable NVDS_ENABLE_LATENCY_MEASUREMENT=1 is set.
    # To enable component level latency measurement, please set environment variable
    # NVDS_ENABLE_COMPONENT_LATENCY_MEASUREMENT=1 in addition to the above.
    global measure_latency
    if measure_latency:
        num_sources_in_batch = pyds.nvds_measure_buffer_latency(hash(gst_buffer))
        if num_sources_in_batch == 0:
            print("Unable to get number of sources in GstBuffer for latency measurement")

    batch_meta = pyds.gst_buffer_get_nvds_batch_meta(hash(gst_buffer))
    l_frame = batch_meta.frame_meta_list
    while l_frame is not None:
        try:
            # Note that l_frame.data needs a cast to pyds.NvDsFrameMeta
            # The casting is done by pyds.NvDsFrameMeta.cast()
            # The casting also keeps ownership of the underlying memory
            # in the C code, so the Python garbage collector will leave
            # it alone.
            frame_meta = pyds.NvDsFrameMeta.cast(l_frame.data)
        except StopIteration:
            break

        frame_number=frame_meta.frame_num
        l_obj=frame_meta.obj_meta_list
        num_rects = frame_meta.num_obj_meta
        obj_counter = {
        PGIE_CLASS_ID_VEHICLE:0,
        PGIE_CLASS_ID_PERSON:0,
        PGIE_CLASS_ID_BICYCLE:0,
        PGIE_CLASS_ID_ROADSIGN:0
        }
        while l_obj is not None:
            try: 
                # Casting l_obj.data to pyds.NvDsObjectMeta
                obj_meta=pyds.NvDsObjectMeta.cast(l_obj.data)
            except StopIteration:
                break
            obj_counter[obj_meta.class_id] += 1
            try: 
                l_obj=l_obj.next
            except StopIteration:
                break
        if not silent:
            print("Frame Number=", frame_number, "Number of Objects=",num_rects,"Vehicle_count=",obj_counter[PGIE_CLASS_ID_VEHICLE],"Person_count=",obj_counter[PGIE_CLASS_ID_PERSON])

        # Update frame rate through this probe
        stream_index = "stream{0}".format(frame_meta.pad_index)
        global perf_data
        perf_data.update_fps(stream_index)

        try:
            l_frame=l_frame.next
        except StopIteration:
            break

    return Gst.PadProbeReturn.OK

def main(args, requested_pgie=None, config=None, disable_probe=False):
    global perf_data
    perf_data = PERF_DATA(len(args))

    number_sources=len(args)

    platform_info = PlatformInfo()
    # Standard GStreamer initialization

    Gst.init(None)

    # Create gstreamer elements
    # Create Pipeline element that will form a connection of other elements
    print("Creating Pipeline \n ")
    pipeline = Gst.Pipeline()
    is_live = False

    if not pipeline:
        sys.stderr.write(" Unable to create Pipeline \n")

    print("Creating streamux \n ")

    # Create nvstreammux instance to form batches from one or more sources.
    streammux = Gst.ElementFactory.make("nvstreammux", "Stream-muxer")
    if not streammux:
        sys.stderr.write(" Unable to create NvStreamMux \n")

    pipeline.add(streammux)

    for i in range(number_sources):
        print("Creating source_bin ",i," \n ")
        uri_name=args[i]
        if uri_name.find("rtsp://") == 0 or uri_name.find("rtp://") == 0:
            is_live = True

        if uri_name.find("rtp://") == 0:
            if codec_h264:
                source_bin = create_rtp_h264_source_bin(i, uri_name)
            else:
                source_bin = create_rtp_h265_source_bin(i, uri_name)
        else:
            source_bin = create_source_bin(i, uri_name)

        if not source_bin:
            sys.stderr.write("Unable to create source bin \n")
        pipeline.add(source_bin)
        padname="sink_%u" %i
        sinkpad= streammux.request_pad_simple(padname) 
        if not sinkpad:
            sys.stderr.write("Unable to create sink pad bin \n")
        srcpad=source_bin.get_static_pad("src")
        if not srcpad:
            sys.stderr.write("Unable to create src pad bin \n")
        srcpad.link(sinkpad)

    queue1=Gst.ElementFactory.make("queue","queue1")
    queue2=Gst.ElementFactory.make("queue","queue2")
    queue3=Gst.ElementFactory.make("queue","queue3")
    queue4=Gst.ElementFactory.make("queue","queue4")
    queue5=Gst.ElementFactory.make("queue","queue5")
    pipeline.add(queue1)
    pipeline.add(queue2)
    pipeline.add(queue3)
    pipeline.add(queue4)
    pipeline.add(queue5)

    nvdslogger = None

    print("Creating Pgie \n ")
    if requested_pgie != None and (requested_pgie == 'nvinferserver' or requested_pgie == 'nvinferserver-grpc') :
        pgie = Gst.ElementFactory.make("nvinferserver", "primary-inference")
    elif requested_pgie != None and requested_pgie == 'nvinfer':
        pgie = Gst.ElementFactory.make("nvinfer", "primary-inference")
    else:
        pgie = Gst.ElementFactory.make("nvinfer", "primary-inference")

    if not pgie:
        sys.stderr.write(" Unable to create pgie :  %s\n" % requested_pgie)

    if disable_probe:
        # Use nvdslogger for perf measurement instead of probe function
        print ("Creating nvdslogger \n")
        nvdslogger = Gst.ElementFactory.make("nvdslogger", "nvdslogger")

    print("Creating tiler \n ")
    tiler=Gst.ElementFactory.make("nvmultistreamtiler", "nvtiler")
    if not tiler:
        sys.stderr.write(" Unable to create tiler \n")
    print("Creating nvvidconv \n ")
    nvvidconv = Gst.ElementFactory.make("nvvideoconvert", "convertor")
    if not nvvidconv:
        sys.stderr.write(" Unable to create nvvidconv \n")
    print("Creating nvosd \n ")
    nvosd = Gst.ElementFactory.make("nvdsosd", "onscreendisplay")
    if not nvosd:
        sys.stderr.write(" Unable to create nvosd \n")
    nvosd.set_property('process-mode',OSD_PROCESS_MODE)
    nvosd.set_property('display-text',OSD_DISPLAY_TEXT)

    if file_loop:
        if platform_info.is_integrated_gpu():
            # Set nvbuf-memory-type=4 for integrated gpu for file-loop (nvurisrcbin case)
            streammux.set_property('nvbuf-memory-type', 4)
        else:
            # Set nvbuf-memory-type=2 for x86 for file-loop (nvurisrcbin case)
            streammux.set_property('nvbuf-memory-type', 2)

    if no_display:
        print("Creating Fakesink \n")
        sink = Gst.ElementFactory.make("fakesink", "fakesink")
        sink.set_property('enable-last-sample', 0)
        sink.set_property('sync', 0)
    else:
        if platform_info.is_integrated_gpu():
            print("Creating nv3dsink \n")
            sink = Gst.ElementFactory.make("nv3dsink", "nv3d-sink")
            if not sink:
                sys.stderr.write(" Unable to create nv3dsink \n")
        else:
            if platform_info.is_platform_aarch64():
                print("Creating nv3dsink \n")
                sink = Gst.ElementFactory.make("nv3dsink", "nv3d-sink")
            else:
                print("Creating EGLSink \n")
                sink = Gst.ElementFactory.make("nveglglessink", "nvvideo-renderer")
            if not sink:
                sys.stderr.write(" Unable to create egl sink \n")

        # Use window resizing for fullscreen effect (for nv3dsink)
        if sink:
        #    sink.set_property('fullscreen', True)  # Enable fullscreen
            sink.set_property('window-x', 0)
            sink.set_property('window-y', 0)
            sink.set_property('window-width', 1920)  # Assuming 1920x1080 resolution
            sink.set_property('window-height', 1080)

    if not sink:
        sys.stderr.write(" Unable to create sink element \n")

    if is_live:
        print("At least one of the sources is live")
        streammux.set_property('live-source', 1)

    streammux.set_property('width', 1920)
    streammux.set_property('height', 1080)
    streammux.set_property('batch-size', number_sources)
    streammux.set_property('batched-push-timeout', MUXER_BATCH_TIMEOUT_USEC)
    if requested_pgie == "nvinferserver" and config != None:
        pgie.set_property('config-file-path', config)
    elif requested_pgie == "nvinferserver-grpc" and config != None:
        pgie.set_property('config-file-path', config)
    elif requested_pgie == "nvinfer" and config != None:
        pgie.set_property('config-file-path', config)
    else:
        pgie.set_property('config-file-path', DEEPSTREAM_TEST_PGIE_CONFIG)
    
    pgie_batch_size=pgie.get_property("batch-size")
    if(pgie_batch_size != number_sources):
        print("WARNING: Overriding infer-config batch-size",pgie_batch_size," with number of sources ", number_sources," \n")
        pgie.set_property("batch-size",number_sources)
    tiler_rows=int(math.sqrt(number_sources))
    tiler_columns=int(math.ceil((1.0*number_sources)/tiler_rows))
    tiler.set_property("rows",tiler_rows)
    tiler.set_property("columns",tiler_columns)
    tiler.set_property("width", TILED_OUTPUT_WIDTH)
    tiler.set_property("height", TILED_OUTPUT_HEIGHT)

    if platform_info.is_integrated_gpu():
        tiler.set_property("compute-hw", 2)
    else:
        tiler.set_property("compute-hw", 1)
    sink.set_property("qos",0)

    print("Adding elements to Pipeline \n")
    pipeline.add(pgie)
    if nvdslogger:
        pipeline.add(nvdslogger)
    pipeline.add(tiler)
    pipeline.add(nvvidconv)
    pipeline.add(nvosd)
    pipeline.add(sink)

    print("Linking elements in the Pipeline \n")
    streammux.link(queue1)
    queue1.link(pgie)
    pgie.link(queue2)
    if nvdslogger:
        queue2.link(nvdslogger)
        nvdslogger.link(tiler)
    else:
        queue2.link(tiler)
    tiler.link(queue3)
    queue3.link(nvvidconv)
    nvvidconv.link(queue4)
    queue4.link(nvosd)
    nvosd.link(queue5)
    queue5.link(sink)   

    # create an event loop and feed gstreamer bus mesages to it
    loop = GLib.MainLoop()
    bus = pipeline.get_bus()
    bus.add_signal_watch()
    bus.connect ("message", bus_call, loop)
    pgie_src_pad=pgie.get_static_pad("src")
    if not pgie_src_pad:
        sys.stderr.write(" Unable to get src pad \n")
    else:
        if not disable_probe:
            pgie_src_pad.add_probe(Gst.PadProbeType.BUFFER, pgie_src_pad_buffer_probe, 0)
            # perf callback function to print fps every 5 sec
            GLib.timeout_add(5000, perf_data.perf_print_callback)

    # Enable latency measurement via probe if environment variable NVDS_ENABLE_LATENCY_MEASUREMENT=1 is set.
    # To enable component level latency measurement, please set environment variable
    # NVDS_ENABLE_COMPONENT_LATENCY_MEASUREMENT=1 in addition to the above.
    if environ.get('NVDS_ENABLE_LATENCY_MEASUREMENT') == '1':
        print ("Pipeline Latency Measurement enabled!\nPlease set env var NVDS_ENABLE_COMPONENT_LATENCY_MEASUREMENT=1 for Component Latency Measurement")
        global measure_latency
        measure_latency = True

    # List the sources
    print("Now playing...")
    for i, source in enumerate(args):
        print(i, ": ", source)

    print("Starting pipeline \n")
    
    # start play back and listed to events
    pipeline.set_state(Gst.State.PLAYING)
    try:
      loop.run()
    except:
      pass

    # cleanup
    print("Exiting app\n")
    pipeline.set_state(Gst.State.NULL)

def parse_args():

    parser = argparse.ArgumentParser(prog="deepstream",
                    description="deepstream multi stream, supports rtp:// rtsp:// file://")
    parser.add_argument(
        "-i",
        "--input",
        help="Path to input streams",
        nargs="+",
        metavar="URIs",
        default=["a"],
        required=True,
    )
    parser.add_argument(
        "--input-codec", 
        type=str, choices=["h264", "h265"], 
        default="h264", 
        help="Input codec: h264 or h265 (default: h264)"
    )
    parser.add_argument(
        "-c",
        "--configfile",
        metavar="config_location.txt",
        default=None,
        help="Choose the config-file to be used with specified pgie",
    )
    parser.add_argument(
        "-g",
        "--pgie",
        default=None,
        help="Choose Primary GPU Inference Engine",
        choices=["nvinfer", "nvinferserver", "nvinferserver-grpc"],
    )
    parser.add_argument(
        "--no-display",
        action="store_true",
        default=False,
        dest='no_display',
        help="Disable display of video output",
    )
    parser.add_argument(
        "--file-loop",
        action="store_true",
        default=False,
        dest='file_loop',
        help="Loop the input file sources after EOS",
    )
    parser.add_argument(
        "--disable-probe",
        action="store_true",
        default=False,
        dest='disable_probe',
        help="Disable the probe function and use nvdslogger for FPS",
    )
    parser.add_argument(
        "-s",
        "--silent",
        action="store_true",
        default=False,
        dest='silent',
        help="Disable verbose output",
    )
    # Check input arguments
    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(1)
    args = parser.parse_args()

    stream_paths = args.input
    pgie = args.pgie
    config = args.configfile
    disable_probe = args.disable_probe
    
    global no_display
    global silent
    global file_loop
    global codec_h264

    no_display = args.no_display
    silent = args.silent
    file_loop = args.file_loop
    if args.input_codec == "h264":
        codec_h264 = True
    else:
        codec_h264 = False

    if config and not pgie or pgie and not config:
        sys.stderr.write ("\nEither pgie or configfile is missing. Please specify both! Exiting...\n\n\n\n")
        parser.print_help()
        sys.exit(1)
    if config:
        config_path = Path(config)
        if not config_path.is_file():
            sys.stderr.write ("Specified config-file: %s doesn't exist. Exiting...\n\n" % config)
            sys.exit(1)

    print(vars(args))
    return stream_paths, pgie, config, disable_probe

if __name__ == '__main__':
    # Get the current working directory
    current_directory = os.getcwd()
    print(f"Current working directory: {current_directory}")

    # Set the new working directory
    new_directory = './utils/deepstream/'  # Replace with the path you want
    os.chdir(new_directory)

    # Verify the new working directory
    current_directory = os.getcwd()
    print(f"New working directory: {current_directory}")

    stream_paths, pgie, config, disable_probe = parse_args()
    sys.exit(main(stream_paths, pgie, config, disable_probe))

