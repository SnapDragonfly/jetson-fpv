# source_bin.py

import gi
gi.require_version('Gst', '1.0')
from gi.repository import GLib, Gst

from urllib.parse import urlparse

file_loop = False

def cb_newpad(decodebin, decoder_src_pad, data):
    print("In cb_newpad\n")
    caps=decoder_src_pad.get_current_caps()
    if not caps:
        caps = decoder_src_pad.query_caps()
    gststruct=caps.get_structure(0)
    gstname=gststruct.get_name()
    source_bin=data
    features=caps.get_features(0)

    # Need to check if the pad created by the decodebin is for video and not
    # audio.
    print("gstname=",gstname)
    if(gstname.find("video")!=-1):
        # Link the decodebin pad only if decodebin has picked nvidia
        # decoder plugin nvdec_*. We do this by checking if the pad caps contain
        # NVMM memory features.
        print("features=",features)
        if features.contains("memory:NVMM"):
            # Get the source bin ghost pad
            bin_ghost_pad=source_bin.get_static_pad("src")
            if not bin_ghost_pad.set_target(decoder_src_pad):
                sys.stderr.write("Failed to link decoder src pad to source bin ghost pad\n")
        else:
            sys.stderr.write(" Error: Decodebin did not pick nvidia decoder plugin.\n")

def decodebin_child_added(child_proxy,Object,name,user_data):
    print("Decodebin child added:", name, "\n")
    if(name.find("decodebin") != -1):
        Object.connect("child-added",decodebin_child_added,user_data)

    if "source" in name:
        source_element = child_proxy.get_by_name("source")
        if source_element.find_property('drop-on-latency') != None:
            Object.set_property("drop-on-latency", True)

def parse_rtp_url(rtp_url):
    parsed_url = urlparse(rtp_url)
    
    # Ensure the scheme is RTP
    if parsed_url.scheme != "rtp":
        raise ValueError("URL scheme is not RTP")
    
    # Extract netloc (e.g., @:5600 or 192.168.1.5:5000)
    netloc = parsed_url.netloc.strip()
    
    # Handle the case where the URL is in the format rtp://@:port
    if netloc.startswith('@:'):
        port = int(netloc[2:])  # Extract port after "@:"
        ip = "0.0.0.0"  # Default to all interfaces (wildcard)
    # Handle standard IP:port format
    elif re.match(r"(.+):(\d+)", netloc):
        match = re.match(r"(.+):(\d+)", netloc)
        ip = match.group(1)
        port = int(match.group(2))
    else:
        raise ValueError(f"Invalid RTP URL format: {rtp_url}")
    
    return ip, port

def create_rtp_h265_source_bin(index, uri):
    print("Creating rtp h265 bin")

    # Create a source GstBin to abstract this bin's content from the rest of the
    # pipeline
    bin_name="source-bin-%02d" %index
    print(bin_name)
    nbin=Gst.Bin.new(bin_name)
    if not nbin:
        sys.stderr.write(" Unable to create source bin \n")

    ip, port = parse_rtp_url(uri)
    udpsrc = Gst.ElementFactory.make("udpsrc", "udpsrc")
    print(f"{ip} {port}")
    udpsrc.set_property('address', ip)
    udpsrc.set_property('port', port)
    caps = Gst.Caps.from_string("application/x-rtp,encoding-name=H265,payload=96")
    capsfilter = Gst.ElementFactory.make("capsfilter", "capsfilter")
    capsfilter.set_property("caps", caps)
    rtph265depay = Gst.ElementFactory.make("rtph265depay", "rtph265depay")
    h265parse = Gst.ElementFactory.make("h265parse", "h265parse")
    nvv4l2decoder = Gst.ElementFactory.make("nvv4l2decoder", "nvv4l2decoder")

    # We need to create a ghost pad for the source bin which will act as a proxy
    # for the video decoder src pad. The ghost pad will not have a target right
    # now. Once the decode bin creates the video decoder and generates the
    # cb_newpad callback, we will set the ghost pad target to the video decoder
    # src pad.
    #Gst.Bin.add(nbin, udpsrc, capsfilter, rtph265depay,h265parse,nvv4l2decoder)
    nbin.add(udpsrc)
    nbin.add(capsfilter)
    nbin.add(rtph265depay)
    nbin.add(h265parse)
    nbin.add(nvv4l2decoder)
    udpsrc.link(capsfilter)
    capsfilter.link(rtph265depay)
    rtph265depay.link(h265parse)
    h265parse.link(nvv4l2decoder)
    bin_ghost_pad = Gst.GhostPad.new_no_target("src",Gst.PadDirection.SRC)
    bin_pad=nbin.add_pad(bin_ghost_pad)
    if not bin_pad:
        sys.stderr.write(" Failed to add ghost pad in source bin \n")
        return None
    decoder_src_pad=nvv4l2decoder.get_static_pad("src")
    bin_ghost_pad.set_target(decoder_src_pad)
    return nbin

def create_rtp_h264_source_bin(index, uri):
    print("Creating rtp h264 bin")

    # Create a source GstBin to abstract this bin's content from the rest of the
    # pipeline
    bin_name="source-bin-%02d" %index
    print(bin_name)
    nbin=Gst.Bin.new(bin_name)
    if not nbin:
        sys.stderr.write(" Unable to create source bin \n")

    ip, port = parse_rtp_url(uri)
    udpsrc = Gst.ElementFactory.make("udpsrc", "udpsrc")
    print(f"{ip} {port}")
    udpsrc.set_property('address', ip)
    udpsrc.set_property('port', port)
    caps = Gst.Caps.from_string("application/x-rtp,encoding-name=H264,payload=96")
    capsfilter = Gst.ElementFactory.make("capsfilter", "capsfilter")
    capsfilter.set_property("caps", caps)
    rtph264depay = Gst.ElementFactory.make("rtph264depay", "rtph264depay")
    h264parse = Gst.ElementFactory.make("h264parse", "h264parse")
    nvv4l2decoder = Gst.ElementFactory.make("nvv4l2decoder", "nvv4l2decoder")

    # We need to create a ghost pad for the source bin which will act as a proxy
    # for the video decoder src pad. The ghost pad will not have a target right
    # now. Once the decode bin creates the video decoder and generates the
    # cb_newpad callback, we will set the ghost pad target to the video decoder
    # src pad.
    #Gst.Bin.add(nbin, udpsrc, capsfilter, rtph265depay,h265parse,nvv4l2decoder)
    nbin.add(udpsrc)
    nbin.add(capsfilter)
    nbin.add(rtph264depay)
    nbin.add(h264parse)
    nbin.add(nvv4l2decoder)
    udpsrc.link(capsfilter)
    capsfilter.link(rtph264depay)
    rtph264depay.link(h264parse)
    h264parse.link(nvv4l2decoder)
    bin_ghost_pad = Gst.GhostPad.new_no_target("src",Gst.PadDirection.SRC)
    bin_pad=nbin.add_pad(bin_ghost_pad)
    if not bin_pad:
        sys.stderr.write(" Failed to add ghost pad in source bin \n")
        return None
    decoder_src_pad=nvv4l2decoder.get_static_pad("src")
    bin_ghost_pad.set_target(decoder_src_pad)
    return nbin

def create_source_bin(index,uri):
    print("Creating source bin")

    # Create a source GstBin to abstract this bin's content from the rest of the
    # pipeline
    bin_name="source-bin-%02d" %index
    print(bin_name)
    nbin=Gst.Bin.new(bin_name)
    if not nbin:
        sys.stderr.write(" Unable to create source bin \n")

    # Source element for reading from the uri.
    # We will use decodebin and let it figure out the container format of the
    # stream and the codec and plug the appropriate demux and decode plugins.
    if file_loop:
        # use nvurisrcbin to enable file-loop
        uri_decode_bin=Gst.ElementFactory.make("nvurisrcbin", "uri-decode-bin")
        uri_decode_bin.set_property("file-loop", 1)
        uri_decode_bin.set_property("cudadec-memtype", 0)
    else:
        uri_decode_bin=Gst.ElementFactory.make("uridecodebin", "uri-decode-bin")
    if not uri_decode_bin:
        sys.stderr.write(" Unable to create uri decode bin \n")
    # We set the input uri to the source element
    uri_decode_bin.set_property("uri",uri)
    # Connect to the "pad-added" signal of the decodebin which generates a
    # callback once a new pad for raw data has beed created by the decodebin
    uri_decode_bin.connect("pad-added",cb_newpad,nbin)
    uri_decode_bin.connect("child-added",decodebin_child_added,nbin)

    # We need to create a ghost pad for the source bin which will act as a proxy
    # for the video decoder src pad. The ghost pad will not have a target right
    # now. Once the decode bin creates the video decoder and generates the
    # cb_newpad callback, we will set the ghost pad target to the video decoder
    # src pad.
    Gst.Bin.add(nbin,uri_decode_bin)
    bin_pad=nbin.add_pad(Gst.GhostPad.new_no_target("src",Gst.PadDirection.SRC))
    if not bin_pad:
        sys.stderr.write(" Failed to add ghost pad in source bin \n")
        return None
    return nbin