#!/usr/bin/env python3
"""语音播报 — mac say TTS"""
import argparse, subprocess, sys, os

VOICE = os.environ.get("MAC_SAY_VOICE", "Tingting")

def speak(text, voice=VOICE):
    if not text.strip():
        return
    if len(text) > 120:
        text = text[:117] + "..."
    try:
        subprocess.run(["say", "-v", voice, text], check=True, timeout=30)
        print(f"[voice] OK: {text[:40]}...")
    except FileNotFoundError:
        print("[voice] say 命令不存在，跳过", file=sys.stderr)
    except Exception as e:
        print(f"[voice] 失败: {e}", file=sys.stderr)

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--text",  required=True)
    p.add_argument("--voice", default=VOICE)
    args = p.parse_args()
    speak(args.text, args.voice)
