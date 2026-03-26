#!/usr/bin/env python3
"""会议状态机"""
import json, argparse, sys
from pathlib import Path
from datetime import datetime

SESSION_DIR = Path.home() / ".openclaw" / "meeting_sessions"
SESSION_DIR.mkdir(parents=True, exist_ok=True)
CURRENT     = SESSION_DIR / "current.json"

def load():
    return json.loads(CURRENT.read_text()) if CURRENT.exists() else {"state": "idle"}

def save(s):
    CURRENT.write_text(json.dumps(s, ensure_ascii=False, indent=2))

def start(caller_id, agenda):
    s = {"state": "active", "started_at": datetime.now().isoformat(),
         "started_by": caller_id, "agenda": agenda, "current_agenda": 0,
         "utterances": [], "decisions": [], "actions": [], "risks": []}
    save(s)
    return {"ok": True, "agenda_count": len(agenda), "first_item": agenda[0] if agenda else ""}

def log_utterance(speaker_id, speaker_name, text, timestamp):
    s = load()
    if s.get("state") != "active":
        return {"ok": False, "reason": "会议未进行中"}
    entry = {"speaker_id": speaker_id, "speaker_name": speaker_name,
             "text": text, "timestamp": timestamp,
             "agenda_index": s.get("current_agenda", 0), "tags": []}
    for tag, words in {
        "[DECISION]": ["决定", "确定", "同意", "批准", "通过"],
        "[ACTION]":   ["负责", "跟进", "截止", "完成", "提交"],
        "[RISK]":     ["风险", "担心", "问题", "阻塞", "卡点"],
    }.items():
        if any(w in text for w in words):
            entry["tags"].append(tag)
            key = {"[DECISION]": "decisions", "[ACTION]": "actions", "[RISK]": "risks"}[tag]
            s[key].append(entry)
    s["utterances"].append(entry)
    save(s)
    return {"ok": True, "tags": entry["tags"]}

def next_agenda():
    s    = load()
    idx  = s.get("current_agenda", 0) + 1
    agenda = s.get("agenda", [])
    if idx >= len(agenda):
        return {"ok": False, "reason": "已是最后一项议程"}
    s["current_agenda"] = idx
    save(s)
    return {"ok": True, "current": idx, "item": agenda[idx], "total": len(agenda)}

def close_meeting():
    s = load()
    s["state"]    = "closing"
    s["ended_at"] = datetime.now().isoformat()
    save(s)
    date_str = datetime.now().strftime("%Y-%m-%d")
    topic    = (s.get("agenda") or ["未命名"])[0][:10]
    archive  = SESSION_DIR / f"{date_str}-{topic}.json"
    archive.write_text(json.dumps(s, ensure_ascii=False, indent=2))
    return {"ok": True, "session": str(archive),
            "decisions": len(s.get("decisions", [])),
            "actions":   len(s.get("actions", []))}

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--action", required=True,
                   choices=["start","log","next_agenda","close","status"])
    p.add_argument("--caller_id",    default="")
    p.add_argument("--agenda",       default="[]")
    p.add_argument("--speaker_id",   default="")
    p.add_argument("--speaker_name", default="")
    p.add_argument("--text",         default="")
    p.add_argument("--timestamp",    default=datetime.now().isoformat())
    args = p.parse_args()
    if   args.action == "start":      r = start(args.caller_id, json.loads(args.agenda))
    elif args.action == "log":        r = log_utterance(args.speaker_id, args.speaker_name, args.text, args.timestamp)
    elif args.action == "next_agenda":r = next_agenda()
    elif args.action == "close":      r = close_meeting()
    elif args.action == "status":     r = load()
    print(json.dumps(r, ensure_ascii=False, indent=2))
