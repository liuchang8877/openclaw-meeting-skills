#!/usr/bin/env python3
"""Mock 数据源 — 开发测试用"""

def query(params):
    q   = params.get("query", "")
    lvl = params.get("caller_level", 4)
    return {
        "data_type": "mock",
        "query":     q,
        "result":    f"（mock）{q} 的查询结果：本月完成率 78%，环比上月提升 12%",
        "level":     lvl,
    }
