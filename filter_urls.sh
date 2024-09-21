#!/bin/bash

# Usage:
# ./filter_urls.sh -i inputfile.txt -md "domain1" -md "domain2"

# Default variables
MATCH_DOMAINS=()
INPUT_FILE=""

# Help message function
print_help() {
  echo "Usage: ./filter_urls.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -i    Input file containing URLs."
  echo "  -md   Domain or subdomain to match (can be used multiple times)."
  echo "  -h    Show this help message."
  echo ""
  echo "Example:"
  echo "  ./filter_urls.sh -i inputfile.txt -md domain1 -md domain2"
  exit 0
}

# Parse flags
while [[ "$1" != "" ]]; do
    case "$1" in
        -i )    shift
                INPUT_FILE="$1"
                ;;
        -md )   shift
                MATCH_DOMAINS+=("$1")
                ;;
        -h | --help ) 
                print_help
                ;;
        * )     echo "Invalid option. Use -h for help."
                exit 1
    esac
    shift
done

# Check if input file is provided
if [ -z "$INPUT_FILE" ]; then
  echo "Error: No input file provided. Use -i to specify the input file."
  exit 1
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file '$INPUT_FILE' not found!"
  exit 1
fi

# Check if at least one domain is provided
if [ ${#MATCH_DOMAINS[@]} -eq 0 ]; then
  echo "Error: No domain or subdomain provided. Use -md to specify at least one domain/subdomain."
  exit 1
fi

# Output files
SUBDOMAIN_FILE="subdomain.txt"
URL_FILE="url.txt"
JAVASCRIPT_FILE="java.txt"
URL_WITH_PATH_FILE="url-with-path.txt"
EXTENSION_FILE="extension.txt"

# Empty the output files
> "$SUBDOMAIN_FILE"
> "$URL_FILE"
> "$JAVASCRIPT_FILE"
> "$URL_WITH_PATH_FILE"
> "$EXTENSION_FILE"

# Helper function to check if the line matches any of the domains/subdomains
match_domain() {
  local line="$1"
  for domain in "${MATCH_DOMAINS[@]}"; do
    if [[ "$line" =~ $domain ]]; then
      return 0  # Match found
    fi
  done
  return 1  # No match
}

# Process the input file
while IFS= read -r line
do
  # Extract subdomains
  if [[ $line =~ ^\[subdomains\] ]]; then
    if match_domain "$line"; then
      subdomain=$(echo "$line" | grep -oP '(?<= - ).*')
      echo "$subdomain" >> "$SUBDOMAIN_FILE"
    fi
  
  # Extract URLs
  elif [[ $line =~ ^\[url\] ]]; then
    if match_domain "$line"; then
      url=$(echo "$line" | grep -oP '(?<= - )https?.*')
      echo "$url" >> "$URL_FILE"
      echo "$url" >> "$EXTENSION_FILE"
    fi
  
  # Extract JavaScript files
  elif [[ $line =~ ^\[javascript\] && $line =~ \.js$ ]]; then
    if match_domain "$line"; then
      js_file=$(echo "$line" | grep -oP '(?<= - )https?.*')
      echo "$js_file" >> "$JAVASCRIPT_FILE"
      echo "$js_file" >> "$EXTENSION_FILE"
    fi

  # Extract URLs and merge paths for [linkfinder] cases
  elif [[ $line =~ ^\[linkfinder\] ]]; then
    if match_domain "$line"; then
      # Extract the base URL
      base_url=$(echo "$line" | grep -oP '(?<=from: ).*?(?=\])')
      
      # Extract the path after " - "
      path=$(echo "$line" | grep -oP '(?<= - ).*')

      # Determine whether the path is relative or absolute
      if [[ "$path" =~ ^https?:// ]]; then
        # If it's an absolute URL, save it as is
        final_url="$path"
      else
        # If it's a relative path, merge it with the base URL
        if [[ $path =~ ^/ ]]; then
          final_url="${base_url%/}$path"
        else
          final_url="$base_url/$path"
        fi
      fi

      # Clean the path from unwanted relative references like "./" and malformed URLs
      final_url=$(echo "$final_url" | sed 's|\./||g' | sed 's| //|/|g')

      # Save the merged URL to url-with-path.txt
      echo "$final_url" >> "$URL_WITH_PATH_FILE"
    fi
  fi

done < "$INPUT_FILE"

# Remove duplicates in extension.txt
sort -u "$EXTENSION_FILE" -o "$EXTENSION_FILE"

# Count the number of lines in each output file
subdomain_count=$(wc -l < "$SUBDOMAIN_FILE")
url_count=$(wc -l < "$URL_FILE")
js_count=$(wc -l < "$JAVASCRIPT_FILE")
url_with_path_count=$(wc -l < "$URL_WITH_PATH_FILE")
extension_count=$(wc -l < "$EXTENSION_FILE")

# Display results
echo "Filtering complete!"
echo "Subdomains saved to $SUBDOMAIN_FILE ($subdomain_count entries)"
echo "URLs saved to $URL_FILE ($url_count entries)"
echo "JavaScript files saved to $JAVASCRIPT_FILE ($js_count entries)"
echo "Merged URLs with paths saved to $URL_WITH_PATH_FILE ($url_with_path_count entries)"
echo "URLs with extensions saved to $EXTENSION_FILE ($extension_count entries)"
