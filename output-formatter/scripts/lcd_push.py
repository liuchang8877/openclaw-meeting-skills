#!/usr/bin/env python3
"""Pi Zero LCD 推送"""
import argparse, json, urllib.request, urllib.error, os, sys

PI_URL = os.environ.get("PI_DISPLAY_URL", "http://192.168.1.101:8080/display")

def push(content_type, text, speaker=""):
    payload = {"type": content_type, "text": text[:80], "speaker": speaker}
    data    = json.dumps(payload).encode()
    req     = urllib.request.Request(PI_URL, data=data,
                                     headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=3) as r:
            print(f"[lcd] OK: {r.status}")
    except Exception as e:
        print(f"[lcd] 推送失败（Pi 可能离线）: {e}", file=sys.stderr)

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--type",    default="query_result")
    p.add_argument("--text",    required=True)
    p.add_argument("--speaker", default="")
    args = p.parse_args()
    push(args.type, args.text, args.speaker)
