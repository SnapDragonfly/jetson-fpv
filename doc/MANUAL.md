# Manual

```
$ sudo ./wrapper.sh help
Invalid module: help
Usage: ./wrapper.sh <module_name> {start|restart|ostart|orestart|stop|status|help|<other_command>} [additional_arguments]

Commands:
  start           Start a module
  restart         Restart a module
  ostart          Start a module without msposd
  orestart        Restart a module without msposd
  stop            Stop a module
  status          Check the status of a module
  help            Display this help message
  <other_command> Pass any other command directly to the module script, such as test etc.

Available modules
  Special modules: version wfb
     Base modules: viewer imagenet detectnet segnet posenet gstreamer
 Extended modules: stabilizer yolo deepstream dsyolo

    Version Module: Check depended component versions.
        Wfb Module: Wifibroadcast transmission module.
     Viewer Module: Displays the video stream.
   Imagenet Module: Image classification using Imagenet model.
  Detectnet Module: Object detection using DetectNet.
     Segnet Module: Image segmentation using SegNet.
    Posenet Module: Pose estimation using PoseNet.
  GStreamer Module: GST pipelines to process audio and video, offering flexible, plugin-based support for playback, streaming, and media transformation.
 Stabilizer Module: Stabilizes the camera or system.
       Yolo Module: Real-time object detection using YOLO.
 Deepstream Module: Framework from NVIDIA that enables video analytics and AI processing, using hardware-accelerated inference for deep learning models in real-time.
 Deepstream + YOLO: DeepStream integrates YOLO for real-time object detection and tracking.
```

# simple fpv

- start fpv
```
$ sudo ./wrapper.sh viewer start
```

- stop fpv
```
$ sudo ./wrapper.sh viewer stop
```

- check status
```
$ sudo ./wrapper.sh viewer status
```

# quit fpv

ESC Key to quit and get control back!

