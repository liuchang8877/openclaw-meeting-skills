#!/usr/bin/env python3
"""会议纪要生成器 — DSTE 四层"""
import json, argparse
from pathlib import Path
from datetime import datetime

def generate(session_file, output_dir):
    session    = json.loads(Path(session_file).read_text())
    date_str   = datetime.now().strftime("%Y-%m-%d")
    topic      = (session.get("agenda") or ["未命名会议"])[0]
    output     = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    decisions  = session.get("decisions", [])
    actions    = session.get("actions", [])
    risks      = session.get("risks", [])

    # 原始存档
    raw_path = output / f"{date_str}-raw.json"
    raw_path.write_text(json.dumps({
        "meta": {"date": date_str, "topic": topic,
                 "started_at": session.get("started_at"),
                 "ended_at":   session.get("ended_at"),
                 "agenda":     session.get("agenda", [])},
        "utterances": session.get("utterances", []),
        "decisions": decisions, "actions": actions, "risks": risks,
    }, ensure_ascii=False, indent=2))

    # D层：战略摘要
    d_path = output / f"{date_str}-D-strategy.json"
    d_path.write_text(json.dumps({
        "layer": "D-战略", "for": "CEO", "date": date_str, "topic": topic,
        "decisions_count": len(decisions), "actions_count": len(actions),
        "risk_count": len(risks),
        "key_decisions": [d["text"][:60] for d in decisions[:3]],
        "key_risks":     [r["text"][:60] for r in risks[:3]],
    }, ensure_ascii=False, indent=2))

    # E层：个人行动项
    person_actions = {}
    for a in actions:
        sid = a.get("speaker_id", "unknown")
        person_actions.setdefault(sid, []).append(
            {"text": a["text"], "timestamp": a["timestamp"]})
    e_path = output / f"{date_str}-E-execution.json"
    e_path.write_text(json.dumps({
        "layer": "E-执行", "date": date_str, "person_actions": person_actions,
    }, ensure_ascii=False, indent=2))

    print(json.dumps({"ok": True, "raw": str(raw_path),
                      "d_layer": str(d_path), "e_layer": str(e_path),
                      "decisions": len(decisions), "actions": len(actions)},
                     ensure_ascii=False, indent=2))

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--session_file", required=True)
    p.add_argument("--output_dir",   default="./minutes")
    args = p.parse_args()
    generate(args.session_file, args.output_dir)
