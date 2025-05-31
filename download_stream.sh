#!/usr/bin/env bash

# Script to download video, audio, and subtitle streams and combine them using ffmpeg
# Usage: ./download_stream.sh -v video_url -a audio_url -s subtitle_url -o output_filename

# Function to display usage information
show_usage() {
    echo "Usage: $0 -v <video_url> -a <audio_url> -s <subtitle_url> -o <output_filename>"
    echo "Options:"
    echo "  -v <url>    Video stream URL"
    echo "  -a <url>    Audio stream URL"
    echo "  -s <url>    Subtitle stream URL"
    echo "  -o <file>   Output filename"
    echo "  -h          Show this help message"
    echo "If parameters are not provided, you will be prompted for them."
}

# Function to check if ffmpeg is installed
check_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg is not installed. Please install it first."
        exit 1
    fi
}

# Function to validate URL
validate_url() {
    if [[ -z "$1" ]]; then
        return 1
    fi
    
    # Basic URL validation
    if [[ ! "$1" =~ ^https?:// ]]; then
        echo "Warning: URL '$1' doesn't start with http:// or https://"
        read -p "Continue anyway? (y/n): " confirm
        [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]] || return 1
    fi
    
    return 0
}

# Check for ffmpeg
check_ffmpeg

# Initialize variables
video_url=""
audio_url=""
subtitle_url=""
output_file=""

# Process command line arguments
while getopts "v:a:s:o:h" opt; do
    case ${opt} in
        v )
            video_url="$OPTARG"
            ;;
        a )
            audio_url="$OPTARG"
            ;;
        s )
            subtitle_url="$OPTARG"
            ;;
        o )
            output_file="$OPTARG"
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

# If video URL is not provided, ask for it
if [[ -z "$video_url" ]]; then
    read -p "Enter video stream URL: " video_url
    if ! validate_url "$video_url"; then
        echo "Error: Invalid video URL"
        exit 1
    fi
fi

# If audio URL is not provided, ask for it
if [[ -z "$audio_url" ]]; then
    read -p "Enter audio stream URL (leave empty if not available): " audio_url
    if [[ -n "$audio_url" ]] && ! validate_url "$audio_url"; then
        echo "Error: Invalid audio URL"
        exit 1
    fi
fi

# If subtitle URL is not provided, ask for it
if [[ -z "$subtitle_url" ]]; then
    read -p "Enter subtitle stream URL (leave empty if not available): " subtitle_url
    if [[ -n "$subtitle_url" ]] && ! validate_url "$subtitle_url"; then
        echo "Error: Invalid subtitle URL"
        exit 1
    fi
fi

# If output filename is not provided, ask for it
if [[ -z "$output_file" ]]; then
    read -p "Enter output filename (e.g., output.mp4): " output_file
    if [[ -z "$output_file" ]]; then
        output_file="output.mp4"
        echo "Using default output filename: $output_file"
    fi
fi

# Create temporary directory with unique name
temp_dir=$(mktemp -d)
echo "Created temporary directory: $temp_dir"

# Trap to ensure cleanup on exit
trap 'echo "Cleaning up temporary files..."; rm -rf "$temp_dir"' EXIT

# Download video stream
echo "Downloading video stream..."
video_file="$temp_dir/video_$(date +%s%N).mp4"
ffmpeg -y -i "$video_url" -c copy "$video_file"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download video stream"
    exit 1
fi

# Download audio stream if provided
audio_file=""
if [[ -n "$audio_url" ]]; then
    echo "Downloading audio stream..."
    audio_file="$temp_dir/audio_$(date +%s%N).aac"
    ffmpeg -y -i "$audio_url" -c copy "$audio_file"
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to download audio stream"
        exit 1
    fi
fi

# Download subtitle stream if provided
subtitle_file=""
if [[ -n "$subtitle_url" ]]; then
    echo "Downloading subtitle stream..."
    subtitle_file="$temp_dir/subtitle_$(date +%s%N).srt"
    ffmpeg -y -i "$subtitle_url" "$subtitle_file"
    
    if [[ $? -ne 0 ]]; then
        echo "Warning: Failed to download subtitle stream, continuing without subtitles"
        subtitle_file=""
    fi
fi

# Combine streams
echo "Combining streams..."

# Build ffmpeg command based on available streams
ffmpeg_cmd="ffmpeg -y -i \"$video_file\""

if [[ -n "$audio_file" ]]; then
    ffmpeg_cmd+=" -i \"$audio_file\""
fi

if [[ -n "$subtitle_file" ]]; then
    ffmpeg_cmd+=" -i \"$subtitle_file\""
    ffmpeg_cmd+=" -vf \"subtitles=$subtitle_file:force_style='FontName=Arial Narrow Regular,FontSize=16'\""
    ffmpeg_cmd+=" -c:a copy"
else
    ffmpeg_cmd+=" -c copy"
fi

ffmpeg_cmd+=" -crf 18 -preset slow \"$output_file\""

# Execute the command
eval $ffmpeg_cmd

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to combine streams"
    exit 1
fi

echo "Successfully created: $output_file"
