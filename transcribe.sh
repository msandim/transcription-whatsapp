#!/bin/bash

# Exit on undefined variables
set -u

# Define directories first
input_dir="./audios"
output_dir="./transcriptions"
log_dir="./logs"
temp_dir="./temp"

# Create directories
mkdir -p "$input_dir" "$output_dir" "$log_dir" "$temp_dir"

# Log files - export them immediately
export main_log="${log_dir}/processing.log"
export error_log="${log_dir}/errors.log"

# Function to log messages to both console and file
log_message() {
    echo "$1" | tee -a "${main_log}"
}
export -f log_message

# Define configuration variables
parallel_processes=2

# Clear log file first
: > "${main_log}"  # Clear the log file

# Show initial banner (before main function)
clear
log_message "=== Processing Started at $(date) ==="
log_message "System: MacBook Air M3 (16 GB RAM)" 
log_message "Parallel processes: $parallel_processes"
log_message "================================================="
echo  # Add a blank line for readability

# Stats variables
total_processed=0
total_failed=0
total_size_processed=0
start_time=$(date +%s)

# Format size for macOS
format_size() {
    local size=$1
    if [ $size -ge 1073741824 ]; then
        echo "$(($size / 1073741824))GB"
    elif [ $size -ge 1048576 ]; then
        echo "$(($size / 1048576))MB"
    elif [ $size -ge 1024 ]; then
        echo "$(($size / 1024))KB"
    else
        echo "${size}B"
    fi
}
export -f format_size

# Function to display timestamp
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}
export -f timestamp

# At the top of the script with other variables
export temp_dir="./temp"
export lock_file="${temp_dir}/lock"
export processed_count_file="${temp_dir}/processed_count"
export processed_size_file="${temp_dir}/processed_size"
export failed_count_file="${temp_dir}/failed_count"
export START_TIME=$(date +%s)

# At the top of the script
# Ensure we have a single trap handler
cleanup_done=0

# Function to process a single file
process_file() {
    local input_file="$1"
    local base_name=$(basename "$input_file" .opus)
    local start_time=$(date +%s)
    local file_size=$(stat -f %z "$input_file")
    local temp_log="${TEMP_DIR}/${base_name}.log"
    
    # Add a newline before processing message
    echo
    printf "🎯 [%s] Processing: %s (%s)\n" "$(timestamp)" "$base_name" "$(format_size $file_size)" | tee -a "$main_log"
    
    if whisperx "$input_file" \
        --language pt \
        --model medium \
        --output_format txt \
        --output_dir "$OUTPUT_DIR" \
        --compute_type int8 \
        --device cpu \
        > "$temp_log" 2>&1; then
        
        # Update counters using macOS-compatible file locking
        (
            while ! ln "${lock_file}" "${lock_file}.lock" 2>/dev/null; do
                sleep 0.1
            done
            
            count=$(cat "$processed_count_file" 2>/dev/null || echo 0)
            echo $((count + 1)) > "$processed_count_file"
            
            size=$(cat "$processed_size_file" 2>/dev/null || echo 0)
            echo $((size + file_size)) > "$processed_size_file"
            
            rm -f "${lock_file}.lock"
        )
        
        # Calculate processing time and speed
        local duration=$(($(date +%s) - start_time))
        local speed=$(bc -l <<< "scale=2; ($file_size / 1048576) / $duration") # Convert bytes to MB and divide by seconds
        
        # Log completion with correct speed
        printf "✅ [%s] Completed: %s (%ds, %.2f MB/s)\n" \
            "$(timestamp)" "$base_name" "$duration" "$speed" | tee -a "$main_log"
        
        rm -f "$input_file"
        rm -f "$temp_log"
        printf "🗑️  [%s] Deleted: %s\n" "$(timestamp)" "$base_name" | tee -a "$main_log"
        
        # Calculate and show ETA with proper MB/hour rate
        local elapsed=$(($(date +%s) - START_TIME))
        local processed_size=$(cat "$processed_size_file")
        local mb_per_hour=$(bc -l <<< "scale=2; ($processed_size / 1048576) / ($elapsed / 3600)")
        local total_size=$(find "$INPUT_DIR" -name "*.opus" -type f -exec stat -f %z {} \; | awk '{sum += $1} END {print sum}')
        local eta_hours=$(bc -l <<< "scale=1; ($total_size / 1048576) / $mb_per_hour")
        local eta_time=$(date -v +${eta_hours%.*}H +'%d %b %Y %H:%M')
        
        printf "📊 Progress: %d/%d files | %s/%s | %.1f MB/hr | ETA: %.1f hrs (%s)\n" \
            "$(cat $processed_count_file)" \
            "$(($(cat $processed_count_file) + $(find "$INPUT_DIR" -name "*.opus" -type f | wc -l)))" \
            "$(format_size $processed_size)" \
            "$(format_size $total_size)" \
            "$mb_per_hour" "$eta_hours" "$eta_time" | tee -a "$main_log"
        
        echo  # Add blank line for readability
        
    else
        # Error handling remains the same
        (
            while ! ln "${lock_file}" "${lock_file}.lock" 2>/dev/null; do
                sleep 0.1
            done
            
            count=$(cat "$failed_count_file" 2>/dev/null || echo 0)
            echo $((count + 1)) > "$failed_count_file"
            
            rm -f "${lock_file}.lock"
        )
        
        printf "❌ [%s] Error processing: %s (see error log)\n" "$(timestamp)" "$base_name" | tee -a "$main_log"
        echo
    fi
}
export -f process_file

# Function to write summary
write_summary() {
    echo >> "${main_log}"
    echo "=== Processing Summary ===" >> "${main_log}"
    echo "Completed at: $(date)" >> "${main_log}"
    echo "Total files processed: $total_processed" >> "${main_log}"
    echo "Total files failed: $total_failed" >> "${main_log}"
    echo "Total data processed: $(format_size $total_size_processed)" >> "${main_log}"
    echo "Total time elapsed: $(($(date +%s) - start_time))s" >> "${main_log}"
    echo "=========================" >> "${main_log}"

    if [ $total_failed -gt 0 ]; then
        echo "Failed files are logged in: ${error_log}" >> "${main_log}"
    fi
}

# Function to cleanup resources on exit
cleanup() {
    # Prevent multiple cleanup runs
    if [ "$cleanup_done" -eq 1 ]; then
        return
    fi
    cleanup_done=1
    
    echo
    log_message "Cleaning up..."
    
    # Kill all child processes
    pkill -P $$ || true
    
    # Kill any remaining whisperx processes
    pkill -f whisperx || true
    
    # Get final counts
    total_processed=$(cat "$processed_count_file" 2>/dev/null || echo 0)
    total_failed=$(cat "$failed_count_file" 2>/dev/null || echo 0)
    total_size_processed=$(cat "$processed_size_file" 2>/dev/null || echo 0)
    
    # Write summary
    echo
    log_message "=== Processing Summary ==="
    log_message "Completed at: $(date)"
    log_message "Total files processed: $total_processed"
    log_message "Total files failed: $total_failed"
    log_message "Total data processed: $(format_size $total_size_processed)"
    log_message "Total time elapsed: $(($(date +%s) - start_time))s"
    log_message "========================="

    if [ $total_failed -gt 0 ]; then
        log_message "Failed files are logged in: $error_log"
    fi
    
    # Remove temp directory
    rm -rf "$temp_dir"
    
    log_message "=== Processing ended at $(date) ==="
    
    # Ensure we exit
    exit 0
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Main execution
main() {
    # Check for input files
    total_files=$(find "$input_dir" -name "*.opus" -type f | wc -l | tr -d ' ')
    if [ "$total_files" -eq 0 ]; then
        log_message "No .opus files found in $input_dir."
        exit 0
    fi
    
    log_message "🚀 Starting processing of $total_files files..."
    log_message "📊 Progress:"
    echo
    
    # Initialize stats variables
    total_processed=0
    total_failed=0
    total_size_processed=0
    
    # Initialize counter files and lock file
    mkdir -p "$temp_dir"
    touch "${lock_file}"
    echo 0 > "$processed_count_file"
    echo 0 > "$processed_size_file"
    echo 0 > "$failed_count_file"
    
    # Export all necessary variables for parallel processes
    export START_TIME="$start_time"
    export INPUT_DIR="$input_dir"
    export OUTPUT_DIR="$output_dir"
    export ERROR_LOG="$error_log"
    export TEMP_DIR="$temp_dir"
    
    # Process files using GNU Parallel
    find "$INPUT_DIR" -name "*.opus" -type f -print0 | \
        parallel --jobs "$parallel_processes" \
                --null \
                --line-buffer \
                --will-cite \
                --env main_log \
                --env error_log \
                --env INPUT_DIR \
                --env OUTPUT_DIR \
                --env TEMP_DIR \
                --env START_TIME \
                --env lock_file \
                --env processed_count_file \
                --env processed_size_file \
                --env failed_count_file \
                "process_file {}"
}

# Run main function
main "$@"