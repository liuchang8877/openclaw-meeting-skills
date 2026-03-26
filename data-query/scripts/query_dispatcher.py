#!/usr/bin/env python3
"""数据查询分发器"""
import json, argparse, sys, importlib.util
from pathlib import Path

def load_sources():
    path = Path(__file__).parent.parent / "references" / "data_sources.json"
    return json.loads(path.read_text())

def dispatch(data_type, query, time_range, caller_level):
    sources = load_sources()
    source  = sources.get(data_type)
    if not source:
        return {"error": f"数据类型 {data_type} 未注册"}
    if not source.get("enabled", False):
        return {"error": f"数据源 {data_type} 未启用"}
    if caller_level not in source.get("allowed_levels", []):
        return {"error": "权限不足"}
    script_name = source["script"]
    module_path = Path(__file__).parent / f"{script_name}.py"
    if not module_path.exists():
        return {"error": f"查询脚本 {script_name}.py 不存在，请实现后放入 scripts/ 目录"}
    spec   = importlib.util.spec_from_file_location(script_name, module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.query({"query": query, "time_range": time_range,
                         "caller_level": caller_level, "config": source.get("config", {})})

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_type",    required=True)
    parser.add_argument("--query",        required=True)
    parser.add_argument("--time_range",   default="")
    parser.add_argument("--caller_level", type=int, default=4)
    args   = parser.parse_args()
    result = dispatch(args.data_type, args.query, args.time_range, args.caller_level)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0 if "error" not in result else 1)
