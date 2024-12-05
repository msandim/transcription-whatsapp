# WhatsApp Audio Transcription Tool

A tool to automatically transcribe WhatsApp audio messages and integrate the transcriptions back into the chat export.

## Overview

This tool processes WhatsApp chat exports containing audio messages (.opus files) and creates a new chat file with the audio messages replaced by their transcriptions. It's particularly useful for making WhatsApp voice messages searchable and accessible.

## Features

- Processes WhatsApp chat exports with audio messages
- Transcribes .opus audio files to text
- Maintains chat formatting and structure
- Preserves original timestamps and sender information
- Supports parallel processing for faster transcription
- Includes error handling and logging

## Prerequisites

- Bash shell environment
- Python 3.x
- WhatsApp chat export with audio files

## Setup

1. Export your WhatsApp chat with media
2. Place the chat export file as `_chat.txt` in the root directory
3. Place all audio files in the `audios` directory

## Directory Structure

```
.
├── _chat.txt              # Input WhatsApp chat export
├── audios/                # Directory containing audio files
├── transcriptions/        # Directory for transcription outputs
├── process_chat.py        # Python script for chat processing
└── transcribe.sh         # Main transcription script
```

## Usage

1. Run the transcription script:
   ```bash
   ./transcribe.sh
   ```

2. Process the chat with transcriptions:
   ```bash
   python process_chat.py
   ```

The processed chat will be saved as `chat_2.txt` with all audio messages replaced by their transcriptions.

## Output

The tool generates:
- Transcription files in the `transcriptions` directory
- A new chat file (`chat_2.txt`) with integrated transcriptions
- Log files in the `logs` directory for tracking progress and errors

## License

This project is licensed under the terms included in the LICENSE file.
