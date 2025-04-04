import sys
import signal
import csv
import numpy as np
from datetime import datetime
from PyQt5.QtWidgets import QApplication, QWidget
from PyQt5.QtCore import QTimer, Qt, QRect
from PyQt5.QtGui import QPainter, QColor, QPen, QFont
import argparse

DEFAULT_GRAPH_WIDTH=240
DEFAULT_GRAPH_HEIGHT=80
DEFAULT_GRAPH_BARS=20
DEFAULT_GRAPH_FONT_SIZE=12

class OSDWindow(QWidget):
    def __init__(self, 
                 timestamps, timestamp_strings, data, 
                 osd_width=1920, osd_height=1080,
                 graph_x=1400, graph_y=150, graph_width=DEFAULT_GRAPH_WIDTH, graph_height=DEFAULT_GRAPH_HEIGHT, 
                 background_opacity=0.5, num_bars=DEFAULT_GRAPH_BARS, 
                 title="Link Score", min_value=1000, max_value=2000, threshold=1500, direction=-1):
        super().__init__()
        self.timestamps = timestamps
        self.timestamp_strings = timestamp_strings  # Original timestamp strings for display
        self.data = data
        self.index = 0  # Current index in the timestamps array
        self.osd_width = osd_width # Default OSD width
        self.osd_height = osd_height # Default OSD height
        self.background_opacity = background_opacity  # OSD background transparency
        self.num_bars = num_bars  # Default number of bars
        self.min_value = min_value  # Configurable min value for data range
        self.max_value = max_value  # Configurable max value for data range
        self.threshold = threshold  # Configurable threshold for bar color change
        self.direction = direction  # Configurable direction for threshold comparison
        self.title = title  # Configurable title of the graph

        self.setWindowTitle('Transparent OSD Overlay')
        self.setGeometry(0, 0, self.osd_width, self.osd_height)
        self.setAttribute(Qt.WA_TranslucentBackground, True)  # Enable transparency
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)  # Remove window borders and set to always stay on top

        # Timer for updating the graph dynamically
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_graph)
        self.start_dynamic_timer()  # Start with the first interval

        # Data buffer
        self.buffer_timestamps = []
        self.buffer_data = []

        # OSD display area
        self.osd_region = QRect(graph_x, graph_y, graph_width, graph_height)  # x,y,width,height

    def start_dynamic_timer(self):
        """Dynamically set the timer interval based on timestamps."""
        if self.index < len(self.timestamps) - 1:
            interval = (self.timestamps[self.index + 1] - self.timestamps[self.index]) * 1000  # Convert to ms
            self.timer.start(int(interval))  # Start the timer with the computed interval
        else:
            self.timer.stop()  # Stop the timer if we reach the end

    def update_graph(self):
        """Update the graph based on timestamp intervals."""
        if self.index >= len(self.timestamps) - 1:  # Restart playback if at the end
            self.index = 0

        current_time = self.timestamps[self.index]

        # Update buffers
        self.buffer_timestamps.append(current_time)
        self.buffer_data.append(self.data[self.index])

        self.index += 1
        self.repaint()  # Trigger UI repaint
        self.start_dynamic_timer()  # Set the next update interval

        self.raise_()  # Manually raise the window to the top

    def paintEvent(self, event):
        """Render the OSD overlay."""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)

        # Draw semi-transparent background
        painter.setOpacity(self.background_opacity)
        painter.fillRect(self.osd_region, QColor(0, 0, 0))

        # Draw graph with a default of 40 bars
        if len(self.buffer_data) > 0:
            height = self.osd_region.height()
            width = self.osd_region.width()
            bar_width = max(1, width / self.num_bars * 0.8)  # Ensure bar width fits within available space
            spacing = (width - bar_width * self.num_bars) / (self.num_bars + 1)  # Calculate the spacing between bars

            window_data = self.buffer_data[-self.num_bars:]  # Get recent num_bars data
            if self.direction == 1:
                mvalue = max(window_data)
            else:
                mvalue = min(window_data)

            # Use min_value and max_value to normalize the data
            for i in range(min(len(self.buffer_data), self.num_bars)):
                value = self.buffer_data[-(i+1)]  # Get the latest value for the bars
                # Normalize the value within the defined min and max range
                if self.max_value == self.min_value:
                    normalized_value = height / 2
                else:
                    if self.min_value < 0:
                        normalized_value = (self.max_value - value) / (self.max_value - self.min_value) * height
                    else:
                        normalized_value = (value - self.min_value) / (self.max_value - self.min_value) * height

                # Make sure height is NOT exceeding/over the graph box
                normalized_value = min(height, normalized_value)

                x = self.osd_region.left() + width - (spacing * (i + 1) + i * bar_width) - bar_width  # Reverse the direction
                # y = self.osd_region.top() + height - normalized_value
                if self.min_value < 0:
                    y = self.osd_region.top()
                else:
                    y = self.osd_region.top() + height - normalized_value

                # Determine color based on threshold and direction
                if (self.direction == -1 and value < self.threshold) or (self.direction == 1 and value > self.threshold):
                    bar_color = QColor(255, 0, 0)  # Red if condition is met
                else:
                    bar_color = QColor(0, 255, 0)  # Green if condition is not met

                painter.setPen(QPen(bar_color))
                painter.setBrush(bar_color)
                painter.drawRect(int(x), int(y), int(bar_width), int(normalized_value))
                # DEBUG
                # print(f"{x} {y} {bar_width} {normalized_value}")

            # Adjust Y position of text based on direction
            if self.min_value < 0:
                text_y = self.osd_region.bottom() - 5  # bottom padding
            else:
                text_y = self.osd_region.top() + 15    # top padding

            painter.setPen(QPen(QColor(255, 255, 255)))
            painter.setFont(QFont("Arial", DEFAULT_GRAPH_FONT_SIZE))
            painter.drawText(self.osd_region.left() + 5, text_y,
                            f'{self.title}: {int(self.data[self.index])}/{int(mvalue)}')
            
        if self.index == (len(self.timestamp_strings) - 1):
            print(f"{self.title}: End of data, Quit.")
            sys.exit(0)

        painter.end()  # Ensure painter is properly closed


def read_csv(file_path, item=15):
    """Read CSV file and parse timestamps and data."""
    timestamps = []
    timestamp_strings = []
    data = []

    with open(file_path, newline='') as csvfile:
        reader = csv.reader(csvfile)
        next(reader)  # Skip header

        for row in reader:
            if not row:
                continue
            try:
                time_str = row[0]  # Read timestamp string
                time_obj = datetime.strptime(time_str, '%H:%M:%S.%f')
                timestamp_seconds = (time_obj.hour * 3600 + time_obj.minute * 60 +
                                     time_obj.second + time_obj.microsecond / 1e6)

                timestamps.append(timestamp_seconds)
                timestamp_strings.append(time_str)  # Keep original string format
                data.append(float(row[item]))  # Extract data from the 16th column
            except (ValueError, IndexError) as e:
                print(f"Skipping invalid row: {row}, Error: {e}")

    return np.array(timestamps), timestamp_strings, np.array(data)


def signal_handler(sig, frame):
    """Handle Ctrl+C to exit gracefully."""
    print("Exiting plot-widget by Ctrl+C ...")
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)

    # Argument parsing
    parser = argparse.ArgumentParser(description="OSD Overlay with CSV data")
    parser.add_argument('csv_file', type=str, help="CSV file path")
    parser.add_argument('--graph_x', type=int, default=1400, help="Graph X position")
    parser.add_argument('--graph_y', type=int, default=150, help="Graph Y position")
    parser.add_argument('--graph_width', type=int, default=DEFAULT_GRAPH_WIDTH, help="Graph width")
    parser.add_argument('--graph_height', type=int, default=DEFAULT_GRAPH_HEIGHT, help="Graph height")
    parser.add_argument('--title', type=str, default="Link Score", help="Title of the graph")
    parser.add_argument('--item', type=int, default=16, help="Item of the graph")
    parser.add_argument('--min_value', type=int, default=1000, help="Min value for graph")
    parser.add_argument('--max_value', type=int, default=2000, help="Max value for graph")
    parser.add_argument('--threshold', type=int, default=1300, help="Threshold for color change")
    parser.add_argument('--direction', type=int, default=-1, help="Threshold direction")
    parser.add_argument('--background_opacity', type=float, default=0.5, help="Background opacity")
    parser.add_argument('--num_bars', type=int, default=DEFAULT_GRAPH_BARS, help="Number of bars")

    args = parser.parse_args()

    # Load data from CSV
    timestamps, timestamp_strings, data = read_csv(args.csv_file, args.item)

    # Initialize the OSD window with the command-line arguments
    app = QApplication(sys.argv)
    window = OSDWindow(
        timestamps, timestamp_strings, data,
        graph_x=args.graph_x, graph_y=args.graph_y, graph_width=args.graph_width, graph_height=args.graph_height,
        title=args.title, min_value=args.min_value, max_value=args.max_value, threshold=args.threshold, direction=args.direction,
        background_opacity=args.background_opacity, num_bars=args.num_bars
    )
    window.show()
    sys.exit(app.exec_())
