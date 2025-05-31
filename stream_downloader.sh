#!/usr/bin/env bash

# Master script to extract and download streams
# Usage: ./stream_downloader.sh -u <website_url> -c <cookie_file> [-o <output_filename>]

# Function to display usage information
show_usage() {
    echo "Usage: $0 -u <website_url> [-c <cookie_file> | -b <browser>] [-o <output_filename>] [-w]"
    echo "Options:"
    echo "  -u <url>     Website URL containing the streams"
    echo "  -c <file>    Cookie file (exported from browser)"
    echo "  -b <browser> Browser to use for cookie extraction (chrome, firefox, edge, safari)"
    echo "  -p <profile> Browser profile to use (default: use the default profile)"
    echo "  -o <file>    Output filename (default: output.mp4)"
    echo "  -w           Use OpenAI Whisper to generate subtitles if none found"
    echo "  -h           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -u https://example.com/video -b chrome -o video.mp4"
    echo "  $0 -u https://example.com/video -b firefox -p default -w"
}

# Initialize variables
website_url=""
cookie_file=""
browser=""
profile=""
output_file="output.mp4"
use_whisper=""

# Process command line arguments
while getopts "u:c:b:p:o:wh" opt; do
    case ${opt} in
        u )
            website_url="$OPTARG"
            ;;
        c )
            cookie_file="$OPTARG"
            ;;
        b )
            browser="$OPTARG"
            ;;
        p )
            profile="$OPTARG"
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

# If neither cookie file nor browser is provided, ask for one
if [[ -z "$cookie_file" && -z "$browser" ]]; then
    echo "Cookie source not specified. Choose an option:"
    echo "1. Use a cookie file"
    echo "2. Extract cookies from browser"
    read -p "Enter choice (1/2): " cookie_choice
    
    if [[ "$cookie_choice" == "1" ]]; then
        read -p "Enter path to cookie file: " cookie_file
        if [[ ! -f "$cookie_file" ]]; then
            echo "Error: Cookie file not found: $cookie_file"
            exit 1
        fi
    elif [[ "$cookie_choice" == "2" ]]; then
        echo "Available browsers:"
        echo "1. Chrome"
        echo "2. Firefox"
        echo "3. Edge"
        echo "4. Safari"
        read -p "Enter browser choice (1-4): " browser_choice
        
        case "$browser_choice" in
            1) browser="chrome" ;;
            2) browser="firefox" ;;
            3) browser="edge" ;;
            4) browser="safari" ;;
            *) echo "Invalid choice"; exit 1 ;;
        esac
        
        read -p "Enter browser profile (leave empty for default): " profile
    else
        echo "Invalid choice"
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

# Build extract_streams.sh command
extract_cmd="./extract_streams.sh -u \"$website_url\" -o \"$temp_streams\""
if [[ -n "$cookie_file" ]]; then
    extract_cmd+=" -c \"$cookie_file\""
elif [[ -n "$browser" ]]; then
    extract_cmd+=" -b \"$browser\""
    if [[ -n "$profile" ]]; then
        extract_cmd+=" -p \"$profile\""
    fi
fi

# Execute the command
eval $extract_cmd

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
