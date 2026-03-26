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
