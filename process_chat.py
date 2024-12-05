import re
import os

def get_transcript(audio_pattern):
    # Extract the full filename from the pattern like "00000638-AUDIO-2024-06-26-12-04-46.opus"
    transcript_path = f'transcriptions/{audio_pattern.replace(".opus", ".txt")}'
    if os.path.exists(transcript_path):
        with open(transcript_path, 'r', encoding='utf-8') as f:
            return f.read().strip()
    return None

def process_chat():
    try:
        with open('_chat.txt', 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print("Error: _chat.txt file not found.")
        return
    
    new_lines = []
    for line in lines:
        # Check if line contains an audio attachment
        if '<attached:' in line and '.opus>' in line:
            # Extract the full audio pattern
            match = re.search(r'<attached: (.*?)>', line)
            if match:
                audio_pattern = match.group(1)
                # Get the transcript
                transcript = get_transcript(audio_pattern)
                if transcript:
                    # Keep the timestamp and sender part (everything before the attachment)
                    header = line.split('<attached:')[0].strip()
                    # Split transcript into lines and prefix each with the header
                    for transcript_line in transcript.split('\n'):
                        if transcript_line.strip():  # Only add non-empty lines
                            new_lines.append(f'{header} {transcript_line.strip()}\n')
                    continue
        
        # If not an audio line or no transcript found, keep original line
        new_lines.append(line)
    
    try:
        # Write the processed content to chat_2.txt
        with open('chat_2.txt', 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
    except Exception as e:
        print(f"Error writing to chat_2.txt: {e}")

if __name__ == '__main__':
    process_chat()
