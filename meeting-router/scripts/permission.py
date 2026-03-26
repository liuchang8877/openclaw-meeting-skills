#!/usr/bin/env python3
"""权限校验脚本"""
import json, argparse, sys
from pathlib import Path

PERMISSION_MATRIX = {
    (1, "person_query"): [1, 2, 3, 4],
    (1, "data_query"):   [1, 2, 3, 4],
    (2, "person_query"): [2, 3, 4],
    (2, "data_query"):   [2, 3, 4],
    (3, "person_query"): [3, 4],
    (3, "data_query"):   [3, 4],
    (4, "person_query"): [4],
    (4, "data_query"):   [4],
}
for level in [1, 2, 3, 4]:
    PERMISSION_MATRIX[(level, "meeting_control")] = "all"
    PERMISSION_MATRIX[(level, "broadcast")]       = "all"
    PERMISSION_MATRIX[(level, "register")]        = "all"

def load_persons():
    path = Path(__file__).parent.parent / "references" / "persons.json"
    return json.loads(path.read_text())

def check_permission(caller_id, intent, target_id=None):
    persons      = load_persons()
    caller       = persons.get(caller_id)
    if not caller:
        return {"allowed": False, "reason": f"调用方 {caller_id} 未注册"}
    caller_level  = caller["dste_level"]
    allowed_levels = PERMISSION_MATRIX.get((caller_level, intent))
    if allowed_levels is None:
        return {"allowed": False, "reason": "未知意图类型"}
    if allowed_levels == "all" or target_id is None:
        return {"allowed": True}
    target = persons.get(target_id)
    if not target:
        return {"allowed": False, "reason": f"目标人员 {target_id} 未注册"}
    if target["dste_level"] in allowed_levels:
        return {"allowed": True}
    return {"allowed": False, "reason": f"您没有权限查询 {target['name']} 的数据"}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--caller_id",  required=True)
    parser.add_argument("--intent",     required=True)
    parser.add_argument("--target_id",  default=None)
    args   = parser.parse_args()
    result = check_permission(args.caller_id, args.intent, args.target_id)
    print(json.dumps(result, ensure_ascii=False))
    sys.exit(0 if result["allowed"] else 1)
