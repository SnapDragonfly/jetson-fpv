#!/bin/bash

COLUMN_GRAPH_FIRST_LINE=150
COLUMN_GRAPH_HEIGHT=100

COLUMN_A_X=1400
COLUMN_B_X=1650

COLUMN_Y1=$COLUMN_GRAPH_FIRST_LINE
COLUMN_Y2=$((COLUMN_Y1+COLUMN_GRAPH_HEIGHT))
COLUMN_Y3=$((COLUMN_Y2+COLUMN_GRAPH_HEIGHT))
COLUMN_Y4=$((COLUMN_Y3+COLUMN_GRAPH_HEIGHT))
COLUMN_Y5=$((COLUMN_Y4+COLUMN_GRAPH_HEIGHT))
COLUMN_Y6=$((COLUMN_Y5+COLUMN_GRAPH_HEIGHT))

BG_OPACITY=0.5


CMD_PLOT_CSV="python3 ./utils/plot-widget.py"

verbose=0  # Default: verbose mode is off
delay=0 # Default: 0, no delay
csv_file=""
video_file=""

# Function to display help
show_help() {
  echo "Usage: $0 [OPTIONS] <csv_file>"
  echo
  echo "Options:"
  echo "  --verbose         Enable verbose mode"
  echo "  --delay <num>     Set delay in seconds (integer required)"
  echo "  -d <num>          Alias for --delay"
  echo "  --video <file>    Specify video file path"
  echo "  -h, --help        Show this help message and exit"
  echo
  echo "Example:"
  echo "  $0 --verbose --delay 5 --video sample.mp4 data.csv"
  exit 0
}

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

    -h|--help)
      show_help
      exit 1
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

# linkQ
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_A_X\
              --graph_y $COLUMN_Y1\
              --background_opacity=$BG_OPACITY\
              --title "LinkQ"\
              --item 15 &

# smthdQ
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_A_X\
              --graph_y $COLUMN_Y2\
              --background_opacity=$BG_OPACITY\
              --title "smthdQ"\
              --item 16 &

# Penalty
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_A_X\
              --graph_y $COLUMN_Y3\
              --background_opacity=$BG_OPACITY\
              --title "Penalty"\
              --item 22\
              --min_value -500\
              --max_value 0\
              --threshold -100\
              --direction -1 &

# Rx Drop
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_A_X\
              --graph_y $COLUMN_Y4\
              --background_opacity=$BG_OPACITY\
              --title "Rx Drop"\
              --item 26\
              --min_value 0\
              --max_value 20\
              --threshold 1\
              --direction +1 &

# Tx Drop
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_A_X\
              --graph_y $COLUMN_Y5\
              --background_opacity=$BG_OPACITY\
              --title "Tx Drop"\
              --item 23\
              --min_value 0\
              --max_value 50\
              --threshold 15\
              --direction +1 &

# CPU
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_A_X\
              --graph_y $COLUMN_Y6\
              --background_opacity=$BG_OPACITY\
              --title "CPU"\
              --item 12\
              --min_value 0\
              --max_value 100\
              --threshold 70\
              --direction +1 &

######################################################################
# Column B
######################################################################

# RSSI
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_B_X\
              --graph_y $COLUMN_Y1\
              --background_opacity=$BG_OPACITY\
              --title "RSSI"\
              --item 17\
              --min_value -80\
              --max_value -30\
              --threshold -70\
              --direction -1 &

# SNR
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_B_X\
              --graph_y $COLUMN_Y2\
              --background_opacity=$BG_OPACITY\
              --title "SNR"\
              --item 19\
              --min_value 12\
              --max_value 38\
              --threshold 30\
              --direction +1 &

# Bitrate
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_B_X\
              --graph_y $COLUMN_Y3\
              --background_opacity=$BG_OPACITY\
              --title "Bitrate Kbps"\
              --item 2\
              --min_value 0\
              --max_value 12288\
              --threshold 2048\
              --direction -1 &

# Rx Key Frame Req
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_B_X\
              --graph_y $COLUMN_Y4\
              --background_opacity=$BG_OPACITY\
              --title "RX Req"\
              --item 25\
              --min_value 0\
              --max_value 5\
              --threshold 0\
              --direction +1 &

# Tx Key Frame Req
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_B_X\
              --graph_y $COLUMN_Y5\
              --background_opacity=$BG_OPACITY\
              --title "TX Req"\
              --item 24\
              --min_value 0\
              --max_value 5\
              --threshold 0\
              --direction +1 &

# FEC
$CMD_PLOT_CSV $csv_file\
              --graph_x $COLUMN_B_X\
              --graph_y $COLUMN_Y6\
              --background_opacity=$BG_OPACITY\
              --title "FEC"\
              --item 21\
              --min_value 0\
              --max_value 20\
              --threshold 3\
              --direction +1 &

######################################################################
# Column C, reserved
######################################################################


######################################################################
# Video
######################################################################
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



python3 ./utils/plot-widget.py  2025-04-04_14-08-50/2025-04-04_14-08-50.csv\
                        --graph_x 1400\
                        --graph_y 900\
                        --graph_width 300\
                        --graph_height 100\
                        --title "Penalty"\
                        --item 22\
                        --min_value -600\
                        --max_value 0\
                        --threshold -50\
                        --direction -1