import os
import re
from datetime import datetime

def count_words(text):
    return len(text.split())

def parse_date(line):
    # Extract date from line format like "[23.08.24, 11:18:58]"
    match = re.match(r'\[(\d{2})\.(\d{2})\.(\d{2}), (\d{2}):(\d{2}):(\d{2})\]', line)
    if match:
        day, month, year, hour, minute, second = map(int, match.groups())
        # Assuming years are in format '24' for 2024
        year += 2000
        return datetime(year, month, day, hour, minute, second)
    return None

def split_chat():
    # Create output directory if it doesn't exist
    output_dir = 'chats_divided'
    os.makedirs(output_dir, exist_ok=True)
    
    # Read all lines from chat_2.txt
    with open('chat_2.txt', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    if not lines:
        print("Error: chat_2.txt is empty")
        return
    
    # Variables for splitting
    current_part = 1
    current_words = 0
    current_lines = []
    first_date = None
    last_date = None
    
    # Process each line
    for line in lines:
        # Count words in this line
        line_words = count_words(line)
        
        # Update dates
        date = parse_date(line)
        if date:
            if not first_date:
                first_date = date
            last_date = date
        
        # If adding this line would exceed the limit, write current batch
        if current_words + line_words > 400000 and current_lines:
            # Format dates for filename
            filename = f'chat_part{current_part:03d}.txt'
            
            # Write current batch
            with open(os.path.join(output_dir, filename), 'w', encoding='utf-8') as f:
                f.writelines(current_lines)
            
            print(f"Created {filename} with {current_words} words")
            
            # Reset for next batch
            current_part += 1
            current_words = 0
            current_lines = []
            first_date = date
        
        # Add line to current batch
        current_lines.append(line)
        current_words += line_words
    
    # Write remaining lines if any
    if current_lines:
        filename = f'chat_part{current_part:03d}.txt'
        
        with open(os.path.join(output_dir, filename), 'w', encoding='utf-8') as f:
            f.writelines(current_lines)
        
        print(f"Created {filename} with {current_words} words")

if __name__ == '__main__':
    split_chat()
