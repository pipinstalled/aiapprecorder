#!/usr/bin/env python3
"""
FastAPI Backend Service for Persian Speech-to-Text using
wav2vec2-large-xlsr-53-persian
This service provides a high-performance REST API for converting Persian
audio to text.
"""

import asyncio
import base64
import os
import tempfile
from pathlib import Path
from typing import Dict, Optional

import numpy as np
import torch
import uvicorn
from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from pydub import AudioSegment
from scipy.io import wavfile
from scipy.signal import resample
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

# Initialize FastAPI app
app = FastAPI(
    title="Persian Speech-to-Text API",
    description=(
        "High-performance API for Persian speech recognition using "
        "wav2vec2-large-xlsr-53-persian model"
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify React Native app origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables for model and processor
model: Optional[Wav2Vec2ForCTC] = None
processor: Optional[Wav2Vec2Processor] = None
model_loaded = False

# Configuration
MODEL_NAME = "jonatasgrosman/wav2vec2-large-xlsr-53-persian"
TARGET_SAMPLE_RATE = 16000
MAX_AUDIO_LENGTH = 30  # seconds
MIN_AUDIO_LENGTH = 0.5  # seconds
SUPPORTED_FORMATS = [".wav", ".mp3", ".m4a", ".flac", ".ogg", ".aac"]


# Pydantic models for request/response
class TranscriptionResponse(BaseModel):
    success: bool
    transcription: Optional[str] = None
    confidence: Optional[float] = None
    language: str = "persian"
    model: str = MODEL_NAME
    audio_duration: Optional[float] = None
    processing_time: Optional[float] = None
    error: Optional[str] = None


class Base64TranscriptionRequest(BaseModel):
    audio: str  # base64 encoded audio
    filename: Optional[str] = None
    content_type: Optional[str] = None


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    service: str = "Persian Speech-to-Text FastAPI Service"
    version: str = "1.0.0"


# Model loading functions
async def load_model():
    """Load the Persian wav2vec2 model and processor"""
    global model, processor, model_loaded

    if not model_loaded:
        print("Loading Persian wav2vec2 model...")
        try:
            # Set cache directory to a writable location
            cache_dir = os.environ.get("TRANSFORMERS_CACHE", "/tmp/transformers_cache")
            os.makedirs(cache_dir, exist_ok=True)

            # Load processor and model with cache directory
            processor = Wav2Vec2Processor.from_pretrained(
                MODEL_NAME, cache_dir=cache_dir, force_download=False
            )
            model = Wav2Vec2ForCTC.from_pretrained(
                MODEL_NAME, cache_dir=cache_dir, force_download=False
            )
            model.eval()

            # Move to GPU if available
            if torch.cuda.is_available():
                model = model.cuda()
                print("Model loaded on GPU")
            else:
                print("Model loaded on CPU")

            model_loaded = True
            print("Model loaded successfully!")

        except Exception as e:
            print(f"Error loading model: {e}")
            raise e


def convert_audio_to_wav(input_path: str, output_path: str) -> str:
    """
    Convert any audio format to WAV using pydub
    Returns the path to the converted WAV file
    """
    try:
        # Detect format from file extension
        file_ext = Path(input_path).suffix.lower()
        
        # Load audio file using pydub (supports many formats)
        if file_ext == '.wav':
            # Already WAV, just copy or return original
            audio = AudioSegment.from_wav(input_path)
        elif file_ext == '.mp3':
            audio = AudioSegment.from_mp3(input_path)
        elif file_ext == '.m4a':
            audio = AudioSegment.from_file(input_path, format='m4a')
        elif file_ext == '.flac':
            audio = AudioSegment.from_file(input_path, format='flac')
        elif file_ext == '.ogg':
            audio = AudioSegment.from_ogg(input_path)
        elif file_ext == '.aac':
            audio = AudioSegment.from_file(input_path, format='aac')
        else:
            # Try to auto-detect format
            audio = AudioSegment.from_file(input_path)
        
        # Export as WAV (16kHz, mono, 16-bit PCM)
        audio = audio.set_frame_rate(TARGET_SAMPLE_RATE)
        audio = audio.set_channels(1)  # Convert to mono
        audio.export(output_path, format='wav')
        
        return output_path
    except Exception as e:
        print(f"Error converting audio to WAV: {e}")
        raise ValueError(f"Failed to convert audio file: {str(e)}") from e


def preprocess_audio(
    audio_file_path: str, target_sr: int = TARGET_SAMPLE_RATE
) -> tuple[np.ndarray, float]:
    """
    Preprocess audio file for wav2vec2 model
    - Convert any format to WAV if needed
    - Convert to 16kHz sample rate
    - Normalize audio
    - Return audio array and duration
    """
    try:
        # Check if file is already WAV by reading first bytes
        is_wav = False
        try:
            with open(audio_file_path, 'rb') as f:
                header = f.read(4)
                if header == b'RIFF' or header == b'RIFX':
                    is_wav = True
        except:
            pass
        
        # Convert to WAV if needed
        if not is_wav:
            print(f"Converting {Path(audio_file_path).suffix} to WAV...")
            with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as temp_wav:
                wav_path = temp_wav.name
            try:
                convert_audio_to_wav(audio_file_path, wav_path)
                audio_file_path = wav_path
            except Exception as e:
                # Clean up temp file if conversion failed
                if os.path.exists(wav_path):
                    os.unlink(wav_path)
                raise e
        
        # Load audio file using scipy (now guaranteed to be WAV)
        sr, audio = wavfile.read(audio_file_path)
        
        # Clean up converted WAV file if it was temporary
        if not is_wav and os.path.exists(audio_file_path):
            try:
                os.unlink(audio_file_path)
            except:
                pass

        # Convert to float and normalize
        if audio.dtype == np.int16:
            audio = audio.astype(np.float32) / 32768.0
        elif audio.dtype == np.int32:
            audio = audio.astype(np.float32) / 2147483648.0
        elif audio.dtype == np.uint8:
            audio = (audio.astype(np.float32) - 128.0) / 128.0

        # Handle stereo audio (convert to mono by averaging channels)
        if len(audio.shape) > 1:
            audio = np.mean(audio, axis=1)

        # Resample if necessary
        if sr != target_sr:
            num_samples = int(len(audio) * target_sr / sr)
            audio = resample(audio, num_samples)

        # Normalize audio
        if np.max(np.abs(audio)) > 0:
            audio = audio / np.max(np.abs(audio))

        # Calculate duration
        duration = len(audio) / target_sr

        # Validate audio length
        if duration < MIN_AUDIO_LENGTH:
            raise ValueError(
                f"Audio too short: {duration:.2f}s " f"(minimum: {MIN_AUDIO_LENGTH}s)"
            )

        if duration > MAX_AUDIO_LENGTH:
            raise ValueError(
                f"Audio too long: {duration:.2f}s " f"(maximum: {MAX_AUDIO_LENGTH}s)"
            )

        return audio, duration

    except Exception as e:
        print(f"Error preprocessing audio: {e}")
        raise e


def transcribe_audio(audio_array: np.ndarray) -> tuple[str, float]:
    """
    Transcribe audio array to Persian text
    Returns transcription and confidence score
    """
    try:
        # Process audio with the processor
        input_values = processor(
            audio_array, return_tensors="pt", sampling_rate=TARGET_SAMPLE_RATE
        ).input_values

        # Move to GPU if available
        if torch.cuda.is_available():
            input_values = input_values.cuda()

        # Perform inference
        with torch.no_grad():
            logits = model(input_values).logits

        # Get predicted token IDs
        predicted_ids = torch.argmax(logits, dim=-1)

        # Decode to text
        transcription = processor.batch_decode(predicted_ids)[0]

        # Calculate confidence (based on max logit value)
        max_logits = torch.max(torch.softmax(logits, dim=-1))
        confidence = float(max_logits)

        return transcription.strip(), confidence

    except Exception as e:
        print(f"Error during transcription: {e}")
        raise e


# Dependency to ensure model is loaded
async def get_model():
    if not model_loaded:
        await load_model()
    return model, processor


# API Endpoints
@app.on_event("startup")
async def startup_event():
    """Load model on startup"""
    await load_model()


@app.get("/", response_model=Dict[str, str])
async def root():
    """Root endpoint"""
    return {
        "message": "Persian Speech-to-Text API",
        "version": "1.0.0",
        "docs": "/docs",
        "model": MODEL_NAME,
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        model_loaded=model_loaded,
        service="Persian Speech-to-Text FastAPI Service",
    )


@app.post("/transcribe", response_model=TranscriptionResponse)
async def transcribe_audio_file(
    audio: UploadFile = File(...), _: tuple = Depends(get_model)
):
    """
    Transcribe audio file uploaded via multipart/form-data
    """
    start_time = asyncio.get_event_loop().time()

    try:
        # Validate file format
        file_extension = Path(audio.filename).suffix.lower()
        if file_extension not in SUPPORTED_FORMATS:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Unsupported audio format: {file_extension}. "
                    f"Supported formats: {SUPPORTED_FORMATS}"
                ),
            )

        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(
            delete=False, suffix=file_extension
        ) as temp_file:
            content = await audio.read()
            temp_file.write(content)
            temp_path = temp_file.name

        try:
            # Load and preprocess audio
            audio_array, duration = preprocess_audio(temp_path)

            # Transcribe audio
            transcription, confidence = transcribe_audio(audio_array)

            processing_time = asyncio.get_event_loop().time() - start_time

            return TranscriptionResponse(
                success=True,
                transcription=transcription,
                confidence=confidence,
                audio_duration=duration,
                processing_time=processing_time,
            )

        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.unlink(temp_path)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Transcription failed: {str(e)}"
        ) from e


@app.post("/transcribe-base64", response_model=TranscriptionResponse)
async def transcribe_base64_audio(
    request: Base64TranscriptionRequest, _: tuple = Depends(get_model)
):
    """
    Transcribe base64 encoded audio data
    """
    start_time = asyncio.get_event_loop().time()

    try:
        # Decode base64 audio
        try:
            audio_data = base64.b64decode(request.audio)
        except Exception as e:
            raise HTTPException(
                status_code=400, detail=f"Invalid base64 audio data: {str(e)}"
            ) from e

        # Detect audio format from filename, content_type, or file header
        file_ext = ".m4a"  # Default to m4a (common for React Native recordings)
        
        # Try filename first
        if request.filename:
            file_ext = Path(request.filename).suffix.lower() or ".m4a"
        
        # Try content_type second
        elif request.content_type:
            content_type_map = {
                'audio/wav': '.wav',
                'audio/mpeg': '.mp3',
                'audio/mp4': '.m4a',
                'audio/flac': '.flac',
                'audio/ogg': '.ogg',
                'audio/aac': '.aac',
            }
            file_ext = content_type_map.get(request.content_type, '.m4a')
        
        # Fallback: detect from file header
        else:
            if len(audio_data) >= 4:
                header = audio_data[:4]
                if header == b'RIFF' or header == b'RIFX':
                    file_ext = ".wav"
                elif header[:3] == b'ID3' or (len(audio_data) >= 2 and audio_data[0:2] == b'\xff\xfb'):
                    file_ext = ".mp3"
                elif header[:4] == b'fLaC':
                    file_ext = ".flac"
                elif header[:4] == b'OggS':
                    file_ext = ".ogg"
        
        # Ensure extension is in supported formats
        if file_ext not in SUPPORTED_FORMATS:
            file_ext = ".m4a"  # Default fallback
        
        # Save to temporary file with detected extension
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_ext) as temp_file:
            temp_file.write(audio_data)
            temp_path = temp_file.name

        try:
            # Load and preprocess audio
            audio_array, duration = preprocess_audio(temp_path)

            # Transcribe audio
            transcription, confidence = transcribe_audio(audio_array)

            processing_time = asyncio.get_event_loop().time() - start_time

            return TranscriptionResponse(
                success=True,
                transcription=transcription,
                confidence=confidence,
                audio_duration=duration,
                processing_time=processing_time,
            )

        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.unlink(temp_path)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Transcription failed: {str(e)}"
        ) from e


@app.post("/transcribe-url", response_model=TranscriptionResponse)
async def transcribe_audio_url(audio_url: str, _: tuple = Depends(get_model)):
    """
    Transcribe audio from URL (for testing purposes)
    """
    import aiohttp

    start_time = asyncio.get_event_loop().time()

    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(audio_url) as response:
                if response.status != 200:
                    raise HTTPException(
                        status_code=400, detail="Failed to download audio from URL"
                    )

                audio_data = await response.read()

        # Save to temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            temp_file.write(audio_data)
            temp_path = temp_file.name

        try:
            # Load and preprocess audio
            audio_array, duration = preprocess_audio(temp_path)

            # Transcribe audio
            transcription, confidence = transcribe_audio(audio_array)

            processing_time = asyncio.get_event_loop().time() - start_time

            return TranscriptionResponse(
                success=True,
                transcription=transcription,
                confidence=confidence,
                audio_duration=duration,
                processing_time=processing_time,
            )

        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.unlink(temp_path)

    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Transcription failed: {str(e)}"
        ) from e


# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(_request, exc):
    return JSONResponse(
        status_code=exc.status_code,
        content={"success": False, "error": exc.detail, "status_code": exc.status_code},
    )


@app.exception_handler(Exception)
async def general_exception_handler(_request, exc):
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": "Internal server error",
            "detail": str(exc),
        },
    )


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, log_level="info")
