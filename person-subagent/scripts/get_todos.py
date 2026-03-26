#!/usr/bin/env python3
"""拉取指定人员的待办数据"""
import json, argparse, os, sys
from pathlib import Path

FEISHU_APP_ID     = os.environ.get("FEISHU_APP_ID", "")
FEISHU_APP_SECRET = os.environ.get("FEISHU_APP_SECRET", "")

def get_todos(person_id):
    # 从 meeting-router 的 persons.json 读取人员配置
    persons_path = Path(__file__).parent.parent.parent / "meeting-router" / "references" / "persons.json"
    if not persons_path.exists():
        persons_path = Path(__file__).parent.parent / "references" / "persons.json"
    persons = json.loads(persons_path.read_text())
    person  = persons.get(person_id)
    if not person:
        return []
    source = person.get("todo_source", "mock")
    if source == "feishu":
        return _fetch_feishu(person["todo_space_id"])
    return _mock_todos(person["name"])

def _fetch_feishu(space_id):
    try:
        import urllib.request
        url  = "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal"
        body = json.dumps({"app_id": FEISHU_APP_ID, "app_secret": FEISHU_APP_SECRET}).encode()
        req  = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req) as r:
            token = json.loads(r.read())["tenant_access_token"]
        req2 = urllib.request.Request(
            "https://open.feishu.cn/open-apis/task/v2/tasks?page_size=20",
            headers={"Authorization": f"Bearer {token}"}
        )
        with urllib.request.urlopen(req2) as r:
            items = json.loads(r.read()).get("data", {}).get("items", [])
        return [{"title": t.get("summary",""), "status": t.get("status",""), "progress": "未知"} for t in items]
    except Exception as e:
        print(f"[warn] feishu error: {e}", file=sys.stderr)
        return []

def _mock_todos(name):
    return [
        {"title": f"{name}待办A：季度规划文档", "status": "进行中", "progress": "60%"},
        {"title": f"{name}待办B：跨部门协作会",  "status": "待开始", "progress": "0%"},
        {"title": f"{name}待办C：上周行动项",    "status": "已完成", "progress": "100%"},
    ]

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--person_id", required=True)
    args = parser.parse_args()
    print(json.dumps(get_todos(args.person_id), ensure_ascii=False, indent=2))
