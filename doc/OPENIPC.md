# OpenIPC Project

[OpenIPC](https://openipc.org/) is an open source operating system from the open community targeting for IP cameras

# Support Targets

There are two source of camera support list:

- [OpenIPC/builder](https://github.com/OpenIPC/builder)
- [OpenIPC/firmware](https://github.com/OpenIPC/firmware)

# OSD Program

- [MSPOSD](https://github.com/OpenIPC/msposd)

There are two kinds of OSD in FPV camera firmware:

## 1. AirUnit OSD

**AirUnit**

```
$ msposd --master /dev/ttyS2 --baudrate 115200 --out 127.0.0.1:14560 --matrix 11 --ahi 1 -r 30 --osd
```

**GroundStation**

Just play RTP stream (UDP:5600) with H265 decoder.

## 2. GroundStation OSD

**AirUnit**

start msposd application send message to UPD:14560
```
$ msposd --master /dev/ttyS2 --baudrate 115200 --out 127.0.0.1:14560 --matrix 11 --ahi 1 -r 30
```

forward UDP:14560 to ground station UPD:14560
```
$ wfb_tx -p 17 -u 14560 -K /etc/drone.key -B 20 -M 1 -S 1 -L 1 -G long -k 1 -n 2 -T 0 -i 7669206 -f data wlan0
```


**GroundStation**

receive air unit msposd message send to UDP:14560
```
$ wfb_rx -p 17 -i 7669206 -u 14560 -K /etc/gs.key  wlan1
```

monitor UDP:14560 and draw info on ground station
```
$ msposd --master 127.0.0.1:14560  --osd -r 50 --ahi 1 --matrix 11 -v
```

# Reference

- [OpenIPC开源FPV之固件sysupgrade升级](https://blog.csdn.net/lida2003/article/details/143103377)
- [OpenIPC开源FPV之Ardupilot配置](https://blog.csdn.net/lida2003/article/details/143120610)
- [OpenIPC开源FPV之Channel配置](https://blog.csdn.net/lida2003/article/details/143167793)
- [OpenIPC开源FPV之msposd配置](https://blog.csdn.net/lida2003/article/details/143305757)
- [OpenIPC开源FPV之重要源码启动配置](https://blog.csdn.net/lida2003/article/details/142526783)
- [OpenIPC开源FPV之重要源码包](https://blog.csdn.net/lida2003/article/details/141780776)
- [OpenIPC开源FPV之工程框架](https://blog.csdn.net/lida2003/article/details/141745662)
- [OpenIPC开源FPV之工程编译](https://blog.csdn.net/lida2003/article/details/141693376)
- [Open FPV VTX开源之DIY硬件形态](https://blog.csdn.net/lida2003/article/details/145180370)
- [Open FPV VTX开源之硬件规格及组成](https://blog.csdn.net/lida2003/article/details/145055527)
- [Open FPV VTX开源之第一次出图](https://blog.csdn.net/lida2003/article/details/145072199)
- [Open FPV VTX开源之默认MAVLink设置](https://blog.csdn.net/lida2003/article/details/145080645)
- [Open FPV VTX开源之嵌入式OSD配置](https://blog.csdn.net/lida2003/article/details/145118339)
- [Open FPV VTX开源之ardupilot配置](https://blog.csdn.net/lida2003/article/details/145136008)
- [Open FPV VTX开源之betaflight配置](https://blog.csdn.net/lida2003/article/details/145136745)
- [Open FPV VTX开源之inav配置](https://blog.csdn.net/lida2003/article/details/145138328)
- [Open FPV VTX开源之图形化配置工具](https://blog.csdn.net/lida2003/article/details/145157869)
- [Open FPV VTX开源之图形化系统升级](https://blog.csdn.net/lida2003/article/details/145161146)
- [Open FPV VTX开源之卡录功能](https://blog.csdn.net/lida2003/article/details/145201204)
