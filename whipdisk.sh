#!/bin/bash

# Function to check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        whiptail --msgbox "This script must be run as root. Use sudo." 10 60
        exit 1
    fi
}

# Function to select a disk
select_disk() {
    local disks
    disks=$(lsblk -dn -o NAME,SIZE | awk '{print "/dev/" $1 " (" $2 ")"}')
    local disk
    disk=$(whiptail --title "Select Disk" --menu "Choose a disk to manage:" 20 60 10 ${disks} 3>&1 1>&2 2>&3)
    echo "$disk"
}

# Function to manage partitions
manage_partitions() {
    local disk=$1
    while true; do
        local choice
        choice=$(whiptail --title "Manage Partitions on $disk" --menu "Choose an action:" 20 60 10 \
            "1" "View partitions" \
            "2" "Create a new partition" \
            "3" "Delete a partition" \
            "4" "Write changes to disk" \
            "5" "Exit" 3>&1 1>&2 2>&3)
        case $choice in
            1)
                view_partitions "$disk"
                ;;
            2)
                create_partition "$disk"
                ;;
            3)
                delete_partition "$disk"
                ;;
            4)
                write_changes "$disk"
                ;;
            5)
                break
                ;;
            *)
                whiptail --msgbox "Invalid choice!" 10 60
                ;;
        esac
    done
}

# Function to view partitions
view_partitions() {
    local disk=$1
    local output
    output=$(fdisk -l "$disk")
    whiptail --title "Partitions on $disk" --msgbox "$output" 20 80
}

# Function to create a partition
create_partition() {
    local disk=$1
    local partition_type
    local size
    local free_space

    # Get available free space on the disk
    free_space=$(lsblk -dn -o NAME,FREE | grep "^$(basename "$disk")" | awk '{print $2}')
    if [[ -z "$free_space" ]]; then
        free_space="Unknown"
    fi

    partition_type=$(whiptail --title "Partition Type" --menu "Choose the partition type:" 15 60 2 \
        "p" "Primary" \
        "e" "Extended" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    size=$(whiptail --inputbox "Enter the partition size (e.g., +500M or +1G). Leave empty to use all remaining space ($free_space):" 10 60 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
        return
    fi

    (
        echo n     # Add new partition
        echo "$partition_type"  # Partition type
        echo        # Default partition number
        echo        # Default start
        echo "$size" # End size (leave empty for all remaining space)
        echo w     # Write changes
    ) | fdisk "$disk" > /dev/null 2>&1

    whiptail --msgbox "Partition created successfully on $disk." 10 60
}

# Function to delete a partition
delete_partition() {
    local disk=$1
    local partitions
    local choice

    # Get list of partitions on the disk
    partitions=$(lsblk -ln -o NAME,SIZE | grep "^$(basename "$disk")" | awk '{print $1 " " $2}')

    if [[ -z "$partitions" ]]; then
        whiptail --msgbox "No partitions available to delete on $disk." 10 60
        return
    fi

    # Build menu items with properly formatted details
    menu_items=()
    while read -r line; do
        partition_name=$(echo "$line" | awk '{print $1}')
        partition_size=$(echo "$line" | awk '{print $2}')
        partition_number=$(echo "$partition_name" | sed "s/^$(basename "$disk")//")
        menu_items+=("$partition_number" "Partition: $partition_name | Size: $partition_size")
    done <<< "$partitions"

    choice=$(whiptail --title "Delete Partition" --menu "Choose a partition to delete:" 20 60 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || -z "$choice" ]]; then
        return
    fi

    # Confirm deletion
    if ! whiptail --yesno "Are you sure you want to delete partition $choice on $disk?" 10 60; then
        return
    fi

    (
        echo d     # Delete partition
        echo "$choice" # Partition number
        echo w     # Write changes
    ) | fdisk "$disk" > /dev/null 2>&1

    whiptail --msgbox "Partition $choice deleted successfully on $disk." 10 60
}

# Function to write changes to disk
write_changes() {
    local disk=$1
    (
        echo w     # Write changes
    ) | fdisk "$disk" > /dev/null 2>&1

    whiptail --msgbox "Changes written to $disk successfully." 10 60
}

# Main function
main() {
    check_root
    local disk
    disk=$(select_disk)
    if [[ -n "$disk" ]]; then
        manage_partitions "$disk"
    else
        whiptail --msgbox "No disk selected. Exiting." 10 60
    fi
}

# Run the script
main