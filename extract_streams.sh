#!/usr/bin/env bash

# Script to extract video, audio, and subtitle stream URLs from a website using browser cookies
# Usage: ./extract_streams.sh -u <website_url> -c <cookie_file> [-b <browser>]

# Function to display usage information
show_usage() {
    echo "Usage: $0 -u <website_url> -c <cookie_file> [-b <browser>] [-o <output_file>]"
    echo "Options:"
    echo "  -u <url>      Website URL containing the streams"
    echo "  -c <file>     Cookie file (exported from browser)"
    echo "  -b <browser>  Browser to use for cookie extraction (chrome, firefox, edge, safari)"
    echo "                If not specified, will try to detect from cookie file"
    echo "  -o <file>     Output file to save stream URLs (default: streams.txt)"
    echo "  -h            Show this help message"
}

# Function to check if required tools are installed
check_requirements() {
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v grep &> /dev/null || ! command -v sed &> /dev/null; then
        echo "Error: grep and/or sed are not installed. Please install them first."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "Warning: jq is not installed. JSON parsing may be less reliable."
        echo "Consider installing jq for better results: https://stedolan.github.io/jq/download/"
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

# Function to extract cookies from browser
extract_cookies() {
    local browser="$1"
    local cookie_file="$2"
    local temp_cookies="$temp_dir/cookies.txt"
    
    case "$browser" in
        chrome|chromium)
            if command -v sqlite3 &> /dev/null; then
                echo "Extracting cookies from Chrome/Chromium..."
                # This is a simplified example - actual implementation would be more complex
                echo "Error: Direct Chrome cookie extraction not implemented."
                echo "Please export cookies manually using a browser extension."
                exit 1
            else
                echo "Error: sqlite3 is required to extract Chrome cookies."
                exit 1
            fi
            ;;
        firefox)
            if command -v sqlite3 &> /dev/null; then
                echo "Extracting cookies from Firefox..."
                echo "Error: Direct Firefox cookie extraction not implemented."
                echo "Please export cookies manually using a browser extension."
                exit 1
            else
                echo "Error: sqlite3 is required to extract Firefox cookies."
                exit 1
            fi
            ;;
        *)
            # If browser not specified or not supported, assume cookie file is already in correct format
            if [[ -f "$cookie_file" ]]; then
                cp "$cookie_file" "$temp_cookies"
                return 0
            else
                echo "Error: Cookie file not found: $cookie_file"
                exit 1
            fi
            ;;
    esac
}

# Function to extract stream URLs from a webpage
extract_stream_urls() {
    local url="$1"
    local cookie_file="$2"
    local output_file="$3"
    local temp_html="$temp_dir/page.html"
    local video_url=""
    local audio_url=""
    local subtitle_url=""
    
    echo "Downloading webpage content..."
    curl -s -L --cookie "$cookie_file" "$url" > "$temp_html"
    
    if [[ $? -ne 0 || ! -s "$temp_html" ]]; then
        echo "Error: Failed to download webpage or page is empty"
        exit 1
    fi
    
    echo "Analyzing webpage for stream URLs..."
    
    # Look for common video stream patterns
    # This is a simplified approach - actual implementation would need to be tailored to the specific website
    
    # Try to find HLS (.m3u8) or DASH (.mpd) manifests
    local manifests=$(grep -o 'https\?://[^"'\''[:space:]]*\.\(m3u8\|mpd\)' "$temp_html" | sort | uniq)
    
    if [[ -n "$manifests" ]]; then
        echo "Found potential stream manifests:"
        echo "$manifests"
        
        # Take the first manifest as the video URL
        video_url=$(echo "$manifests" | head -n 1)
        
        # Check if we have separate audio streams
        if echo "$manifests" | grep -q "audio"; then
            audio_url=$(echo "$manifests" | grep "audio" | head -n 1)
        fi
    else
        # Look for direct MP4 links
        local mp4_links=$(grep -o 'https\?://[^"'\''[:space:]]*\.mp4' "$temp_html" | sort | uniq)
        
        if [[ -n "$mp4_links" ]]; then
            echo "Found potential MP4 links:"
            echo "$mp4_links"
            
            # Take the first MP4 link as the video URL
            video_url=$(echo "$mp4_links" | head -n 1)
        fi
    fi
    
    # Look for subtitle files
    local subtitle_links=$(grep -o 'https\?://[^"'\''[:space:]]*\.\(srt\|vtt\|ass\)' "$temp_html" | sort | uniq)
    
    if [[ -n "$subtitle_links" ]]; then
        echo "Found potential subtitle links:"
        echo "$subtitle_links"
        
        # Take the first subtitle link
        subtitle_url=$(echo "$subtitle_links" | head -n 1)
    fi
    
    # If we have jq, try to parse JSON data that might contain stream information
    if command -v jq &> /dev/null; then
        echo "Searching for JSON data with stream information..."
        
        # Extract JSON objects from the page
        grep -o '{[^{]*"url"[^}]*}' "$temp_html" > "$temp_dir/json_snippets.txt"
        
        # If we found JSON with URLs, try to extract them
        if [[ -s "$temp_dir/json_snippets.txt" ]]; then
            if [[ -z "$video_url" ]]; then
                video_url=$(grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' "$temp_dir/json_snippets.txt" | 
                           grep -i "video\|mp4\|stream" | 
                           head -n 1 | 
                           sed 's/"url"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
            fi
            
            if [[ -z "$audio_url" ]]; then
                audio_url=$(grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' "$temp_dir/json_snippets.txt" | 
                           grep -i "audio" | 
                           head -n 1 | 
                           sed 's/"url"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
            fi
            
            if [[ -z "$subtitle_url" ]]; then
                subtitle_url=$(grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' "$temp_dir/json_snippets.txt" | 
                              grep -i "subtitle\|caption\|srt\|vtt" | 
                              head -n 1 | 
                              sed 's/"url"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
            fi
        fi
    fi
    
    # Save the results
    echo "# Stream URLs extracted from $url" > "$output_file"
    echo "# Extracted on $(date)" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ -n "$video_url" ]]; then
        echo "VIDEO_URL=\"$video_url\"" >> "$output_file"
        echo "Found video stream URL: $video_url"
    else
        echo "# No video stream URL found" >> "$output_file"
        echo "Warning: No video stream URL found"
    fi
    
    if [[ -n "$audio_url" ]]; then
        echo "AUDIO_URL=\"$audio_url\"" >> "$output_file"
        echo "Found audio stream URL: $audio_url"
    else
        echo "# No separate audio stream URL found" >> "$output_file"
        echo "Note: No separate audio stream URL found"
    fi
    
    if [[ -n "$subtitle_url" ]]; then
        echo "SUBTITLE_URL=\"$subtitle_url\"" >> "$output_file"
        echo "Found subtitle URL: $subtitle_url"
    else
        echo "# No subtitle URL found" >> "$output_file"
        echo "Note: No subtitle URL found"
    fi
    
    echo "" >> "$output_file"
    echo "# To use with download_stream.sh:" >> "$output_file"
    echo "# ./download_stream.sh -v \"\$VIDEO_URL\" -a \"\$AUDIO_URL\" -s \"\$SUBTITLE_URL\" -o \"output.mp4\"" >> "$output_file"
    
    echo "Stream URLs saved to: $output_file"
}

# Initialize variables
website_url=""
cookie_file=""
browser=""
output_file="streams.txt"

# Check for required tools
check_requirements

# Process command line arguments
while getopts "u:c:b:o:h" opt; do
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

# If website URL is not provided, ask for it
if [[ -z "$website_url" ]]; then
    read -p "Enter website URL: " website_url
    if ! validate_url "$website_url"; then
        echo "Error: Invalid website URL"
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

# Extract cookies if needed
extract_cookies "$browser" "$cookie_file"

# Extract stream URLs
extract_stream_urls "$website_url" "$cookie_file" "$output_file"

echo ""
echo "Next steps:"
echo "1. Review the extracted URLs in $output_file"
echo "2. Use download_stream.sh to download and combine the streams:"
echo "   ./download_stream.sh -v \"\$VIDEO_URL\" -a \"\$AUDIO_URL\" -s \"\$SUBTITLE_URL\" -o \"output.mp4\""
echo ""
echo "Or source the output file and use the variables directly:"
echo "   source $output_file"
echo "   ./download_stream.sh -v \"\$VIDEO_URL\" -a \"\$AUDIO_URL\" -s \"\$SUBTITLE_URL\" -o \"output.mp4\""
