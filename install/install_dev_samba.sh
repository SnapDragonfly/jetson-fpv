#!/bin/bash

# Check if there are exactly two arguments (username and password)
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

# Assign arguments to variables
username=$1
password=$2

# Step 1: Install Samba package
echo "Installing Samba..."
sudo apt-get install -y samba

# Step 2: Add user to Samba and set the password
echo "Adding user to Samba..."
echo -e "$password\n$password" | sudo smbpasswd -a "$username"

# Backup file name
backup_file="/etc/samba/smb.conf"
backup_dir="/etc/samba"
bak_prefix="smb.conf.bak"
bak_suffix=0

# Check if the backup file already exists
while [ -f "$backup_dir/$bak_prefix$bak_suffix" ]; do
    bak_suffix=$((bak_suffix + 1))
done

# Step 3: Create the backup with the incremented name
sudo cp "$backup_file" "$backup_dir/$bak_prefix$bak_suffix"
echo "Backup created as: $backup_dir/$bak_prefix$bak_suffix"

# Step 4: Modify the smb.conf file (using sed instead of nano)
echo "Modifying /etc/samba/smb.conf..."

# 4.1: Add lines under the [global] section
sudo sed -i '/^\[global\]/a \
   follow symlinks = yes\n\
   wide links = yes\n\
   unix extensions = no\n' /etc/samba/smb.conf

# 4.2: Uncomment and modify lines in the [homes] section (if they exist)

# Uncomment the [homes] section if it's commented
sudo sed -i '/^\;\[homes\]/c\[homes\]' /etc/samba/smb.conf

# Uncomment specific lines in the [homes] section and modify them
sudo sed -i '/^\[homes\]/,/^\;\[.*\]\|\[.*\]/s/^\;\s*comment\s*=\s*Home Directories/comment = Home Directories/' /etc/samba/smb.conf
sudo sed -i '/^\[homes\]/,/^\;\[.*\]\|\[.*\]/s/^\;\s*browseable\s*=\s*no/browseable = no/' /etc/samba/smb.conf
sudo sed -i '/^\[homes\]/,/^\;\[.*\]\|\[.*\]/s/^\;\s*read only\s*=\s*yes/read only = no/' /etc/samba/smb.conf
sudo sed -i '/^\[homes\]/,/^\;\[.*\]\|\[.*\]/s/^\;\s*create mask\s*=\s*0700/create mask = 0700/' /etc/samba/smb.conf
sudo sed -i '/^\[homes\]/,/^\;\[.*\]\|\[.*\]/s/^\;\s*directory mask\s*=\s*0700/directory mask = 0700/' /etc/samba/smb.conf
sudo sed -i '/^\[homes\]/,/^\;\[.*\]\|\[.*\]/s/^\;\s*valid users\s*=\s*%S/valid users = %S/' /etc/samba/smb.conf

# Step 5: Restart the Samba service to apply changes
echo "Restarting Samba service..."
sudo service smbd restart

echo "Script completed successfully."

