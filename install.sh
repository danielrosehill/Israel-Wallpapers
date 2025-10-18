#!/bin/bash

# Israel Wallpapers Installation Script
# This script helps you install wallpapers to your preferred location

set -e

# Color codes for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Israel Wallpapers Installation       ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo ""

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGES_DIR="$SCRIPT_DIR/images"

# Check if images directory exists
if [ ! -d "$IMAGES_DIR" ]; then
    echo -e "${YELLOW}Warning: images directory not found at $IMAGES_DIR${NC}"
    echo "Please ensure the repository has been properly cloned with the images directory."
    exit 1
fi

# Check if Git LFS is installed
if ! command -v git-lfs &> /dev/null; then
    echo -e "${YELLOW}Warning: Git LFS is not installed.${NC}"
    echo "This repository uses Git LFS to store image files."
    echo ""
    echo "Please install Git LFS first:"
    echo "  Ubuntu/Debian: sudo apt-get install git-lfs"
    echo "  Other systems: https://git-lfs.github.com/"
    echo ""
    read -p "Do you want to continue anyway? [y/N]: " continue_anyway
    continue_anyway=${continue_anyway:-N}
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if we need to pull LFS files
# Look for LFS pointer files (they're very small, < 200 bytes)
sample_image=$(find "$IMAGES_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print -quit)
if [ -n "$sample_image" ]; then
    file_size=$(stat -f%z "$sample_image" 2>/dev/null || stat -c%s "$sample_image" 2>/dev/null)
    if [ "$file_size" -lt 200 ]; then
        echo -e "${BLUE}Detecting LFS pointer files. Pulling actual images from Git LFS...${NC}"
        echo ""
        if git lfs pull; then
            echo -e "${GREEN}✓ Successfully pulled image files from Git LFS${NC}"
            echo ""
        else
            echo -e "${YELLOW}Warning: Failed to pull files from Git LFS.${NC}"
            echo "The installation may not work correctly."
            echo ""
            read -p "Do you want to continue anyway? [y/N]: " continue_anyway
            continue_anyway=${continue_anyway:-N}
            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
fi

# Function to get image dimensions
get_image_dimensions() {
    local img="$1"
    identify -format "%w %h" "$img" 2>/dev/null || echo "0 0"
}

# Function to determine orientation
get_orientation() {
    local img="$1"
    read -r width height <<< $(get_image_dimensions "$img")

    if [ "$width" -eq 0 ] || [ "$height" -eq 0 ]; then
        echo "unknown"
        return
    fi

    local aspect_ratio=$(echo "scale=2; $width / $height" | bc)
    local portrait_ratio=$(echo "scale=2; 9 / 16" | bc)
    local landscape_ratio=$(echo "scale=2; 16 / 9" | bc)

    # Check if it's close to 9:16 (portrait)
    if (( $(echo "$aspect_ratio >= 0.50 && $aspect_ratio <= 0.60" | bc -l) )); then
        echo "portrait"
    # Check if it's close to 16:9 (landscape)
    elif (( $(echo "$aspect_ratio >= 1.70 && $aspect_ratio <= 1.80" | bc -l) )); then
        echo "landscape"
    else
        echo "other"
    fi
}

# Ask for destination directory
echo -e "${GREEN}Where would you like to install the wallpapers?${NC}"
echo "1) ~/wallpapers (default)"
echo "2) Custom directory"
read -p "Enter your choice [1-2] (default: 1): " dir_choice
dir_choice=${dir_choice:-1}

case $dir_choice in
    1)
        DEST_DIR="$HOME/wallpapers"
        ;;
    2)
        read -p "Enter custom directory path: " custom_dir
        DEST_DIR="${custom_dir/#\~/$HOME}"
        ;;
    *)
        echo -e "${YELLOW}Invalid choice. Using default: ~/wallpapers${NC}"
        DEST_DIR="$HOME/wallpapers"
        ;;
esac

# Create destination directory if it doesn't exist
if [ ! -d "$DEST_DIR" ]; then
    echo -e "${GREEN}Creating directory: $DEST_DIR${NC}"
    mkdir -p "$DEST_DIR"
else
    echo -e "${BLUE}Directory already exists: $DEST_DIR${NC}"
fi

echo ""

# Ask about folder structure
echo -e "${GREEN}How would you like to organize the wallpapers?${NC}"
echo "1) Preserve folder structure (keep subdirectories)"
echo "2) Flat structure (copy all images to one directory)"
read -p "Enter your choice [1-2] (default: 1): " structure_choice
structure_choice=${structure_choice:-1}

echo ""

# Ask about orientation filter
echo -e "${GREEN}Which wallpapers would you like to install?${NC}"
echo "1) All images"
echo "2) Portrait only (9:16 aspect ratio)"
echo "3) Landscape only (16:9 aspect ratio)"
read -p "Enter your choice [1-3] (default: 1): " filter_choice
filter_choice=${filter_choice:-1}

echo ""
echo -e "${BLUE}Starting installation...${NC}"
echo ""

# Check if imagemagick is installed (needed for orientation detection)
if ! command -v identify &> /dev/null && [ "$filter_choice" != "1" ]; then
    echo -e "${YELLOW}Warning: ImageMagick not found. Installing for orientation detection...${NC}"
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y imagemagick
    else
        echo -e "${YELLOW}Please install ImageMagick manually to filter by orientation.${NC}"
        echo "Proceeding with all images..."
        filter_choice=1
    fi
fi

# Counter for copied files
copied_count=0
skipped_count=0

# Copy files based on user preferences
while IFS= read -r -d '' img; do
    # Get relative path from images directory
    rel_path="${img#$IMAGES_DIR/}"

    # Check orientation filter
    if [ "$filter_choice" != "1" ]; then
        orientation=$(get_orientation "$img")

        if [ "$filter_choice" == "2" ] && [ "$orientation" != "portrait" ]; then
            ((skipped_count++))
            continue
        elif [ "$filter_choice" == "3" ] && [ "$orientation" != "landscape" ]; then
            ((skipped_count++))
            continue
        fi
    fi

    # Determine destination based on structure choice
    if [ "$structure_choice" == "1" ]; then
        # Preserve structure
        dest_file="$DEST_DIR/$rel_path"
        dest_subdir=$(dirname "$dest_file")
        mkdir -p "$dest_subdir"
    else
        # Flat structure
        filename=$(basename "$img")
        dest_file="$DEST_DIR/$filename"
    fi

    # Copy the file
    cp "$img" "$dest_file"
    echo -e "  ${GREEN}✓${NC} Copied: $rel_path"
    ((copied_count++))

done < <(find "$IMAGES_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" -o -iname "*.tiff" \) -print0)

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Installation Complete!                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Summary:${NC}"
echo -e "  Copied: $copied_count images"
echo -e "  Skipped: $skipped_count images"
echo -e "  Destination: $DEST_DIR"
echo ""
echo -e "${BLUE}Enjoy your Israel wallpapers!${NC}"
