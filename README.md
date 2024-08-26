# My Awesome Script
This script is designed to manage LVM partitions on an Arch Linux system. It allows you to safely resize partitions, view disk usage, and identify the largest directories within each logical volume.

## Features

1. Display current logical volume usage and largest directories
2. Shrink and extend logical volumes safely
3. Interactive selection of volumes using fzf
Dependencies

Make sure the following packages are installed on your system:

```bash
sudo pacman -Syu lsof e2fsprogs fzf
```

**Usage**

```bash
sudo pacman -Syu lsof e2fsprogs fzf
```

```bash
sudo ./my-awesome-script.sh
```

*Note:* It's recommended to run this script in a chroot environment if modifying critical system partitions.

### License

MIT License