#!/bin/bash

# Script to organize wallpapers into flat portrait/landscape directories
# Detects orientation based on actual image dimensions (aspect ratio)
# Ignores folder structure to avoid mislabeling issues
# Supports incremental runs with conflict resolution

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/flat"
PORTRAIT_DIR="${OUTPUT_DIR}/portrait"
LANDSCAPE_DIR="${OUTPUT_DIR}/landscape"

# Counters
portrait_count=0
landscape_count=0
skipped_count=0
error_count=0

# Create output directories
mkdir -p "${PORTRAIT_DIR}" "${LANDSCAPE_DIR}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Wallpaper Organization Script${NC}"
echo -e "${BLUE}(Aspect Ratio Detection)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if ImageMagick is installed
check_imagemagick() {
    if ! command -v identify &> /dev/null; then
        echo -e "${YELLOW}ImageMagick not found. Installing...${NC}"
        sudo apt-get update -qq
        sudo apt-get install -y imagemagick
    fi
}

# Function to get image dimensions
get_dimensions() {
    local file="$1"
    identify -format "%w %h" "$file" 2>/dev/null || echo "0 0"
}

# Function to determine orientation based on aspect ratio
get_orientation() {
    local file="$1"
    read -r width height <<< "$(get_dimensions "$file")"

    if [ "$width" -eq 0 ] || [ "$height" -eq 0 ]; then
        echo "unknown"
        return 1
    fi

    # Portrait: height > width
    # Landscape: width >= height
    if [ "$height" -gt "$width" ]; then
        echo "portrait"
    else
        echo "landscape"
    fi
}

# Function to generate unique filename
get_unique_filename() {
    local dest_dir="$1"
    local filename="$2"
    local base="${filename%.*}"
    local ext="${filename##*.}"
    local counter=1
    local new_filename="$filename"

    while [ -f "${dest_dir}/${new_filename}" ]; do
        new_filename="${base}_${counter}.${ext}"
        ((counter++))
    done

    echo "$new_filename"
}

# Function to copy file to appropriate directory
copy_file() {
    local source="$1"
    local orientation="$2"
    local width="$3"
    local height="$4"
    local filename="$(basename "$source")"
    local dest_dir

    if [ "$orientation" = "portrait" ]; then
        dest_dir="$PORTRAIT_DIR"
    elif [ "$orientation" = "landscape" ]; then
        dest_dir="$LANDSCAPE_DIR"
    else
        echo -e "${RED}Error: Unknown orientation for $filename${NC}"
        error_count=$((error_count + 1))
        return 1
    fi

    # Check if file already exists with same content
    local unique_filename="$(get_unique_filename "$dest_dir" "$filename")"
    local dest_path="${dest_dir}/${unique_filename}"

    # If the exact file already exists (same content), skip
    if [ -f "$dest_path" ] && cmp -s "$source" "$dest_path"; then
        echo -e "${YELLOW}⊘${NC} Skipped (duplicate): $filename"
        skipped_count=$((skipped_count + 1))
        return 0
    fi

    # Copy the file
    cp "$source" "$dest_path"

    if [ "$orientation" = "portrait" ]; then
        echo -e "${GREEN}📱${NC} Portrait  [${width}x${height}]: $filename → $unique_filename"
        portrait_count=$((portrait_count + 1))
    else
        echo -e "${GREEN}🖼️ ${NC} Landscape [${width}x${height}]: $filename → $unique_filename"
        landscape_count=$((landscape_count + 1))
    fi
}

# Function to process all images in source directories
process_all_images() {
    local total_files=0

    echo -e "${BLUE}Scanning for images...${NC}"

    # Process originals directory
    if [ -d "${SCRIPT_DIR}/originals" ]; then
        echo -e "${YELLOW}Processing: originals/${NC}"
        find "${SCRIPT_DIR}/originals" -type f \( \
            -iname "*.jpg" -o \
            -iname "*.jpeg" -o \
            -iname "*.png" -o \
            -iname "*.gif" -o \
            -iname "*.bmp" -o \
            -iname "*.webp" -o \
            -iname "*.tiff" \
        \) | while read -r file; do
            # Get dimensions and orientation
            read -r width height <<< "$(get_dimensions "$file")"

            if [ "$width" -eq 0 ] || [ "$height" -eq 0 ]; then
                echo -e "${RED}Error: Could not read dimensions for $(basename "$file")${NC}"
                error_count=$((error_count + 1))
                continue
            fi

            orientation="$(get_orientation "$file")"
            if [ $? -eq 0 ]; then
                copy_file "$file" "$orientation" "$width" "$height"
            else
                echo -e "${RED}Error processing: $(basename "$file")${NC}"
                error_count=$((error_count + 1))
            fi
        done
    fi

    # Process ai-gen directory
    if [ -d "${SCRIPT_DIR}/ai-gen" ]; then
        echo -e "${YELLOW}Processing: ai-gen/${NC}"
        find "${SCRIPT_DIR}/ai-gen" -type f \( \
            -iname "*.jpg" -o \
            -iname "*.jpeg" -o \
            -iname "*.png" -o \
            -iname "*.gif" -o \
            -iname "*.bmp" -o \
            -iname "*.webp" -o \
            -iname "*.tiff" \
        \) | while read -r file; do
            # Get dimensions and orientation
            read -r width height <<< "$(get_dimensions "$file")"

            if [ "$width" -eq 0 ] || [ "$height" -eq 0 ]; then
                echo -e "${RED}Error: Could not read dimensions for $(basename "$file")${NC}"
                error_count=$((error_count + 1))
                continue
            fi

            orientation="$(get_orientation "$file")"
            if [ $? -eq 0 ]; then
                copy_file "$file" "$orientation" "$width" "$height"
            else
                echo -e "${RED}Error processing: $(basename "$file")${NC}"
                error_count=$((error_count + 1))
            fi
        done
    fi
}

# Main execution
echo -e "${BLUE}Checking dependencies...${NC}"
check_imagemagick
echo ""

echo -e "${BLUE}Processing all images by detected aspect ratio...${NC}"
echo -e "${BLUE}(Ignoring folder structure)${NC}"
echo ""

process_all_images

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Portrait images copied:${NC}  $portrait_count"
echo -e "${GREEN}Landscape images copied:${NC} $landscape_count"
echo -e "${YELLOW}Skipped (duplicates):${NC}    $skipped_count"
echo -e "${RED}Errors:${NC}                   $error_count"
echo ""
echo -e "${BLUE}Output directories:${NC}"
echo -e "  Portrait:  ${PORTRAIT_DIR}"
echo -e "  Landscape: ${LANDSCAPE_DIR}"
echo -e "${BLUE}========================================${NC}"
