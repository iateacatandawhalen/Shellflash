#!/bin/bash

# Function to list USB drives with manufacturer information and assign numbers
list_drives() {
    echo "Available USB drives:"
    counter=1
    drives=()
    lsusb | grep -i "Mass Storage" | while read -r line; do
        # Extract vendor, product, and device path
        vendor_id=$(echo "$line" | awk '{print $6}' | cut -d: -f1)
        product_id=$(echo "$line" | awk '{print $6}' | cut -d: -f2)
        drive_path=$(lsblk -dpn | grep -i "/dev/sd" | grep "$vendor_id" | grep "$product_id" | awk '{print $1}')
        size=$(lsblk -dpn | grep -i "$drive_path" | awk '{print $4}')
        
        # Only show drives with size between 1GB and 128GB
        size_in_gb=$(echo "$size" | sed 's/[^0-9]*//g')
        if [ "$size_in_gb" -ge 1 ] && [ "$size_in_gb" -le 128 ]; then
            manufacturer=$(echo "$line" | awk -F' ' '{print $3, $4, $5}')
            drives+=("$counter|$drive_path|$manufacturer|$size")
            echo "$counter) $manufacturer - $size"
            counter=$((counter + 1))
        fi
    done
}

# Function to confirm the selected drive and continue the flash if "y"
confirm_drive() {
    echo "You selected: $1"
    read -p "Are you sure you want to flash this drive? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        echo "Proceeding with flashing..."
    else
        echo "Aborted!"
        exit 1
    fi
}

# Ask for the name of the ISO file (without the .iso extension)
read -p "Enter the name of the ISO file (without the .iso extension): " iso_name

# Search for the matching ISO file in the current directory
iso_file=$(find . -maxdepth 1 -type f -iname "$iso_name.iso" | head -n 1)

if [ -z "$iso_file" ]; then
    echo "No matching ISO file found for $iso_name.iso."
    exit 1
fi

echo "Found ISO file: $iso_file"

# List drives and ask for the target drive
list_drives

# Ask user to select a drive by number
read -p "Enter the number of the USB drive you want to flash: " selection

# Find the selected drive path from the list
selected_drive=""
for drive in "${drives[@]}"; do
    drive_number=$(echo "$drive" | cut -d'|' -f1)
    if [ "$drive_number" -eq "$selection" ]; then
        selected_drive=$(echo "$drive" | cut -d'|' -f2)
        break
    fi
done

if [ -z "$selected_drive" ]; then
    echo "Invalid selection."
    exit 1
fi

# Confirm the selected drive
confirm_drive "$selected_drive"

# Flash the ISO to the USB drive
echo "Flashing $iso_file to $selected_drive..."
sudo dd if="$iso_file" of="$selected_drive" bs=4M status=progress && sync

echo "Done!"
