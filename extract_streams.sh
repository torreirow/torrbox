#!/usr/bin/env bash

# Script to extract video, audio, and subtitle stream URLs from a website using browser cookies
# Usage: ./extract_streams.sh -u <website_url> -c <cookie_file> [-b <browser>]

# Function to display usage information
show_usage() {
    echo "Usage: $0 -u <website_url> [-c <cookie_file> | -b <browser>] [-o <output_file>]"
    echo "Options:"
    echo "  -u <url>      Website URL containing the streams"
    echo "  -c <file>     Cookie file (exported from browser)"
    echo "  -b <browser>  Browser to use for cookie extraction (chrome, firefox, edge, safari)"
    echo "  -p <profile>  Browser profile to use (default: use the default profile)"
    echo "  -o <file>     Output file to save stream URLs (default: streams.txt)"
    echo "  -h            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -u https://example.com/video -b chrome"
    echo "  $0 -u https://example.com/video -b firefox -p default"
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
    
    if [[ -n "$browser" && -z "$cookie_file" ]]; then
        if ! command -v python3 &> /dev/null; then
            echo "Error: python3 is required for browser cookie extraction."
            exit 1
        fi
        
        if ! python3 -c "import browser_cookie3" &> /dev/null; then
            echo "Error: browser_cookie3 Python module is not installed."
            echo "Please install it with: pip install browser-cookie3"
            exit 1
        fi
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
    local browser_name="$1"
    local profile="$2"
    local cookie_file="$3"
    local temp_cookies="$temp_dir/cookies.txt"
    
    # If cookie file is provided, use it directly
    if [[ -n "$cookie_file" ]]; then
        if [[ -f "$cookie_file" ]]; then
            cp "$cookie_file" "$temp_cookies"
            echo "Using provided cookie file: $cookie_file"
            return 0
        else
            echo "Error: Cookie file not found: $cookie_file"
            exit 1
        fi
    fi
    
    # Otherwise extract from browser using browser_cookie3
    if [[ -n "$browser_name" ]]; then
        echo "Extracting cookies from $browser_name browser..."
        
        # Create a Python script to extract cookies
        cat > "$temp_dir/extract_cookies.py" << EOF
import browser_cookie3
import sys
import os
import json
import http.cookiejar

def extract_cookies(browser_name, domain, profile=None):
    try:
        if browser_name.lower() == 'chrome':
            if profile:
                cookies = browser_cookie3.chrome(domain_name=domain, profile_name=profile)
            else:
                cookies = browser_cookie3.chrome(domain_name=domain)
        elif browser_name.lower() == 'firefox':
            if profile:
                cookies = browser_cookie3.firefox(domain_name=domain, profile_name=profile)
            else:
                cookies = browser_cookie3.firefox(domain_name=domain)
        elif browser_name.lower() == 'edge':
            if profile:
                cookies = browser_cookie3.edge(domain_name=domain, profile_name=profile)
            else:
                cookies = browser_cookie3.edge(domain_name=domain)
        elif browser_name.lower() == 'safari':
            cookies = browser_cookie3.safari(domain_name=domain)
        else:
            print(f"Error: Unsupported browser: {browser_name}")
            return False
            
        # Convert to Netscape format (curl compatible)
        with open(sys.argv[1], 'w') as f:
            f.write("# Netscape HTTP Cookie File\n")
            for cookie in cookies:
                if not cookie.value:
                    continue
                secure = "TRUE" if cookie.secure else "FALSE"
                http_only = "TRUE" if cookie.has_nonstandard_attr('HttpOnly') else "FALSE"
                expires = int(cookie.expires) if cookie.expires else 0
                f.write(f"{cookie.domain}\t{'TRUE' if cookie.domain.startswith('.') else 'FALSE'}\t{cookie.path}\t{secure}\t{expires}\t{cookie.name}\t{cookie.value}\n")
        return True
    except Exception as e:
        print(f"Error extracting cookies: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python extract_cookies.py <output_file> <browser> <domain> [profile]")
        sys.exit(1)
        
    output_file = sys.argv[1]
    browser = sys.argv[2]
    domain = sys.argv[3]
    profile = sys.argv[4] if len(sys.argv) > 4 else None
    
    success = extract_cookies(browser, domain, profile)
    sys.exit(0 if success else 1)
EOF
        
        # Extract domain from URL
        domain=$(echo "$website_url" | sed -E 's|^https?://([^/]+).*|\1|')
        
        # Run the Python script
        if [[ -n "$profile" ]]; then
            python3 "$temp_dir/extract_cookies.py" "$temp_cookies" "$browser_name" "$domain" "$profile"
        else
            python3 "$temp_dir/extract_cookies.py" "$temp_cookies" "$browser_name" "$domain"
        fi
        
        if [[ $? -ne 0 || ! -s "$temp_cookies" ]]; then
            echo "Error: Failed to extract cookies from $browser_name"
            exit 1
        fi
        
        echo "Successfully extracted cookies from $browser_name for domain $domain"
        return 0
    else
        echo "Error: No cookie source specified (neither file nor browser)"
        exit 1
    fi
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
profile=""
output_file="streams.txt"

# Check for required tools
check_requirements

# Process command line arguments
while getopts "u:c:b:p:o:h" opt; do
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

# Extract cookies
extract_cookies "$browser" "$profile" "$cookie_file"

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
