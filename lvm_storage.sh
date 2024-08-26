#!/bin/bash

# Ensure fzf is installed
if ! command -v fzf &> /dev/null; then
    echo "fzf could not be found. Please install fzf to use this script."
    exit 1
fi

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Function to display current LV usage and largest directories
display_lv_usage() {
    echo "Logical Volume Space Usage:"
    echo "============================"
    LV_PATHS=$(lvs --noheadings -o lv_path)
    for LV_PATH in $LV_PATHS; do
        LV_NAME=$(basename "$LV_PATH")
        MOUNT_POINT=$(findmnt -nr -o TARGET -S "$LV_PATH")

        if [ -z "$MOUNT_POINT" ]; then
            echo "$LV_NAME is not mounted"
        else
            USAGE=$(df -h "$MOUNT_POINT" | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')
            echo "$LV_NAME ($MOUNT_POINT): $USAGE"
            echo "Largest directories in $MOUNT_POINT:"
            sudo du -ah "$MOUNT_POINT" 2>/dev/null | sort -rh | head -n 10
            echo "----------------------------"
        fi
    done
    echo "============================"
}

# Function to get logical volume selection using fzf
select_lv() {
    local prompt=$1
    local lv=$(lvs --noheadings -o lv_name,vg_name,lv_size | fzf --prompt="$prompt")
    echo $lv
}

# Function to shrink the selected logical volume and filesystem
shrink_lv() {
    local lv_name=$1
    local vg_name=$2
    local size=$3
    local lv_path="/dev/${vg_name}/${lv_name}"

    echo "Attempting to shrink logical volume ${lv_path} by ${size}GiB..."

    if lsof | grep $lv_path; then
        echo "Filesystem is busy. Trying to resize online if supported..."
        if resize2fs -M $lv_path; then
            lvreduce -L -${size}G $lv_path -y
            resize2fs $lv_path
        else
            echo "Online resize not supported or failed. Please ensure the filesystem is not in use."
            exit 1
        fi
    else
        umount $lv_path
        e2fsck -f $lv_path
        resize2fs $lv_path $(($(blockdev --getsize64 $lv_path) / 1024 / 1024 / 1024 - size))G
        lvreduce -L -${size}G $lv_path -y
        mount $lv_path
    fi
}

# Function to extend the selected logical volume and filesystem
extend_lv() {
    local lv_name=$1
    local vg_name=$2
    local size=$3
    local lv_path="/dev/${vg_name}/${lv_name}"

    echo "Extending logical volume ${lv_path} by ${size}GiB..."
    lvextend -L +${size}G $lv_path -r -y
}

# Display current usage
display_lv_usage

# Prompt the user if they want to make any changes
read -p "Do you want to make any changes to the logical volumes? (y/n): " RESPONSE
if [[ "$RESPONSE" != "y" ]]; then
    echo "No changes made. Exiting."
    exit 0
fi

# Select logical volume to shrink
SHRINK_LV=$(select_lv "Select the LV to shrink: ")
if [ -z "$SHRINK_LV" ]; then
    echo "No LV selected. Exiting."
    exit 1
fi
SHRINK_LV_NAME=$(echo $SHRINK_LV | awk '{print $1}')
SHRINK_VG_NAME=$(echo $SHRINK_LV | awk '{print $2}')

# Prompt for the size to shrink
read -p "Enter the size to shrink in GiB: " SHRINK_SIZE

# Select logical volume to extend
EXTEND_LV=$(select_lv "Select the LV to extend: ")
if [ -z "$EXTEND_LV" ]; then
    echo "No LV selected. Exiting."
    exit 1
fi
EXTEND_LV_NAME=$(echo $EXTEND_LV | awk '{print $1}')
EXTEND_VG_NAME=$(echo $EXTEND_LV | awk '{print $2}')

# Perform the resize operations
shrink_lv $SHRINK_LV_NAME $SHRINK_VG_NAME $SHRINK_SIZE
extend_lv $EXTEND_LV_NAME $EXTEND_VG_NAME $SHRINK_SIZE

echo "Resize operations completed successfully."

