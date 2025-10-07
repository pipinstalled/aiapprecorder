# Persian Speech-to-Text FastAPI Backend

A high-performance FastAPI backend service for Persian speech recognition using the `jonatasgrosman/wav2vec2-large-xlsr-53-persian` model.

## Features

- 🚀 **FastAPI**: Modern, fast web framework with automatic API documentation
- 🇮🇷 **Persian Language Support**: Specialized for Persian speech recognition
- 🎯 **High Accuracy**: 30.12% WER and 7.37% CER on Common Voice Persian test set
- 📱 **Mobile Ready**: Optimized for React Native integration
- 🔄 **Async Support**: Full async/await support for better performance
- 📊 **Confidence Scoring**: Provides transcription confidence levels
- 🎵 **Multiple Formats**: Supports WAV, MP3, M4A, FLAC, OGG, AAC
- 📖 **Auto Documentation**: Interactive API docs at `/docs`
- 🔧 **GPU Support**: Automatic GPU detection and utilization

## Installation

1. **Install Python 3.10+**
   ```bash
   python --version  # Should be 3.10 or higher
   ```

2. **Create virtual environment (recommended)**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

## Quick Start

1. **Start the server**
   ```bash
   python main.py
   # or
   python run.py
   ```

2. **Access the API**
   - Server: http://localhost:8000
   - Interactive docs: http://localhost:8000/docs
   - Alternative docs: http://localhost:8000/redoc

## API Endpoints

### Health Check
- **GET** `/health`
- Returns service status and model information

### Transcribe Audio File
- **POST** `/transcribe`
- Upload audio file via multipart/form-data
- **Content-Type**: `multipart/form-data`
- **Parameter**: `audio` (file upload)

### Transcribe Base64 Audio
- **POST** `/transcribe-base64`
- Send base64 encoded audio data
- **Content-Type**: `application/json`
- **Body**: `{"audio_base64": "base64_encoded_audio"}`

### Transcribe from URL
- **POST** `/transcribe-url`
- Transcribe audio from a URL (for testing)
- **Content-Type**: `application/json`
- **Body**: `{"audio_url": "https://example.com/audio.wav"}`

## Response Format

```json
{
  "success": true,
  "transcription": "متن تبدیل شده به فارسی",
  "confidence": 0.95,
  "language": "persian",
  "model": "jonatasgrosman/wav2vec2-large-xlsr-53-persian",
  "audio_duration": 5.2,
  "processing_time": 1.8
}
```

## Audio Requirements

- **Sample Rate**: Automatically converted to 16kHz
- **Duration**: 0.5 - 30 seconds
- **Formats**: WAV, MP3, M4A, FLAC, OGG, AAC
- **Quality**: Higher quality audio produces better results

## Performance

- **First Request**: ~5-10 seconds (model loading)
- **Subsequent Requests**: ~1-3 seconds
- **GPU Acceleration**: Automatic if CUDA is available
- **Concurrent Requests**: Supports multiple simultaneous requests

## Testing

Run the test suite:
```bash
python test_api.py
```

## Server Deployment

### Deploy to Server (65.21.115.188)
```bash
./deploy_to_server.sh
```

This will:
1. Install Python 3.10 and dependencies
2. Create virtual environment
3. Install FastAPI dependencies
4. Set up systemd service
5. Start the service on port 8001

### Nginx Configuration

For `aiapp.sazjoo.com` domain:
```bash
# Copy nginx config to server
scp nginx-aiapp-config.conf root@65.21.115.188:/etc/nginx/sites-available/aiapp.sazjoo.com

# On server:
ln -s /etc/nginx/sites-available/aiapp.sazjoo.com /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

## Integration with React Native

Update your React Native app's backend URL to:
```
http://aiapp.sazjoo.com
```

Example usage in React Native:
```javascript
const response = await fetch('http://aiapp.sazjoo.com/transcribe-base64', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    audio_base64: base64AudioData,
  }),
});

const result = await response.json();
console.log('Transcription:', result.transcription);
```

## Troubleshooting

### Model Loading Issues
- Ensure stable internet connection for initial model download
- Check available disk space (model is ~1.5GB)
- Verify Python version compatibility

### Audio Processing Issues
- Check audio file format is supported
- Ensure audio duration is within limits (0.5-30 seconds)
- Verify audio file is not corrupted

### Performance Issues
- Install CUDA for GPU acceleration
- Increase server resources for better performance
- Consider using multiple workers in production

## Model Information

- **Model**: `jonatasgrosman/wav2vec2-large-xlsr-53-persian`
- **Base Model**: Facebook's wav2vec2-large-xlsr-53
- **Training Data**: Common Voice 6.1 Persian dataset
- **Performance**: 30.12% WER, 7.37% CER on test set
- **Input Requirements**: 16kHz audio
- **Output**: Persian text transcription

## License

This service uses the wav2vec2 model which is subject to its own license terms.
