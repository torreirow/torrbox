#!/usr/bin/env bash

# Master script to extract and download streams
# Usage: ./stream_downloader.sh -u <website_url> -c <cookie_file> [-o <output_filename>]

# Function to display usage information
show_usage() {
    echo "Usage: $0 -u <website_url> -c <cookie_file> [-o <output_filename>] [-w]"
    echo "Options:"
    echo "  -u <url>     Website URL containing the streams"
    echo "  -c <file>    Cookie file (exported from browser)"
    echo "  -o <file>    Output filename (default: output.mp4)"
    echo "  -w           Use OpenAI Whisper to generate subtitles if none found"
    echo "  -h           Show this help message"
}

# Initialize variables
website_url=""
cookie_file=""
output_file="output.mp4"
use_whisper=""

# Process command line arguments
while getopts "u:c:o:wh" opt; do
    case ${opt} in
        u )
            website_url="$OPTARG"
            ;;
        c )
            cookie_file="$OPTARG"
            ;;
        o )
            output_file="$OPTARG"
            ;;
        w )
            use_whisper="-w"
            ;;
        h )
            show_usage
            exit 0
            ;;
        \? )
            echo "Invalid option: $OPTARG" 1>&2
            show_usage
            exit 1
            ;;
        : )
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            show_usage
            exit 1
            ;;
    esac
done

# Check if extract_streams.sh and download_stream.sh exist
if [[ ! -f "./extract_streams.sh" ]]; then
    echo "Error: extract_streams.sh not found in current directory"
    exit 1
fi

if [[ ! -f "./download_stream.sh" ]]; then
    echo "Error: download_stream.sh not found in current directory"
    exit 1
fi

# Make sure the scripts are executable
chmod +x ./extract_streams.sh
chmod +x ./download_stream.sh

# If website URL is not provided, ask for it
if [[ -z "$website_url" ]]; then
    read -p "Enter website URL: " website_url
    if [[ -z "$website_url" ]]; then
        echo "Error: Website URL is required"
        exit 1
    fi
fi

# If cookie file is not provided, ask for it
if [[ -z "$cookie_file" ]]; then
    read -p "Enter path to cookie file: " cookie_file
    if [[ ! -f "$cookie_file" ]]; then
        echo "Error: Cookie file not found: $cookie_file"
        exit 1
    fi
fi

# Create temporary directory with unique name
temp_dir=$(mktemp -d)
echo "Created temporary directory: $temp_dir"

# Trap to ensure cleanup on exit
trap 'echo "Cleaning up temporary files..."; rm -rf "$temp_dir"' EXIT

# Extract stream URLs
echo "Extracting stream URLs from website..."
temp_streams="$temp_dir/streams.txt"
./extract_streams.sh -u "$website_url" -c "$cookie_file" -o "$temp_streams"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to extract stream URLs"
    exit 1
fi

# Source the extracted URLs
source "$temp_streams"

# Download and combine streams
echo "Downloading and combining streams..."
./download_stream.sh -v "$VIDEO_URL" -a "$AUDIO_URL" -s "$SUBTITLE_URL" -o "$output_file" $use_whisper

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download and combine streams"
    exit 1
fi

echo "Successfully created: $output_file"
