#!/usr/bin/env python3
"""推送会议状态到 Pi Zero 显示屏"""
import argparse, json, urllib.request, urllib.error, os, sys, time

PI_URL = os.environ.get("PI_DISPLAY_URL", "http://192.168.1.101:8080/display")
STATUS_MAP = {
    "meeting_start": "active", "meeting_end": "idle",
    "speaker_change": "active", "agenda_next": "active",
    "action_added": "active",   "idle": "idle",
}

def push(event, **kwargs):
    payload = {"status": STATUS_MAP.get(event,"active"),
               "time":   time.strftime("%H:%M"), **kwargs}
    data = json.dumps(payload, ensure_ascii=False).encode()
    req  = urllib.request.Request(PI_URL, data=data,
                                  headers={"Content-Type":"application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=3) as r:
            print(f"[display] OK: {event}"); return True
    except Exception as e:
        print(f"[display] Pi 离线: {e}", file=sys.stderr); return False

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--event",          required=True)
    p.add_argument("--speaker_name",   default="")
    p.add_argument("--agenda_item",    default="")
    p.add_argument("--agenda_index",   type=int, default=0)
    p.add_argument("--agenda_total",   type=int, default=0)
    p.add_argument("--action_count",   type=int, default=0)
    p.add_argument("--decision_count", type=int, default=0)
    args = p.parse_args()
    push(args.event, speaker=args.speaker_name, agenda_item=args.agenda_item,
         agenda_index=args.agenda_index, agenda_total=args.agenda_total,
         action_count=args.action_count, decision_count=args.decision_count)
