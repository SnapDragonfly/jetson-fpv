import keyboard
import sys
import subprocess

# Get module name from command-line arguments
module_name = sys.argv[1] if len(sys.argv) > 1 else "Default Module"

# Print the module name
print(f"Module: {module_name}")
print("Press 'ESC' to exit the program.")

while True:
    if keyboard.is_pressed('esc'):
        print(f"ESC key pressed. {module_name} Exiting...")
        
        # Execute the Bash script
        command = f"sudo ./wrapper.sh {module_name} stop"
        try:
            result = subprocess.run(command, shell=True, check=True, text=True, capture_output=True)
            print(result.stdout)  # Print the output of the Bash script
        except subprocess.CalledProcessError as e:
            print(f"Error executing command: {e}")
            print(e.stderr)  # Print any error messages from the Bash script
        
        break
