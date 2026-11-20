"""AIDM local browser chat, served through the existing Meta FastAPI app.

Usage: from aidm.web import create_chat_app
Change Log: 2026-11-20 DAVOS — AIDM-DES-014.1 browser composition.
"""

from .app import create_chat_app

__all__ = ["create_chat_app"]
