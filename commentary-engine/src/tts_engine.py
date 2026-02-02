"""
TTS Engine

Handles text-to-speech for spoken commentary.
"""

import asyncio
from typing import Optional


class TTSEngine:
    """Text-to-speech engine for commentary."""

    def __init__(self, engine: str = "pyttsx3"):
        self.engine_type = engine
        self.engine = None
        self._init_engine()

    def _init_engine(self):
        """Initialize the TTS engine."""
        if self.engine_type == "pyttsx3":
            try:
                import pyttsx3
                self.engine = pyttsx3.init()
                # Configure voice
                self.engine.setProperty("rate", 175)  # Speed
                self.engine.setProperty("volume", 0.9)

                # Try to use a more natural voice if available
                voices = self.engine.getProperty("voices")
                for voice in voices:
                    if "english" in voice.name.lower():
                        self.engine.setProperty("voice", voice.id)
                        break
            except Exception as e:
                print(f"Failed to initialize pyttsx3: {e}")
                self.engine = None

    async def speak(self, text: str) -> bool:
        """Speak text asynchronously."""
        if not self.engine:
            return False

        # Run TTS in thread pool to not block
        loop = asyncio.get_event_loop()
        try:
            await loop.run_in_executor(None, self._speak_sync, text)
            return True
        except Exception as e:
            print(f"TTS error: {e}")
            return False

    def _speak_sync(self, text: str):
        """Synchronous speak method."""
        if self.engine:
            self.engine.say(text)
            self.engine.runAndWait()

    def stop(self):
        """Stop any ongoing speech."""
        if self.engine:
            try:
                self.engine.stop()
            except:
                pass


class GTTSEngine:
    """Google TTS alternative (requires internet)."""

    def __init__(self):
        self.available = False
        try:
            from gtts import gTTS
            import pygame
            pygame.mixer.init()
            self.available = True
        except ImportError:
            print("gtts or pygame not available")

    async def speak(self, text: str) -> bool:
        """Speak using Google TTS."""
        if not self.available:
            return False

        try:
            from gtts import gTTS
            import pygame
            import io

            # Generate audio
            tts = gTTS(text=text, lang="en")
            audio_buffer = io.BytesIO()
            tts.write_to_fp(audio_buffer)
            audio_buffer.seek(0)

            # Play audio
            pygame.mixer.music.load(audio_buffer)
            pygame.mixer.music.play()

            # Wait for playback
            while pygame.mixer.music.get_busy():
                await asyncio.sleep(0.1)

            return True
        except Exception as e:
            print(f"gTTS error: {e}")
            return False
