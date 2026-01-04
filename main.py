#!/usr/bin/env python3
"""
FastAPI Backend Service for Persian Speech-to-Text using
wav2vec2-large-xlsr-53-persian
This service provides a high-performance REST API for converting Persian
audio to text.
"""

import asyncio
import base64
import logging
import os
import tempfile
import traceback
from pathlib import Path
from typing import Dict, Optional

import numpy as np
import torch
import uvicorn
from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, model_validator
from pydub import AudioSegment
from scipy.io import wavfile
from scipy.signal import resample
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

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
    audio: Optional[str] = None  # base64 encoded audio (new field name)
    audio_base64: Optional[str] = None  # base64 encoded audio (old field name for backward compatibility)
    filename: Optional[str] = None
    content_type: Optional[str] = None
    file_extension: Optional[str] = None  # File extension (e.g., "m4a", "mp3") - helps with format detection
    
    @model_validator(mode='after')
    def validate_audio_field(self):
        """Ensure at least one audio field is provided"""
        if not self.audio and not self.audio_base64:
            raise ValueError("Either 'audio' or 'audio_base64' field must be provided")
        return self
    
    def get_audio_data(self) -> str:
        """Get audio data from either field name"""
        return self.audio or self.audio_base64 or ""


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
    
    Supports: MP3, M4A, FLAC, OGG, AAC, WMA, WAV, MP4, 3GP, etc.
    
    Requires: FFmpeg must be installed on the system
    """
    try:
        # Detect format from file extension
        file_ext = Path(input_path).suffix.lower()
        
        logger.info(f"🔄 [CONVERT] Starting conversion: {input_path} (format: {file_ext})")
        logger.info(f"   [CONVERT] Output path: {output_path}")
        
        # Check if input file exists
        if not os.path.exists(input_path):
            logger.error(f"   [CONVERT] ❌ Input file does not exist: {input_path}")
            raise FileNotFoundError(f"Input file does not exist: {input_path}")
        
        # Get file size for logging
        file_size = os.path.getsize(input_path)
        logger.info(f"   [CONVERT] Input file size: {file_size} bytes")
        
        # Read and log file header
        with open(input_path, 'rb') as f:
            header_bytes = f.read(16)
            header_hex = ' '.join(f'{b:02x}' for b in header_bytes)
            logger.info(f"   [CONVERT] Input file header (hex): {header_hex}")
            logger.info(f"   [CONVERT] Input file header (raw): {header_bytes}")
        
        # Map extensions to pydub format names
        format_map = {
            '.wav': 'wav',
            '.mp3': 'mp3',
            '.m4a': 'm4a',
            '.mp4': 'm4a',  # MP4 audio is usually M4A
            '.flac': 'flac',
            '.ogg': 'ogg',
            '.aac': 'aac',
            '.wma': 'wma',
            '.3gp': '3gp',
        }
        
        # Get format, default to auto-detect if unknown
        audio_format = format_map.get(file_ext, None)
        logger.info(f"   [CONVERT] Detected format: {audio_format or 'auto-detect'}")
        
        # Load audio file using pydub
        try:
            logger.info(f"   [CONVERT] Attempting to load audio file...")
            if audio_format:
                if audio_format == 'wav':
                    logger.info(f"   [CONVERT] Loading as WAV...")
                    audio = AudioSegment.from_wav(input_path)
                elif audio_format == 'mp3':
                    logger.info(f"   [CONVERT] Loading as MP3...")
                    audio = AudioSegment.from_mp3(input_path)
                elif audio_format == 'ogg':
                    logger.info(f"   [CONVERT] Loading as OGG...")
                    audio = AudioSegment.from_ogg(input_path)
                else:
                    # Use from_file for formats like m4a, flac, aac, etc.
                    logger.info(f"   [CONVERT] Loading as {audio_format.upper()} using from_file()...")
                    audio = AudioSegment.from_file(input_path, format=audio_format)
            else:
                # Auto-detect format (pydub will try to detect)
                logger.info(f"   [CONVERT] Auto-detecting format...")
                audio = AudioSegment.from_file(input_path)
            logger.info(f"   [CONVERT] ✅ Audio loaded successfully")
        except Exception as load_error:
            error_msg = str(load_error)
            logger.error(f"   [CONVERT] ❌ Failed to load audio file: {error_msg}")
            logger.error(f"   [CONVERT] Full traceback: {traceback.format_exc()}")
            if 'ffmpeg' in error_msg.lower() or 'not found' in error_msg.lower():
                raise ValueError(
                    f"FFmpeg is required for audio conversion but was not found. "
                    f"Install it with: sudo apt-get install ffmpeg (Ubuntu/Debian) or "
                    f"brew install ffmpeg (macOS). Original error: {error_msg}"
                ) from load_error
            raise ValueError(f"Failed to load audio file: {error_msg}") from load_error
        
        logger.info(f"   [CONVERT] ✅ Audio loaded: {len(audio)}ms, {audio.frame_rate}Hz, {audio.channels} channels")
        
        # Export as WAV with proper settings for wav2vec2
        # Set to 16kHz mono (wav2vec2 requirement)
        logger.info(f"   [CONVERT] Setting frame rate to {TARGET_SAMPLE_RATE}Hz and converting to mono...")
        audio = audio.set_frame_rate(TARGET_SAMPLE_RATE)
        audio = audio.set_channels(1)  # Convert to mono
        
        # Export as WAV (PCM 16-bit)
        try:
            logger.info(f"   [CONVERT] Exporting to WAV format: {output_path}")
            logger.info(f"   [CONVERT] Using FFmpeg parameters: ['-acodec', 'pcm_s16le']")
            audio.export(
                output_path,
                format='wav',
                parameters=['-acodec', 'pcm_s16le']  # Ensure 16-bit PCM
            )
            logger.info(f"   [CONVERT] ✅ Export completed")
        except Exception as export_error:
            error_msg = str(export_error)
            logger.error(f"   [CONVERT] ❌ Failed to export WAV file: {error_msg}")
            logger.error(f"   [CONVERT] Full traceback: {traceback.format_exc()}")
            if 'ffmpeg' in error_msg.lower() or 'not found' in error_msg.lower():
                raise ValueError(
                    f"FFmpeg is required for audio export but was not found. "
                    f"Install it with: sudo apt-get install ffmpeg. Original error: {error_msg}"
                ) from export_error
            raise ValueError(f"Failed to export WAV file: {error_msg}") from export_error
        
        # Verify the output file exists and has correct header
        if not os.path.exists(output_path):
            logger.error(f"   [CONVERT] ❌ Output file was not created: {output_path}")
            raise ValueError(f"Conversion failed: output file was not created at {output_path}")
        
        output_size = os.path.getsize(output_path)
        logger.info(f"   [CONVERT] Output file size: {output_size} bytes")
        
        # Verify WAV header
        logger.info(f"   [CONVERT] Verifying WAV header...")
        with open(output_path, 'rb') as f:
            header = f.read(4)
            header_hex = ' '.join(f'{b:02x}' for b in header)
            logger.info(f"   [CONVERT] Output file header (hex): {header_hex}")
            logger.info(f"   [CONVERT] Output file header (raw): {header}")
            if header not in [b'RIFF', b'RIFX']:
                logger.error(f"   [CONVERT] ❌ Invalid WAV header! Expected RIFF or RIFX, got: {header}")
                raise ValueError(
                    f"Conversion failed: output file doesn't have WAV header. "
                    f"Got: {header} (expected RIFF or RIFX). "
                    f"This usually means FFmpeg conversion failed."
                )
            logger.info(f"   [CONVERT] ✅ Valid WAV header confirmed")
        
        logger.info(f"   [CONVERT] ✅ Successfully converted to WAV: {output_path}")
        return output_path
    except Exception as e:
        logger.error(f"❌ [CONVERT] Error converting audio to WAV: {e}")
        logger.error(f"   [CONVERT] Input file: {input_path}")
        logger.error(f"   [CONVERT] Output file: {output_path}")
        logger.error(f"   [CONVERT] Full traceback: {traceback.format_exc()}")
        # Re-raise with more context
        raise


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
    original_file_path = audio_file_path
    converted_file_path = None
    is_wav = False
    
    try:
        # Check if file is already WAV by reading first bytes
        file_ext = Path(audio_file_path).suffix.lower()
        logger.info(f"[PREPROCESS] Processing audio file: {audio_file_path} (extension: {file_ext})")
        
        # Check file exists and get size
        if os.path.exists(audio_file_path):
            file_size = os.path.getsize(audio_file_path)
            logger.info(f"[PREPROCESS] File size: {file_size} bytes")
        else:
            logger.error(f"[PREPROCESS] ❌ File does not exist: {audio_file_path}")
            raise FileNotFoundError(f"Audio file not found: {audio_file_path}")
        
        try:
            logger.info(f"[PREPROCESS] Reading file header...")
            with open(audio_file_path, 'rb') as f:
                header = f.read(4)
                header_hex = ' '.join(f'{b:02x}' for b in header)
                logger.info(f"[PREPROCESS] File header (hex): {header_hex}")
                logger.info(f"[PREPROCESS] File header (raw): {header}")
                if header == b'RIFF' or header == b'RIFX':
                    is_wav = True
                    logger.info(f"[PREPROCESS] ✅ File is already WAV format (RIFF/RIFX header detected)")
                else:
                    logger.info(f"[PREPROCESS] File is NOT WAV format (header: {header})")
        except Exception as e:
            logger.warning(f"[PREPROCESS] ⚠️  Could not read file header: {e}")
            logger.warning(f"[PREPROCESS] Full traceback: {traceback.format_exc()}")
            is_wav = False
        
        # ALWAYS convert if extension is not .wav, regardless of header check
        # This ensures M4A, MP3, etc. are always converted
        should_convert = False
        
        if file_ext:
            # If we have an extension, check if it's WAV
            if file_ext != '.wav':
                should_convert = True
                logger.info(f"[PREPROCESS] File extension '{file_ext}' indicates non-WAV format, will convert")
            else:
                logger.info(f"[PREPROCESS] File extension is .wav")
        elif not is_wav:
            # No extension but header check says it's not WAV
            should_convert = True
            logger.info(f"[PREPROCESS] Header check indicates non-WAV format, will convert")
        else:
            # Extension is .wav and header check passed
            should_convert = False
            logger.info(f"[PREPROCESS] File appears to be WAV format, skipping conversion")
        
        # Convert if needed
        if should_convert:
            logger.info(f"[PREPROCESS] 🔄 Converting {file_ext or 'unknown format'} file to WAV format...")
            
            # Create temporary WAV file
            with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as temp_wav:
                converted_file_path = temp_wav.name
            logger.info(f"[PREPROCESS] Created temp WAV file: {converted_file_path}")
            
            try:
                # Convert to WAV
                logger.info(f"[PREPROCESS] Calling convert_audio_to_wav({audio_file_path}, {converted_file_path})")
                convert_audio_to_wav(audio_file_path, converted_file_path)
                
                # Verify conversion succeeded by checking the output file exists
                logger.info(f"[PREPROCESS] Verifying converted file exists...")
                if not os.path.exists(converted_file_path):
                    logger.error(f"[PREPROCESS] ❌ Conversion failed: output file was not created")
                    raise ValueError("Conversion failed: output file was not created")
                
                # Verify it's a valid WAV file by checking header
                logger.info(f"[PREPROCESS] Verifying converted file has valid WAV header...")
                with open(converted_file_path, 'rb') as f:
                    wav_header = f.read(4)
                    wav_header_hex = ' '.join(f'{b:02x}' for b in wav_header)
                    logger.info(f"[PREPROCESS] Converted file header (hex): {wav_header_hex}")
                    logger.info(f"[PREPROCESS] Converted file header (raw): {wav_header}")
                    if wav_header not in [b'RIFF', b'RIFX']:
                        logger.error(f"[PREPROCESS] ❌ Invalid WAV header in converted file!")
                        raise ValueError(
                            f"Conversion failed: output file is not a valid WAV. "
                            f"Header: {wav_header} (expected RIFF or RIFX). "
                            f"This usually means FFmpeg conversion failed."
                        )
                    logger.info(f"[PREPROCESS] ✅ Valid WAV header confirmed in converted file")
                
                # Use the converted file
                audio_file_path = converted_file_path
                logger.info(f"[PREPROCESS] ✅ Conversion successful, using: {audio_file_path}")
            except Exception as e:
                # Clean up temp file if conversion failed
                if converted_file_path and os.path.exists(converted_file_path):
                    try:
                        os.unlink(converted_file_path)
                        logger.info(f"[PREPROCESS] Cleaned up failed conversion temp file")
                    except:
                        pass
                error_msg = f"Audio conversion failed: {str(e)}"
                logger.error(f"[PREPROCESS] ❌ {error_msg}")
                logger.error(f"[PREPROCESS] Full traceback: {traceback.format_exc()}")
                logger.error(f"[PREPROCESS] This usually means FFmpeg is not installed or not in PATH")
                logger.error(f"[PREPROCESS] Install FFmpeg: sudo apt-get install ffmpeg (Ubuntu/Debian)")
                logger.error(f"[PREPROCESS] Or: brew install ffmpeg (macOS)")
                raise ValueError(error_msg) from e
        else:
            logger.info(f"[PREPROCESS] ✅ File is already WAV format, no conversion needed")
        
        # Load audio file using scipy (now guaranteed to be WAV)
        try:
            logger.info(f"[PREPROCESS] Reading WAV file with scipy.wavfile.read(): {audio_file_path}")
            # Double-check header before reading
            with open(audio_file_path, 'rb') as f:
                final_header = f.read(4)
                logger.info(f"[PREPROCESS] Final file header before scipy read: {final_header}")
            sr, audio = wavfile.read(audio_file_path)
            logger.info(f"[PREPROCESS] ✅ Loaded WAV file: {len(audio)} samples at {sr}Hz")
        except Exception as e:
            error_msg = str(e)
            logger.error(f"[PREPROCESS] ❌ Failed to read WAV file with scipy: {error_msg}")
            logger.error(f"[PREPROCESS] Full traceback: {traceback.format_exc()}")
            # If the error mentions RIFF/RIFX, it means the file wasn't converted properly
            if 'RIFF' in error_msg or 'RIFX' in error_msg:
                logger.error(f"[PREPROCESS] This is the exact error the user is seeing!")
                raise ValueError(
                    f"File format error - conversion may have failed. "
                    f"Original error: {error_msg}. "
                    f"Please ensure FFmpeg is installed: sudo apt-get install ffmpeg"
                ) from e
            raise ValueError(f"Failed to read WAV file: {error_msg}") from e

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
        logger.error(f"[PREPROCESS] ❌ Error preprocessing audio: {e}")
        logger.error(f"[PREPROCESS] Full traceback: {traceback.format_exc()}")
        raise e
    finally:
        # Clean up converted WAV file if it was temporary
        if converted_file_path and converted_file_path != original_file_path:
            if os.path.exists(converted_file_path):
                try:
                    os.unlink(converted_file_path)
                    logger.info(f"[PREPROCESS] Cleaned up temporary WAV file: {converted_file_path}")
                except Exception as cleanup_error:
                    logger.warning(f"[PREPROCESS] Could not clean up temp file: {cleanup_error}")


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
    """Load model on startup and check dependencies"""
    # Check if FFmpeg is available (required for audio conversion)
    try:
        import subprocess
        result = subprocess.run(
            ['ffmpeg', '-version'],
            capture_output=True,
            timeout=5
        )
        if result.returncode == 0:
            logger.info("✅ FFmpeg is available for audio conversion")
            logger.info(f"   FFmpeg version: {result.stdout.split(chr(10))[0]}")
        else:
            logger.warning("⚠️  WARNING: FFmpeg check failed. Audio conversion may not work.")
            logger.warning("   Install FFmpeg: sudo apt-get install ffmpeg")
    except FileNotFoundError:
        logger.error("⚠️  WARNING: FFmpeg is NOT installed or not in PATH")
        logger.error("   Audio format conversion (M4A, MP3, etc.) will fail!")
        logger.error("   Install FFmpeg: sudo apt-get install ffmpeg")
    except Exception as e:
        logger.warning(f"⚠️  WARNING: Could not check FFmpeg: {e}")
    
    # Load model
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
    Accepts any audio format and converts to WAV automatically
    """
    start_time = asyncio.get_event_loop().time()
    logger.info("=" * 80)
    logger.info("[TRANSCRIBE] New transcription request received")
    logger.info("=" * 80)

    try:
        # Get file extension from filename or content-type
        file_extension = None
        
        # Try to get from filename first
        if audio.filename:
            file_extension = Path(audio.filename).suffix.lower()
            logger.info(f"[TRANSCRIBE] Detected extension from filename: {file_extension}")
        
        # If no extension in filename, try content-type
        if not file_extension and audio.content_type:
            content_type_map = {
                'audio/wav': '.wav',
                'audio/mpeg': '.mp3',
                'audio/mp4': '.m4a',
                'audio/x-m4a': '.m4a',
                'audio/flac': '.flac',
                'audio/ogg': '.ogg',
                'audio/aac': '.aac',
            }
            file_extension = content_type_map.get(audio.content_type)
            if file_extension:
                logger.info(f"[TRANSCRIBE] Detected extension from content-type '{audio.content_type}': {file_extension}")
        
        # Default to .m4a if still unknown (common for mobile recordings)
        if not file_extension:
            file_extension = ".m4a"
            logger.info(f"[TRANSCRIBE] No extension detected, defaulting to: {file_extension}")
        
        # Log the incoming file format
        logger.info(f"[TRANSCRIBE] 📥 Received audio file: {audio.filename or 'unnamed'}")
        logger.info(f"[TRANSCRIBE]    Extension: {file_extension}")
        logger.info(f"[TRANSCRIBE]    Content-Type: {audio.content_type}")
        
        # Accept any format - we'll convert to WAV if needed
        # No need to restrict here since conversion handles all formats

        # Save uploaded file temporarily with detected extension
        logger.info(f"[TRANSCRIBE] Saving uploaded file to temp location...")
        with tempfile.NamedTemporaryFile(
            delete=False, suffix=file_extension
        ) as temp_file:
            content = await audio.read()
            temp_file.write(content)
            temp_path = temp_file.name
        
        logger.info(f"[TRANSCRIBE] 💾 Saved uploaded file to: {temp_path} ({len(content)} bytes)")
        
        # Log first few bytes of the file
        if len(content) >= 16:
            header_bytes = content[:16]
            header_hex = ' '.join(f'{b:02x}' for b in header_bytes)
            logger.info(f"[TRANSCRIBE] File header (first 16 bytes, hex): {header_hex}")
            logger.info(f"[TRANSCRIBE] File header (first 16 bytes, raw): {header_bytes}")

        try:
            # Load and preprocess audio (this will convert to WAV if needed)
            logger.info(f"[TRANSCRIBE] Starting audio preprocessing...")
            audio_array, duration = preprocess_audio(temp_path)
            logger.info(f"[TRANSCRIBE] ✅ Audio preprocessing completed: {duration:.2f}s duration")

            # Transcribe audio
            logger.info(f"[TRANSCRIBE] Starting transcription...")
            transcription, confidence = transcribe_audio(audio_array)
            logger.info(f"[TRANSCRIBE] ✅ Transcription completed: '{transcription[:50]}...'")

            processing_time = asyncio.get_event_loop().time() - start_time
            logger.info(f"[TRANSCRIBE] Total processing time: {processing_time:.2f}s")

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
                try:
                    os.unlink(temp_path)
                    logger.info(f"[TRANSCRIBE] Cleaned up temp file: {temp_path}")
                except Exception as cleanup_error:
                    logger.warning(f"[TRANSCRIBE] Could not clean up temp file: {cleanup_error}")

    except ValueError as e:
        logger.error(f"[TRANSCRIBE] ❌ ValueError: {str(e)}")
        logger.error(f"[TRANSCRIBE] Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=400, detail=str(e)) from e
    except Exception as e:
        logger.error(f"[TRANSCRIBE] ❌ Exception: {str(e)}")
        logger.error(f"[TRANSCRIBE] Full traceback: {traceback.format_exc()}")
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
        # Get audio data from request (supports both 'audio' and 'audio_base64' field names)
        audio_base64_str = request.get_audio_data()
        if not audio_base64_str:
            raise HTTPException(
                status_code=400, detail="Missing 'audio' or 'audio_base64' field in request"
            )
        
        # Decode base64 audio
        try:
            audio_data = base64.b64decode(audio_base64_str)
        except Exception as e:
            raise HTTPException(
                status_code=400, detail=f"Invalid base64 audio data: {str(e)}"
            ) from e

        # Detect audio format from filename, content_type, or file header
        # Also check for file_extension field (from frontend)
        file_ext = request.file_extension  # New field from frontend
        if file_ext and not file_ext.startswith('.'):
            file_ext = f".{file_ext}"
        
        # Try filename first
        if not file_ext and request.filename:
            file_ext = Path(request.filename).suffix.lower() or ".m4a"
        
        # Try content_type second
        if not file_ext and request.content_type:
            content_type_map = {
                'audio/wav': '.wav',
                'audio/mpeg': '.mp3',
                'audio/mp4': '.m4a',
                'audio/x-m4a': '.m4a',
                'audio/flac': '.flac',
                'audio/ogg': '.ogg',
                'audio/aac': '.aac',
            }
            file_ext = content_type_map.get(request.content_type, '.m4a')
        
        # Fallback: detect from file header
        if not file_ext:
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
                elif header[:4] == b'\x00\x00\x00':  # M4A/MP4 often starts with this
                    file_ext = ".m4a"
                else:
                    file_ext = ".m4a"  # Default fallback
            else:
                file_ext = ".m4a"  # Default fallback
        
        # Ensure extension is in supported formats (or allow conversion)
        # Note: We'll convert any format, so we don't need to restrict here
        if file_ext not in SUPPORTED_FORMATS:
            print(f"Warning: {file_ext} not in SUPPORTED_FORMATS, but will attempt conversion")
        
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
