#!/bin/bash

COLUMN_A_X=1400
COLUMN_B_X=1650
COLUMN_Y1=100
COLUMN_Y2=200
COLUMN_Y3=300
COLUMN_Y4=400

BG_OPACITY=0.5


CMD_PLOT_CSV="python3 ./utils/plot-widget.py"

verbose=0  # Default: verbose mode is off
delay=0 # Default: 0, no delay
csv_file=""
video_file=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      verbose=1
      shift ;;  # Move to next argument

    --delay)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        delay=$2
        shift 2  # Move past '--delay' and its value
      else
        echo "Error: --delay requires an integer argument."
        exit 1
      fi
      ;;

    -d)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        delay=$2
        shift 2  # Move past '-c' and its value
      else
        echo "Error: -c requires an integer argument."
        exit 1
      fi
      ;;

    --video)
      if [[ -n "$2" ]]; then
        video_file="$2"
        shift 2  # Move past '--video' and its value
      else
        echo "Error: --video requires a file path argument."
        exit 1
      fi
      ;;

    *)
      if [[ -z "$csv_file" ]]; then
        csv_file="$1"  # Assign first non-option argument as input file
        shift
      else
        echo "Error: Multiple input files detected. Only one file is allowed."
        exit 1
      fi
      ;;
  esac
done

######################################################################
# Column A
######################################################################

# FEC
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_A_X\
              --graph_y $COLUMN_Y1\
              --background_opacity=$BG_OPACITY\
              --title "FEC"\
              --item 21\
              --min_value -1\
              --max_value 20\
              --threshold 6\
              --direction +1 &


# Packet Drop
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_A_X\
              --graph_y $COLUMN_Y2\
              --background_opacity=$BG_OPACITY\
              --title "Packet drop"\
              --item 23\
              --min_value 0\
              --max_value 50\
              --threshold 15\
              --direction +1 &

# Packet Req
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_A_X\
              --graph_y $COLUMN_Y3\
              --background_opacity=$BG_OPACITY\
              --title "TX Req"\
              --item 24\
              --min_value 0\
              --max_value 2\
              --threshold 0\
              --direction +1 &

# Key Frame Req
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_A_X\
              --graph_y $COLUMN_Y4\
              --background_opacity=$BG_OPACITY\
              --title "RX Req"\
              --item 25\
              --min_value 0\
              --max_value 5\
              --threshold 0\
              --direction +1 &

######################################################################
# Column B
######################################################################

# link score
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_B_X\
              --graph_y $COLUMN_Y1\
              --background_opacity=$BG_OPACITY\
              --item 16 &

# RSSI
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_B_X\
              --graph_y $COLUMN_Y2\
              --background_opacity=$BG_OPACITY\
              --title "Link RSSI"\
              --item 17\
              --min_value -80\
              --max_value -30\
              --threshold -70\
              --direction -1 &

# SNR
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_B_X\
              --graph_y $COLUMN_Y3\
              --background_opacity=$BG_OPACITY\
              --title "Link SNR"\
              --item 19\
              --min_value 12\
              --max_value 38\
              --threshold 30\
              --direction +1 &

# Bitrate
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_B_X\
              --graph_y $COLUMN_Y4\
              --background_opacity=$BG_OPACITY\
              --title "Bitrate Kbps"\
              --item 2\
              --min_value 0\
              --max_value 12288\
              --threshold 2048\
              --direction -1 &

sleep $delay

if [[ -f "$video_file" ]]; then
  echo "Playing $video_file ..."
  video-viewer $video_file
else
  echo "No video file: $video_file"
fi

exit 0

# DEBUG commands FYI
python3 ./utils/plot-widget.py  2025-03-30_2/2025-03-30_15-13-23.csv\
                        --graph_x 1400\
                        --graph_y 900\
                        --graph_width 300\
                        --graph_height 100\
                        --title "Bitrate Kbps"\
                        --item 2\
                        --min_value 0\
                        --max_value 12288\
                        --threshold 2048\
                        --direction -1