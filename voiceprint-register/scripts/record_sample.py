#!/usr/bin/env python3
"""录制声纹注册样本"""
import argparse, wave, struct, sys
from pathlib import Path

try:
    import pyaudio
    HAS_PYAUDIO = True
except ImportError:
    HAS_PYAUDIO = False

SAMPLE_DIR = Path(__file__).parent.parent / "references" / "voiceprints" / "samples"
SAMPLE_DIR.mkdir(parents=True, exist_ok=True)
RATE, CHANNELS, CHUNK = 16000, 1, 1024
PROMPTS = [
    "今天的会议议题是季度业务回顾",
    "本周销售目标完成情况请汇报",
    "下一项议程，产品规划",
]

def record_one(filepath, duration=5):
    if not HAS_PYAUDIO:
        print("  [mock] pyaudio 未安装，写入静音文件", file=sys.stderr)
        with wave.open(str(filepath), "w") as wf:
            wf.setnchannels(CHANNELS); wf.setsampwidth(2); wf.setframerate(RATE)
            wf.writeframes(struct.pack(f"{RATE*duration}h", *([0]*RATE*duration)))
        return
    p = pyaudio.PyAudio()
    s = p.open(format=pyaudio.paInt16, channels=CHANNELS,
               rate=RATE, input=True, frames_per_buffer=CHUNK)
    frames = []
    print(f"  录制 {duration} 秒...", end="", flush=True)
    for _ in range(int(RATE/CHUNK*duration)):
        frames.append(s.read(CHUNK, exception_on_overflow=False))
    s.stop_stream(); s.close(); p.terminate()
    print(" 完成")
    with wave.open(str(filepath), "w") as wf:
        wf.setnchannels(CHANNELS); wf.setsampwidth(2); wf.setframerate(RATE)
        wf.writeframes(b"".join(frames))

def record_samples(person_id, n=3, duration=5):
    d = SAMPLE_DIR / person_id
    d.mkdir(exist_ok=True)
    for i in range(n):
        print(f"\n[样本 {i+1}/{n}] 请说：「{PROMPTS[i%len(PROMPTS)]}」")
        input("  按 Enter 开始录制...")
        record_one(d / f"sample_{i+1}.wav", duration)
    print(f"\n{person_id} 录制完成，共 {n} 个样本")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--person_id", required=True)
    p.add_argument("--samples",   type=int, default=3)
    p.add_argument("--duration",  type=int, default=5)
    args = p.parse_args()
    record_samples(args.person_id, args.samples, args.duration)
