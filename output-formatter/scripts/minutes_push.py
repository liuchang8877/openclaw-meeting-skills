#!/usr/bin/env python3
"""纪要分发 — 会议结束后推送到各渠道（stub，按需实现）"""
import argparse, json
from pathlib import Path
from datetime import datetime

def push(minutes_dir, date):
    d = Path(minutes_dir)
    if not d.exists():
        print(f"[minutes] 目录不存在: {minutes_dir}")
        return
    files = list(d.glob(f"{date}*.json"))
    print(f"[minutes] 找到 {len(files)} 份纪要文件")
    for f in files:
        print(f"  {f.name}")
    # TODO: 接入飞书群机器人 / 邮件推送

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--minutes_dir", default="./minutes")
    p.add_argument("--date",        default=datetime.now().strftime("%Y-%m-%d"))
    args = p.parse_args()
    push(args.minutes_dir, args.date)
