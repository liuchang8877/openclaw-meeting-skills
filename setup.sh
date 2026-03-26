#!/bin/bash
# OpenClaw 会议助手 Skill 一键初始化脚本
# 用法：bash setup.sh
# 在 ~/openclaw-meeting-skills 目录下执行

set -e
BASE=$(pwd)
echo "==> 初始化目录: $BASE"

# ─────────────────────────────────────────────
# 创建目录结构
# ─────────────────────────────────────────────
for skill in meeting-router person-subagent data-query \
             meeting-orchestrator output-formatter \
             voiceprint-register display-sync; do
  mkdir -p "$BASE/$skill/scripts"
  mkdir -p "$BASE/$skill/references"
done
mkdir -p "$BASE/voiceprint-register/references/voiceprints/samples"

echo "==> 目录结构创建完成"

# ─────────────────────────────────────────────
# README.md
# ─────────────────────────────────────────────
cat > "$BASE/README.md" << 'HEREDOC'
# OpenClaw 会议助手 Skill 库

企业会议语音助手的完整 OpenClaw Skill 集合。

## Skill 列表

| Skill | 职责 |
|---|---|
| `meeting-router` | 总控入口，意图识别 + 权限校验 + 路由分发 |
| `person-subagent` | 人员代理，查询个人待办/进度/状态 |
| `data-query` | 数据查询网关，订单/OKR/销售数据 |
| `meeting-orchestrator` | 会议编排，议程/纪要/行动项 |
| `output-formatter` | 多路输出，语音/LCD/飞书 |
| `voiceprint-register` | 声纹注册与实时识别 |
| `display-sync` | Pi Zero LCD 屏幕同步 |

## 硬件

- ESP32-S3 AI 智能音箱板（微雪）— 会议收音+播报
- Raspberry Pi Zero 2W + WhisPlay — 待办显示屏
- Mac Mini — 计算主机，运行所有服务

## 环境变量

```bash
FEISHU_APP_ID=cli_xxxxxxxx
FEISHU_APP_SECRET=xxxxxxxx
PI_DISPLAY_URL=http://192.168.1.101:8080/display
MAC_SAY_VOICE=Tingting
HF_TOKEN=hf_xxxxxxxx   # pyannote 声纹识别
```

## 快速上线

```bash
# 1. 注册声纹
openclaw "注册声纹"

# 2. 开始会议
openclaw "开始会议，议程：产品规划，销售回顾"

# 3. 查询数据
openclaw "查一下李总监本周待办"

# 4. 结束会议
openclaw "结束会议"
```
HEREDOC

# ─────────────────────────────────────────────
# .gitignore
# ─────────────────────────────────────────────
cat > "$BASE/.gitignore" << 'HEREDOC'
*.pyc
__pycache__/
.env
references/voiceprints/*.npy
references/voiceprints/samples/
HEREDOC

# ═════════════════════════════════════════════
# SKILL 1: meeting-router
# ═════════════════════════════════════════════
cat > "$BASE/meeting-router/SKILL.md" << 'HEREDOC'
---
name: meeting-router
description: >-
  企业会议语音助手的总控入口。当收到带有说话人身份的会议指令时触发。
  触发场景：会议语音输入、查询某人待办/进度/订单、发起/结束会议、
  议程管理、查询业务数据、会议纪要生成。
  所有会议相关指令必须经过此 skill 进行权限校验和路由分发。
trigger_keywords:
  - 开始会议
  - 结束会议
  - 查一下
  - 待办
  - 进度
  - 订单
  - 议程
  - 纪要
  - 会议
tools:
  - Bash
  - Read
  - Write
---

# 会议路由总控

## 角色定位

你是企业会议语音助手的总控路由器。所有会议相关指令都由你统一接收、
校验权限，再分发给对应的处理模块。你不直接回答业务问题，只负责
「理解意图 → 校验权限 → 路由分发 → 整合结果」四步。

## 输入格式

每条会议话语以如下 JSON 格式传入：

```json
{
  "speaker_id": "zhang_ceo",
  "speaker_name": "张总",
  "dste_level": 1,
  "text": "李总监本周待办完成了多少"
}
```

如果输入不包含 speaker_id，先调用 `scripts/route.py --identify`
从声纹库匹配说话人，再继续处理。

## 执行步骤

### 第一步：读取人员配置

```bash
cat references/persons.json
```

确认 speaker_id 是否在已注册人员列表中。未注册则回复：
「请先完成声纹注册，说"注册声纹"开始」，终止流程。

### 第二步：意图分类

根据 text 内容判断意图，分为以下类型：

| 意图类型 | 关键词示例 | 路由目标 |
|---|---|---|
| `meeting_control` | 开始会议、结束会议、下一个议程 | meeting-orchestrator skill |
| `person_query` | 某人的待办、进度、状态 | person-subagent skill |
| `data_query` | 订单、销售额、OKR、业务数据 | data-query skill |
| `broadcast` | 告诉大家、通知所有人 | output-formatter skill |
| `register` | 注册声纹、添加成员 | 内联处理 |

### 第三步：权限校验

```bash
python3 scripts/permission.py \
  --caller_id {speaker_id} \
  --intent {意图类型} \
  --target_id {目标人员id，如有}
```

返回 `allowed: false` 时直接回复权限不足原因，终止。

### 第四步：路由分发

根据意图调用对应 skill，传递完整上下文。

### 第五步：整合回复

将返回结果格式化为适合语音播报的简短文本：
- 控制在 3 句话以内
- 数字用中文读法
- 避免 Markdown 格式符号

## 错误处理

| 情况 | 处理方式 |
|---|---|
| speaker_id 未识别 | 提示注册声纹 |
| 权限不足 | 说明原因，不透露被限制的数据 |
| 目标 skill 返回错误 | 简短告知，建议稍后重试 |
| 意图不明确 | 反问澄清，最多问一次 |

## 注意事项

- 永远不要在语音回复中念出 JSON 或技术错误信息
- 会议进行中所有路由结果同时推送给 meeting-orchestrator 记录
HEREDOC

cat > "$BASE/meeting-router/scripts/permission.py" << 'HEREDOC'
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
HEREDOC

cat > "$BASE/meeting-router/references/persons.json" << 'HEREDOC'
{
  "zhang_ceo": {
    "name": "张总",
    "role": "CEO",
    "dste_level": 1,
    "department": "all",
    "todo_source": "mock",
    "todo_space_id": "YOUR_FEISHU_SPACE_ID",
    "voiceprint_registered": false
  },
  "li_director": {
    "name": "李总监",
    "role": "产品总监",
    "dste_level": 2,
    "department": "product",
    "todo_source": "mock",
    "todo_space_id": "YOUR_FEISHU_SPACE_ID",
    "voiceprint_registered": false
  },
  "wang_director": {
    "name": "王总监",
    "role": "销售总监",
    "dste_level": 2,
    "department": "sales",
    "todo_source": "mock",
    "todo_space_id": "YOUR_FEISHU_SPACE_ID",
    "voiceprint_registered": false
  },
  "zhao_engineer": {
    "name": "赵工",
    "role": "工程负责人",
    "dste_level": 3,
    "department": "engineering",
    "todo_source": "mock",
    "todo_space_id": "YOUR_FEISHU_SPACE_ID",
    "voiceprint_registered": false
  }
}
HEREDOC

# ═════════════════════════════════════════════
# SKILL 2: person-subagent
# ═════════════════════════════════════════════
cat > "$BASE/person-subagent/SKILL.md" << 'HEREDOC'
---
name: person-subagent
description: >-
  代表某个会议成员发言或查询其数据。当 meeting-router 路由来
  person_query 意图时触发。负责以目标人员的角色视角回答问题，
  包括个人待办、本周进度、OKR 完成情况、工作重点。
  也负责未参会成员的异步补充发言。
trigger_keywords:
  - 待办
  - 进度
  - 完成情况
  - 本周工作
  - 代表
  - 他的
  - 她的
tools:
  - Bash
  - Read
  - Write
---

# 人员 SubAgent

## 角色定位

你是某个会议成员的 AI 代理。被调用时：
1. 加载该成员的角色 prompt 和待办数据
2. 用该成员的视角和语气回答问题
3. 输出适合语音播报的简短文本

## 输入格式

```json
{
  "target_person_id": "li_director",
  "query": "本周待办完成了多少",
  "caller_dste_level": 1,
  "context": "当前讨论议题：Q3产品规划"
}
```

## 执行步骤

### 第一步：加载角色配置和待办数据

```bash
python3 scripts/get_todos.py --person_id {target_person_id}
```

```bash
cat references/role_prompts.json
```

### 第二步：根据调用方权限过滤数据

| 调用方级别 | 可见数据范围 |
|---|---|
| L1 (CEO) | 全部待办 + 进度数字 + 风险项 |
| L2 (同级总监) | 跨部门协作项 + 整体进度 |
| L3 (经理) | 本部门相关项 |
| L4 (员工本人) | 个人全部待办 |

### 第三步：用角色视角生成回答

以目标人员身份组织回答，遵循其 role_prompts 中的关注重点。

### 第四步：格式化为语音播报

- 控制在 3 句话以内
- 以「{人名}这边：」开头
- 数字用中文

## 异步补充模式

当 context 包含 `mode: async_supplement` 时：
1. 读取会议摘要
2. 从该成员角色视角提取相关事项
3. 生成「如果我在场会说的话」
4. 标注为「{人名}（异步补充）：」
HEREDOC

cat > "$BASE/person-subagent/scripts/get_todos.py" << 'HEREDOC'
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
HEREDOC

cat > "$BASE/person-subagent/references/role_prompts.json" << 'HEREDOC'
{
  "zhang_ceo": {
    "perspective": "战略视角",
    "focus": ["跨部门协作风险", "季度目标偏差", "战略落地情况"],
    "voice_style": "简洁有力，关注结果",
    "intro": "从战略层面来看"
  },
  "li_director": {
    "perspective": "产品视角",
    "focus": ["功能交付进度", "研发资源瓶颈", "用户反馈"],
    "voice_style": "数据导向，关注交付",
    "intro": "产品这边"
  },
  "wang_director": {
    "perspective": "销售视角",
    "focus": ["订单转化率", "客户跟进状态", "销售目标达成"],
    "voice_style": "结果导向，关注数字",
    "intro": "销售这边"
  },
  "zhao_engineer": {
    "perspective": "技术视角",
    "focus": ["技术债务", "研发进度", "系统稳定性"],
    "voice_style": "严谨务实，关注风险",
    "intro": "技术这边"
  }
}
HEREDOC

# ═════════════════════════════════════════════
# SKILL 3: data-query
# ═════════════════════════════════════════════
cat > "$BASE/data-query/SKILL.md" << 'HEREDOC'
---
name: data-query
description: >-
  企业数据统一查询入口。当 meeting-router 路由来 data_query 意图时触发。
  支持查询待办进度、订单数据、OKR 完成率、销售额等业务数据。
  自动根据调用方权限过滤返回内容，格式化为语音播报文本。
  新增数据源只需在 references/data_sources.json 注册即可。
trigger_keywords:
  - 订单
  - 销售额
  - OKR
  - 完成率
  - 业务数据
  - 查询
  - 数据
tools:
  - Bash
  - Read
  - Write
---

# 数据查询 Skill

## 角色定位

企业数据的统一查询网关。接收结构化查询请求，
调用对应数据源脚本，权限过滤后格式化输出。

## 输入格式

```json
{
  "data_type": "order",
  "query": "本月新签订单金额",
  "time_range": "2026-03",
  "caller_id": "zhang_ceo",
  "caller_dste_level": 1
}
```

## 执行步骤

### 第一步：读取数据源注册表

```bash
cat references/data_sources.json
```

### 第二步：调用查询脚本

```bash
python3 scripts/query_dispatcher.py \
  --data_type {data_type} \
  --query "{query}" \
  --time_range "{time_range}" \
  --caller_level {caller_dste_level}
```

### 第三步：权限过滤 + 数字格式化

数字格式：`1234567` → `一百二十三万`，`42%` → `百分之四十二`

输出以「[数据类型]方面：」开头，2句话以内。

## 注意事项

- 查询失败说「暂时无法获取数据，请稍后重试」
- 数据为空说「暂无相关记录」
- 新增数据源：在 data_sources.json 注册 + 在 scripts/ 放对应 .py 文件
HEREDOC

cat > "$BASE/data-query/scripts/query_dispatcher.py" << 'HEREDOC'
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
HEREDOC

cat > "$BASE/data-query/scripts/mock_query.py" << 'HEREDOC'
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
HEREDOC

cat > "$BASE/data-query/references/data_sources.json" << 'HEREDOC'
{
  "todo": {
    "enabled": true,
    "description": "个人和团队待办任务",
    "script": "mock_query",
    "allowed_levels": [1, 2, 3, 4],
    "config": {"table_type": "todo", "space_id": "YOUR_FEISHU_SPACE_ID"}
  },
  "order": {
    "enabled": true,
    "description": "销售订单数据",
    "script": "mock_query",
    "allowed_levels": [1, 2],
    "config": {"crm_endpoint": "http://localhost:9000/api/orders"}
  },
  "okr": {
    "enabled": true,
    "description": "OKR 目标和关键结果进度",
    "script": "mock_query",
    "allowed_levels": [1, 2, 3],
    "config": {"table_type": "okr", "space_id": "YOUR_OKR_SPACE_ID"}
  },
  "sales": {
    "enabled": false,
    "description": "销售额汇总（待接入真实数据源）",
    "script": "mock_query",
    "allowed_levels": [1, 2],
    "config": {}
  }
}
HEREDOC

# ═════════════════════════════════════════════
# SKILL 4: meeting-orchestrator
# ═════════════════════════════════════════════
cat > "$BASE/meeting-orchestrator/SKILL.md" << 'HEREDOC'
---
name: meeting-orchestrator
description: >-
  企业会议生命周期管理。负责会议开始/结束、议程推进、发言记录、
  决策和行动项识别、会议纪要生成、DSTE分级报告推送。
  由 meeting-router 在 meeting_control 意图时调用，
  同时被动接收所有会议发言用于纪要记录。
trigger_keywords:
  - 开始会议
  - 结束会议
  - 下一个议程
  - 记录决策
  - 生成纪要
  - 会议状态
tools:
  - Bash
  - Read
  - Write
---

# 会议编排 Skill

## 角色定位

会议的 AI 主持人和记录员。维护整场会议状态，
识别决策/行动项/风险，会后生成结构化纪要并按 DSTE 层级分发。

## 会议状态机

```
idle → active → paused → closing → idle
```

## 控制指令

| command | 触发词 | 动作 |
|---|---|---|
| `start_meeting` | 开始会议 | 初始化会话，加载议程 |
| `end_meeting` | 结束会议 | 触发纪要生成 |
| `next_agenda` | 下一个议程 | 切换到下一项 |
| `pause_meeting` | 暂停一下 | 状态 → paused |
| `resume_meeting` | 继续会议 | 状态 → active |

## 执行步骤

### 开始会议

```bash
python3 scripts/session.py --action start \
  --caller_id {caller_id} \
  --agenda "{agenda_json}"
```

播报：「会议开始，本次议程共 N 项，第一项：{agenda[0]}，请开始」

### 发言记录（被动接收每条话语）

```bash
python3 scripts/session.py --action log \
  --speaker_id {speaker_id} \
  --speaker_name {speaker_name} \
  --text "{text}" \
  --timestamp "{timestamp}"
```

自动标记：[DECISION] [ACTION] [RISK]

### 结束会议

```bash
python3 scripts/session.py --action close
python3 scripts/minutes_writer.py --session_file {path} --output_dir ./minutes/
```

播报：「会议结束，共 N 项决策，M 个行动项，纪要已生成」

## DSTE 纪要分层

| 层级 | 收件人 | 内容重点 | 字数 |
|---|---|---|---|
| D-战略 | CEO | 战略对齐、跨部门风险 | 100字 |
| S-策略 | 总监 | 部门决策、协作行动项 | 80字 |
| T-战术 | 经理 | 执行任务、截止日 | 按任务数 |
| E-执行 | 员工 | 本人行动项 | ≤5条 |
HEREDOC

cat > "$BASE/meeting-orchestrator/scripts/session.py" << 'HEREDOC'
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
HEREDOC

cat > "$BASE/meeting-orchestrator/scripts/minutes_writer.py" << 'HEREDOC'
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
HEREDOC

cat > "$BASE/meeting-orchestrator/references/agenda_template.json" << 'HEREDOC'
{
  "default": ["战略回顾", "部门进度汇报", "跨部门协作事项", "行动项确认"],
  "weekly":  ["上周行动项复盘", "本周重点", "风险与阻塞", "下周计划"],
  "monthly": ["月度目标达成", "OKR 进度", "资源需求", "下月规划"]
}
HEREDOC

# ═════════════════════════════════════════════
# SKILL 5: output-formatter
# ═════════════════════════════════════════════
cat > "$BASE/output-formatter/SKILL.md" << 'HEREDOC'
---
name: output-formatter
description: >-
  会议助手的统一输出格式化器。将各 skill 的返回结果
  格式化后分发到正确渠道：语音播报、LCD显示屏、纪要文件、待办系统。
  支持 realtime（实时播报）和 batch（会议后批量分发）两种模式。
trigger_keywords:
  - 播报
  - 推送
  - 显示
  - 通知
  - 分发
tools:
  - Bash
  - Read
  - Write
---

# 输出格式化 Skill

## 输入格式

```json
{
  "mode": "realtime",
  "content_type": "query_result",
  "content": "李总监本周完成3项待办，剩余2项",
  "channels": ["voice", "lcd"],
  "priority": "normal"
}
```

## 执行步骤

### 实时模式

```bash
# 数字中文化
python3 scripts/number_format.py --text "{content}"

# 语音播报
python3 scripts/voice_output.py --text "{formatted}"

# LCD 推送
python3 scripts/lcd_push.py --type "query_result" --text "{formatted}"
```

### 批量模式（会议结束）

```bash
python3 scripts/minutes_push.py --minutes_dir "./minutes/" --date "{today}"
```

## 渠道规则

| 内容类型 | 语音 | LCD | 飞书 |
|---|---|---|---|
| 查询结果 | ✓主要 | ✓辅助 | — |
| 决策记录 | ✓播报 | ✓常驻 | — |
| 行动项 | ✓播报 | ✓常驻 | ✓会后 |
| 会议纪要 | — | ✓摘要 | ✓完整 |

## 语音规范

- 不超过 3 句，15 秒内念完
- LCD 不超过 4 行，每行 ≤ 8 汉字
- 推送失败独立容错，不影响其他渠道
HEREDOC

cat > "$BASE/output-formatter/scripts/voice_output.py" << 'HEREDOC'
#!/usr/bin/env python3
"""语音播报 — mac say TTS"""
import argparse, subprocess, sys, os

VOICE = os.environ.get("MAC_SAY_VOICE", "Tingting")

def speak(text, voice=VOICE):
    if not text.strip():
        return
    if len(text) > 120:
        text = text[:117] + "..."
    try:
        subprocess.run(["say", "-v", voice, text], check=True, timeout=30)
        print(f"[voice] OK: {text[:40]}...")
    except FileNotFoundError:
        print("[voice] say 命令不存在，跳过", file=sys.stderr)
    except Exception as e:
        print(f"[voice] 失败: {e}", file=sys.stderr)

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--text",  required=True)
    p.add_argument("--voice", default=VOICE)
    args = p.parse_args()
    speak(args.text, args.voice)
HEREDOC

cat > "$BASE/output-formatter/scripts/lcd_push.py" << 'HEREDOC'
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
HEREDOC

cat > "$BASE/output-formatter/scripts/number_format.py" << 'HEREDOC'
#!/usr/bin/env python3
"""数字格式化 — 阿拉伯数字 → 中文口语"""
import re, argparse

CN = ["零","一","二","三","四","五","六","七","八","九"]
UNITS = ["","十","百","千","万","十万","百万","千万","亿"]

def int_to_cn(n):
    if n == 0: return "零"
    if n < 0:  return "负" + int_to_cn(-n)
    res, u = "", 0
    while n > 0:
        d = n % 10
        if d:   res = CN[d] + UNITS[u] + res
        elif res and res[0] != "零": res = "零" + res
        n //= 10; u += 1
    if res.startswith("一十"): res = res[1:]
    return res

def fmt_pct(m):
    v = float(m.group(1))
    i = int(v); d = round((v - i) * 10)
    return f"百分之{int_to_cn(i)}" + (f"点{CN[d]}" if d else "")

def fmt_num(m):
    n = int(m.group(0).replace(",",""))
    if n >= 100000000: return int_to_cn(n//100000000) + "亿"
    if n >= 10000:     return int_to_cn(n//10000) + "万"
    return int_to_cn(n)

def convert(text):
    text = re.sub(r"([\d.]+)%", fmt_pct, text)
    text = re.sub(r"\d[\d,]*", fmt_num, text)
    return text

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--text", required=True)
    args = p.parse_args()
    print(convert(args.text))
HEREDOC

cat > "$BASE/output-formatter/scripts/minutes_push.py" << 'HEREDOC'
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
HEREDOC

cat > "$BASE/output-formatter/references/output_channels.json" << 'HEREDOC'
{
  "voice":   {"enabled": true,  "script": "voice_output.py"},
  "lcd":     {"enabled": true,  "script": "lcd_push.py", "url_env": "PI_DISPLAY_URL"},
  "feishu":  {"enabled": false, "note": "会议结束后批量推送，需配置 FEISHU_WEBHOOK_URL"},
  "minutes": {"enabled": true,  "script": "minutes_push.py"}
}
HEREDOC

# ═════════════════════════════════════════════
# SKILL 6: voiceprint-register
# ═════════════════════════════════════════════
cat > "$BASE/voiceprint-register/SKILL.md" << 'HEREDOC'
---
name: voiceprint-register
description: >-
  会议成员声纹注册和实时识别。会议开始前为每位成员注册声纹，
  会议中自动识别说话人身份，返回 speaker_id 供 meeting-router 使用。
  触发场景：「注册声纹」、「添加成员声纹」、「识别说话人」。
trigger_keywords:
  - 注册声纹
  - 声纹注册
  - 添加成员
  - 识别说话人
  - 我是谁
tools:
  - Bash
  - Read
  - Write
---

# 声纹注册与识别 Skill

## 角色定位

负责会议成员的身份绑定。通过声纹向量实现「这段音频是谁说的」。

## 注册流程（会议前一次性）

1. 用户说「注册声纹」
2. 询问要注册哪位成员
3. 提示该成员说 3 句注册语
4. 录制并建立声纹向量

### 执行命令

```bash
# 录制样本
python3 scripts/record_sample.py --person_id {person_id} --samples 3

# 构建声纹向量
python3 scripts/build_voiceprint.py --person_id {person_id}
```

注册语提示词：
- 「今天的会议议题是季度业务回顾」
- 「本周销售目标完成情况请汇报」
- 「下一项议程，产品规划」

## 识别流程（会议中自动）

```bash
python3 scripts/match_speaker.py \
  --audio_file {audio_path} \
  --threshold 0.75
```

返回格式：
```json
{"matched": true, "speaker_id": "zhang_ceo", "confidence": 0.91}
```

## 注意事项

- 声纹文件存储本地，不上传云端
- 置信度低于 0.75 时标记「未知说话人」，不强行猜测
- 需要安装：`pip3 install pyannote.audio pyaudio numpy`
HEREDOC

cat > "$BASE/voiceprint-register/scripts/record_sample.py" << 'HEREDOC'
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
HEREDOC

cat > "$BASE/voiceprint-register/scripts/build_voiceprint.py" << 'HEREDOC'
#!/usr/bin/env python3
"""构建声纹向量"""
import argparse, json, sys
from pathlib import Path

SAMPLE_DIR     = Path(__file__).parent.parent / "references" / "voiceprints" / "samples"
VOICEPRINT_DIR = Path(__file__).parent.parent / "references" / "voiceprints"

def build(person_id):
    samples = list((SAMPLE_DIR / person_id).glob("*.wav")) if (SAMPLE_DIR / person_id).exists() else []
    if not samples:
        print(json.dumps({"ok": False, "error": "未找到样本，请先录制"}))
        sys.exit(1)
    try:
        from pyannote.audio import Model, Inference
        import numpy as np
        model = Model.from_pretrained("pyannote/embedding", use_auth_token=True)
        inf   = Inference(model, window="whole")
        embs  = [inf(str(f)) for f in samples]
        mean  = np.mean(embs, axis=0)
        out   = VOICEPRINT_DIR / f"{person_id}.npy"
        np.save(str(out), mean)
        print(json.dumps({"ok": True, "person_id": person_id,
                          "samples": len(embs), "saved": str(out)}, ensure_ascii=False))
    except ImportError:
        import numpy as np
        mock = np.random.randn(512).astype("float32")
        out  = VOICEPRINT_DIR / f"{person_id}.npy"
        np.save(str(out), mock)
        print(json.dumps({"ok": True, "person_id": person_id,
                          "mode": "mock（pyannote 未安装）", "saved": str(out)},
                         ensure_ascii=False))

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--person_id", required=True)
    args = p.parse_args()
    build(args.person_id)
HEREDOC

cat > "$BASE/voiceprint-register/scripts/match_speaker.py" << 'HEREDOC'
#!/usr/bin/env python3
"""实时声纹匹配"""
import argparse, json, sys
from pathlib import Path

VOICEPRINT_DIR = Path(__file__).parent.parent / "references" / "voiceprints"

def match(audio_file, threshold=0.75):
    vp_files = list(VOICEPRINT_DIR.glob("*.npy"))
    if not vp_files:
        return {"matched": False, "reason": "声纹库为空，请先注册"}
    try:
        from pyannote.audio import Model, Inference
        import numpy as np
        model = Model.from_pretrained("pyannote/embedding", use_auth_token=True)
        inf   = Inference(model, window="whole")
        query = inf(audio_file)
        best_id, best_score = None, -1.0
        for vp in vp_files:
            reg   = np.load(str(vp))
            score = float(np.dot(query, reg) / (np.linalg.norm(query)*np.linalg.norm(reg)+1e-8))
            if score > best_score:
                best_score = score; best_id = vp.stem
        if best_score >= threshold:
            return {"matched": True, "speaker_id": best_id, "confidence": round(best_score, 3)}
        return {"matched": False, "speaker_id": None, "confidence": round(best_score, 3),
                "reason": "置信度不足"}
    except ImportError:
        fallback = vp_files[0].stem if vp_files else None
        return {"matched": bool(fallback), "speaker_id": fallback,
                "confidence": 0.99, "mode": "mock（pyannote 未安装）"}

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--audio_file", required=True)
    p.add_argument("--threshold",  type=float, default=0.75)
    args = p.parse_args()
    r = match(args.audio_file, args.threshold)
    print(json.dumps(r, ensure_ascii=False, indent=2))
    sys.exit(0 if r["matched"] else 1)
HEREDOC

# ═════════════════════════════════════════════
# SKILL 7: display-sync
# ═════════════════════════════════════════════
cat > "$BASE/display-sync/SKILL.md" << 'HEREDOC'
---
name: display-sync
description: >-
  Pi Zero 2W + WhisPlay 1.54寸 LCD 屏幕的实时状态同步。
  会议进行中推送当前说话人、议程进度、待办摘要到屏幕。
  Pi Zero 上运行 HTTP 服务，Mac Mini 通过局域网推送数据。
trigger_keywords:
  - 显示屏
  - 屏幕更新
  - 推送状态
  - 同步显示
tools:
  - Bash
  - Read
  - Write
---

# 显示屏同步 Skill

## 架构

- Pi Zero 2W：运行 `scripts/pi_server.py`，监听 8080 端口
- Mac Mini：调用 `scripts/push_state.py`，推送会议状态

## 部署 Pi Zero 端

```bash
# 安装依赖（在 Pi Zero 上）
pip3 install flask pillow --break-system-packages

# 传输服务脚本
scp scripts/pi_server.py pi@{PI_IP}:/home/pi/display_server.py

# 开机自启
ssh pi@{PI_IP} "echo '@reboot python3 /home/pi/display_server.py' | crontab -"
ssh pi@{PI_IP} "nohup python3 /home/pi/display_server.py &"
```

## Mac Mini 端调用

```bash
python3 scripts/push_state.py \
  --event "speaker_change" \
  --speaker_name "张总" \
  --agenda_item "Q3战略回顾" \
  --agenda_index 1 \
  --agenda_total 4 \
  --action_count 3
```

## 屏幕布局（240×240）

```
┌──────────────────────┐
│ 当前说话人（大字橙色）│
├──────────────────────┤
│ 议程 N/M  具体内容   │
├──────────────────────┤
│ 决策 N    行动项 M   │
├──────────────────────┤
│ 14:32    会议进行中  │
└──────────────────────┘
```

## 事件类型

| event | 触发时机 |
|---|---|
| `meeting_start` | 会议开始 |
| `speaker_change` | 说话人切换 |
| `agenda_next` | 切换议程 |
| `action_added` | 新增行动项 |
| `meeting_end` | 会议结束 |
| `idle` | 无会议，显示今日待办 |
HEREDOC

cat > "$BASE/display-sync/scripts/pi_server.py" << 'HEREDOC'
#!/usr/bin/env python3
"""Pi Zero LCD 显示服务 — 部署到 Pi Zero 2W 上运行"""
import json, threading, time
from http.server import HTTPServer, BaseHTTPRequestHandler

try:
    from PIL import Image, ImageDraw, ImageFont
    from luma.core.interface.serial import spi
    from luma.lcd.device import st7789
    HAS_DISPLAY = True
except ImportError:
    HAS_DISPLAY = False
    print("[warn] 显示库未安装，headless 模式")

STATE = {"speaker": "待机中", "agenda_item": "暂无议程",
         "agenda_index": 0, "agenda_total": 0,
         "action_count": 0, "decision_count": 0,
         "status": "idle", "time": ""}
LOCK = threading.Lock()

def render(state):
    if not HAS_DISPLAY:
        print(f"\n[LCD] {'='*22}")
        print(f"  发言: {state['speaker']}")
        print(f"  议程: {state['agenda_index']}/{state['agenda_total']} {state['agenda_item'][:12]}")
        print(f"  决策:{state['decision_count']} 行动:{state['action_count']}")
        print(f"  {state['time']}  {state['status']}")
        return
    img  = Image.new("RGB", (240, 240), (20, 20, 30))
    draw = ImageDraw.Draw(img)
    try:
        fl = ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-microhei.ttc", 32)
        fm = ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-microhei.ttc", 20)
        fs = ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-microhei.ttc", 16)
    except Exception:
        fl = fm = fs = ImageFont.load_default()
    draw.rectangle([0,0,240,70],   fill=(40,30,10))
    draw.text((10,8),  "当前发言",           font=fs, fill=(180,140,60))
    draw.text((10,30), state["speaker"][:6], font=fl, fill=(255,200,80))
    draw.rectangle([0,72,240,140],  fill=(25,25,40))
    draw.text((10,76), f"议程 {state['agenda_index']}/{state['agenda_total']}", font=fs, fill=(120,140,180))
    draw.text((10,96), state["agenda_item"][:12], font=fm, fill=(220,220,255))
    draw.rectangle([0,142,240,190], fill=(20,35,25))
    draw.text((10,148),  f"决策 {state['decision_count']}", font=fm, fill=(80,200,120))
    draw.text((130,148), f"行动 {state['action_count']}",   font=fm, fill=(80,180,220))
    sc = (100,220,100) if state["status"]=="active" else (160,160,160)
    draw.rectangle([0,192,240,240], fill=(15,15,20))
    draw.text((10,198),  state["time"],   font=fs, fill=(140,140,140))
    draw.text((110,198), state["status"], font=fs, fill=sc)
    try:
        serial = spi(port=0, device=0, gpio_DC=24, gpio_RST=25)
        device = st7789(serial, width=240, height=240, rotate=0)
        device.display(img)
    except Exception as e:
        print(f"[lcd] 写入失败: {e}")

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        n    = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n)
        try:
            data = json.loads(body)
            with LOCK:
                STATE.update({k: v for k, v in data.items() if k in STATE})
                STATE["time"] = time.strftime("%H:%M")
            render(STATE)
            self.send_response(200); self.end_headers()
            self.wfile.write(b'{"ok":true}')
        except Exception as e:
            self.send_response(500); self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())
    def log_message(self, *args): pass

def clock():
    while True:
        time.sleep(60)
        with LOCK: STATE["time"] = time.strftime("%H:%M")
        render(STATE)

if __name__ == "__main__":
    threading.Thread(target=clock, daemon=True).start()
    print("[display-server] 监听 :8080")
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
HEREDOC

cat > "$BASE/display-sync/scripts/push_state.py" << 'HEREDOC'
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
HEREDOC

cat > "$BASE/display-sync/references/display_layout.json" << 'HEREDOC'
{
  "resolution": "240x240",
  "rows": [
    {"id": "speaker",  "y_start": 0,   "y_end": 70,  "color": "orange", "font_size": 32, "label": "当前说话人"},
    {"id": "agenda",   "y_start": 72,  "y_end": 140, "color": "white",  "font_size": 20, "label": "议程进度"},
    {"id": "stats",    "y_start": 142, "y_end": 190, "color": "green",  "font_size": 20, "label": "决策/行动统计"},
    {"id": "status",   "y_start": 192, "y_end": 240, "color": "gray",   "font_size": 16, "label": "时间+会议状态"}
  ]
}
HEREDOC

# ═════════════════════════════════════════════
# .env.example
# ═════════════════════════════════════════════
cat > "$BASE/.env.example" << 'HEREDOC'
# 飞书开放平台
FEISHU_APP_ID=cli_xxxxxxxxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Pi Zero 显示屏地址（局域网）
PI_DISPLAY_URL=http://192.168.1.101:8080/display

# TTS 声音（mac say 内置）
MAC_SAY_VOICE=Tingting

# HuggingFace Token（pyannote 声纹识别需要）
HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# CRM 接口（如有）
CRM_API_KEY=xxxxxxxx
HEREDOC

# ─────────────────────────────────────────────
# Git 提交并推送
# ─────────────────────────────────────────────
echo ""
echo "==> 所有文件创建完成，准备提交..."

git add .
git commit -m "feat: 初始化 OpenClaw 会议助手 Skill 库

包含 7 个 skill：
- meeting-router：总控入口，意图识别+权限校验+路由分发
- person-subagent：人员代理，个人待办/进度查询
- data-query：数据查询网关，订单/OKR/销售
- meeting-orchestrator：会议编排，议程/纪要/行动项
- output-formatter：多路输出，语音/LCD/飞书
- voiceprint-register：声纹注册与实时识别
- display-sync：Pi Zero LCD 屏幕同步

硬件：ESP32-S3 音箱板 + Pi Zero 2W + Mac Mini"

echo ""
echo "==> 推送到 GitHub..."
gh repo create liuchang8877/openclaw-meeting-skills --public --source=. --push

echo ""
echo "✅ 完成！仓库地址：https://github.com/liuchang8877/openclaw-meeting-skills"
