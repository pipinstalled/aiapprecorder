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
    audio_base64: str


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


def preprocess_audio(
    audio_file_path: str, target_sr: int = TARGET_SAMPLE_RATE
) -> tuple[np.ndarray, float]:
    """
    Preprocess audio file for wav2vec2 model
    - Convert to 16kHz sample rate
    - Normalize audio
    - Return audio array and duration
    """
    try:
        # Load audio file using scipy
        sr, audio = wavfile.read(audio_file_path)

        # Convert to float and normalize
        if audio.dtype == np.int16:
            audio = audio.astype(np.float32) / 32768.0
        elif audio.dtype == np.int32:
            audio = audio.astype(np.float32) / 2147483648.0
        elif audio.dtype == np.uint8:
            audio = (audio.astype(np.float32) - 128.0) / 128.0

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
            audio_data = base64.b64decode(request.audio_base64)
        except Exception as e:
            raise HTTPException(
                status_code=400, detail=f"Invalid base64 audio data: {str(e)}"
            ) from e

        # Save to temporary file (assume WAV format for base64)
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
