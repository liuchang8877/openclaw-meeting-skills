# OpenClaw 会议助手 Skill 测试指南

> **给 OpenClaw 的说明**：本文档是可执行的测试手册。
> 当用户说「执行测试」或「跑一遍测试」时，请按照本文档的步骤依次执行，
> 对每个步骤输出「✅ 通过」或「❌ 失败：原因」，最终给出汇总报告。

---

## 前置检查

在开始任何测试前，先确认环境就绪：

```bash
# 检查 skill 目录是否存在
ls ~/.openclaw/skills/ | grep -E "meeting|person|data|output|voiceprint|display"
```

**期望**：看到以下 7 个目录：
- `meeting-router`
- `person-subagent`
- `data-query`
- `meeting-orchestrator`
- `output-formatter`
- `voiceprint-register`
- `display-sync`

```bash
# 检查 Python 版本
python3 --version
```

**期望**：Python 3.8 或以上

```bash
# 检查 persons.json 是否存在
cat ~/.openclaw/skills/meeting-router/references/persons.json
```

**期望**：输出包含 `zhang_ceo`、`li_director` 等人员配置的 JSON

---

## 模块一：权限校验测试

### T01 — CEO 查询总监（应通过）

```bash
python3 ~/.openclaw/skills/meeting-router/scripts/permission.py \
  --caller_id zhang_ceo \
  --intent person_query \
  --target_id li_director
```

**期望输出**：
```json
{"allowed": true}
```

---

### T02 — 员工查询 CEO（应拒绝）

```bash
python3 ~/.openclaw/skills/meeting-router/scripts/permission.py \
  --caller_id zhao_engineer \
  --intent person_query \
  --target_id zhang_ceo
```

**期望输出**：
```json
{"allowed": false, "reason": "您没有权限查询 张总 的数据"}
```

---

### T03 — 所有人可做会议控制

```bash
python3 ~/.openclaw/skills/meeting-router/scripts/permission.py \
  --caller_id zhao_engineer \
  --intent meeting_control
```

**期望输出**：
```json
{"allowed": true}
```

---

### T04 — 未注册人员查询（应拒绝）

```bash
python3 ~/.openclaw/skills/meeting-router/scripts/permission.py \
  --caller_id unknown_person \
  --intent person_query
```

**期望输出**：包含 `"allowed": false` 和说明原因的 `reason` 字段

---

## 模块二：人员数据查询测试

### T05 — 获取李总监 mock 待办

```bash
python3 ~/.openclaw/skills/person-subagent/scripts/get_todos.py \
  --person_id li_director
```

**期望输出**：包含 3 条待办任务的 JSON 数组，每条有 `title`、`status`、`progress` 字段

---

### T06 — 获取不存在人员的待办

```bash
python3 ~/.openclaw/skills/person-subagent/scripts/get_todos.py \
  --person_id nonexistent_person
```

**期望输出**：空数组 `[]`，不报错

---

## 模块三：数据查询分发测试

### T07 — 查询已启用数据源

```bash
python3 ~/.openclaw/skills/data-query/scripts/query_dispatcher.py \
  --data_type todo \
  --query "本周完成情况" \
  --caller_level 1
```

**期望**：返回包含 `result` 字段的 JSON，退出码 0

---

### T08 — 权限不足拒绝查询

```bash
python3 ~/.openclaw/skills/data-query/scripts/query_dispatcher.py \
  --data_type order \
  --query "本月订单" \
  --caller_level 4
```

**期望输出**：包含 `"error": "权限不足"` 的 JSON，退出码 1

---

### T09 — 查询未启用数据源

```bash
python3 ~/.openclaw/skills/data-query/scripts/query_dispatcher.py \
  --data_type sales \
  --query "销售额" \
  --caller_level 1
```

**期望输出**：包含 `"error": "数据源 sales 未启用"` 的 JSON

---

### T10 — 查询未注册数据源

```bash
python3 ~/.openclaw/skills/data-query/scripts/query_dispatcher.py \
  --data_type finance \
  --query "财务数据" \
  --caller_level 1
```

**期望输出**：包含 `"error": "数据类型 finance 未注册"` 的 JSON

---

## 模块四：会议状态机测试

### T11 — 开始会议

```bash
python3 ~/.openclaw/skills/meeting-orchestrator/scripts/session.py \
  --action start \
  --caller_id zhang_ceo \
  --agenda '["Q3战略回顾", "产品规划", "行动项确认"]'
```

**期望输出**：
```json
{
  "ok": true,
  "agenda_count": 3,
  "first_item": "Q3战略回顾"
}
```

---

### T12 — 记录普通发言（无标签）

```bash
python3 ~/.openclaw/skills/meeting-orchestrator/scripts/session.py \
  --action log \
  --speaker_id zhang_ceo \
  --speaker_name "张总" \
  --text "大家好，今天主要讨论三个议题" \
  --timestamp "2026-03-26T14:00:00"
```

**期望输出**：`"tags": []`（无标记）

---

### T13 — 记录包含行动项的发言

```bash
python3 ~/.openclaw/skills/meeting-orchestrator/scripts/session.py \
  --action log \
  --speaker_id zhang_ceo \
  --speaker_name "张总" \
  --text "Q3复购率目标定在40%，李总监负责跟进，截止下周五" \
  --timestamp "2026-03-26T14:05:00"
```

**期望输出**：`"tags"` 中包含 `"[ACTION]"`

---

### T14 — 记录包含决策的发言

```bash
python3 ~/.openclaw/skills/meeting-orchestrator/scripts/session.py \
  --action log \
  --speaker_id zhang_ceo \
  --speaker_name "张总" \
  --text "大家同意这个方案，正式决定Q3预算增加20%" \
  --timestamp "2026-03-26T14:10:00"
```

**期望输出**：`"tags"` 中包含 `"[DECISION]"`

---

### T15 — 切换议程

```bash
python3 ~/.openclaw/skills/meeting-orchestrator/scripts/session.py \
  --action next_agenda
```

**期望输出**：`"current": 1, "item": "产品规划"`

---

### T16 — 查看当前会议状态

```bash
python3 ~/.openclaw/skills/meeting-orchestrator/scripts/session.py \
  --action status
```

**期望输出**：包含 `"state": "active"`，`utterances` 数组中有之前记录的发言

---

### T17 — 结束会议

```bash
python3 ~/.openclaw/skills/meeting-orchestrator/scripts/session.py \
  --action close
```

**期望输出**：
```json
{
  "ok": true,
  "session": "~/.openclaw/meeting_sessions/2026-...-Q3战略回顾.json",
  "decisions": 1,
  "actions": 1
}
```

---

## 模块五：会议纪要生成测试

### T18 — 生成纪要文件

**先找到刚才生成的会话文件：**

```bash
ls ~/.openclaw/meeting_sessions/*.json | grep -v current
```

**然后生成纪要：**

```bash
SESSION_FILE=$(ls ~/.openclaw/meeting_sessions/*.json | grep -v current | tail -1)
python3 ~/.openclaw/skills/meeting-orchestrator/scripts/minutes_writer.py \
  --session_file "$SESSION_FILE" \
  --output_dir ~/meeting_minutes_test/
```

**期望**：命令成功执行，输出包含 `"ok": true`

---

### T19 — 验证纪要文件内容

```bash
ls ~/meeting_minutes_test/
```

**期望**：看到至少 3 个文件：
- `YYYY-MM-DD-raw.json`
- `YYYY-MM-DD-D-strategy.json`
- `YYYY-MM-DD-E-execution.json`

```bash
cat ~/meeting_minutes_test/*D-strategy.json
```

**期望**：包含 `"layer": "D-战略"`、`decisions_count`、`key_decisions` 字段

```bash
cat ~/meeting_minutes_test/*E-execution.json
```

**期望**：包含 `"layer": "E-执行"` 和 `person_actions` 字段，其中 `zhang_ceo` 下有行动项

---

## 模块六：输出格式化测试

### T20 — 数字中文化

```bash
python3 ~/.openclaw/skills/output-formatter/scripts/number_format.py \
  --text "本月完成率42%，订单金额1234567元，共3项行动"
```

**期望输出**：`本月完成率百分之四十二，订单金额一百二十三万元，共三项行动`

---

### T21 — 大数字转换

```bash
python3 ~/.openclaw/skills/output-formatter/scripts/number_format.py \
  --text "年度营收100000000元，增长15%"
```

**期望输出**：`年度营收一亿元，增长百分之十五`

---

### T22 — 语音播报

```bash
python3 ~/.openclaw/skills/output-formatter/scripts/voice_output.py \
  --text "会议助手测试，语音播报功能正常"
```

**期望**：Mac 说出这句话，终端打印 `[voice] OK: 会议助手测试...`

---

### T23 — LCD 推送（Pi 离线时应静默失败）

```bash
python3 ~/.openclaw/skills/output-formatter/scripts/lcd_push.py \
  --type "query_result" \
  --text "测试推送" \
  --speaker "张总"
```

**期望**：
- Pi 在线时：打印 `[lcd] OK: 200`
- Pi 离线时：打印警告但**不报错退出**，退出码 0

---

## 模块七：OpenClaw 端到端对话测试

> 以下测试在 OpenClaw 对话界面中执行。
> 如果 skill 没有自动触发，可以用「使用 {skill名} skill」前缀强制指定。

### T24 — 触发会议开始

在 OpenClaw 中输入：
```
开始会议，议程：产品规划，销售回顾，行动项确认
```

**期望**：
- 触发 `meeting-orchestrator` skill
- 回复包含「会议开始」和「三项」或「3项」
- 语音播报会议开始内容

---

### T25 — 触发人员待办查询

在 OpenClaw 中输入：
```
查一下李总监本周的待办进度
```

**期望**：
- 触发 `meeting-router` → `person-subagent`
- 权限校验通过（默认以 zhang_ceo 身份）
- 回复包含「李总监」和待办数据
- 语音播报查询结果

---

### T26 — 触发数据查询

在 OpenClaw 中输入：
```
本月订单完成情况怎么样
```

**期望**：
- 触发 `meeting-router` → `data-query`
- 回复包含订单相关数据（mock 数据）

---

### T27 — 触发权限拒绝

在 OpenClaw 中输入（模拟低权限查询）：
```
以赵工的身份查询张总的待办
```

**期望**：回复包含权限不足的提示，不返回张总的数据

---

### T28 — 触发会议结束和纪要生成

在 OpenClaw 中输入：
```
结束会议
```

**期望**：
- 触发 `meeting-orchestrator` 关闭会议
- 回复包含「会议结束」和决策/行动项数量
- 生成纪要文件到 `~/.openclaw/meeting_sessions/`

---

### T29 — 切换议程

在 OpenClaw 中输入（需先开始会议）：
```
开始会议，议程：议题A，议题B，议题C
下一个议程
```

**期望**：第二条指令后回复「进入第二项：议题B」

---

## 清理测试数据

测试完成后，清理临时文件：

```bash
# 清理测试会话（保留一份作为样本）
ls ~/.openclaw/meeting_sessions/

# 清理测试纪要
rm -rf ~/meeting_minutes_test/

# 重置当前会议状态（如果有残留）
python3 -c "
from pathlib import Path
import json
f = Path.home() / '.openclaw' / 'meeting_sessions' / 'current.json'
f.write_text(json.dumps({'state': 'idle'}))
print('会议状态已重置')
"
```

---

## 测试结果汇总模板

OpenClaw 执行完所有测试后，请按以下格式输出汇总：

```
## 测试结果汇总

### 模块一：权限校验（T01-T04）
- T01 CEO查总监：✅ 通过
- T02 员工查CEO：✅ 通过
- T03 所有人会议控制：✅ 通过
- T04 未注册人员：✅ 通过

### 模块二：人员数据查询（T05-T06）
- T05 获取mock待办：✅ 通过
- T06 不存在人员：✅ 通过

### 模块三：数据查询分发（T07-T10）
- T07 已启用数据源：✅ 通过
- T08 权限不足拒绝：✅ 通过
- T09 未启用数据源：✅ 通过
- T10 未注册数据源：✅ 通过

### 模块四：会议状态机（T11-T17）
- T11 开始会议：✅ 通过
- T12 普通发言无标签：✅ 通过
- T13 行动项识别：✅ 通过
- T14 决策识别：✅ 通过
- T15 切换议程：✅ 通过
- T16 查看状态：✅ 通过
- T17 结束会议：✅ 通过

### 模块五：纪要生成（T18-T19）
- T18 生成纪要文件：✅ 通过
- T19 验证文件内容：✅ 通过

### 模块六：输出格式化（T20-T23）
- T20 数字中文化：✅ 通过
- T21 大数字转换：✅ 通过
- T22 语音播报：✅ 通过
- T23 LCD推送容错：✅ 通过

### 模块七：端到端对话（T24-T29）
- T24 开始会议：✅ 通过
- T25 人员待办查询：✅ 通过
- T26 数据查询：✅ 通过
- T27 权限拒绝：✅ 通过
- T28 结束会议纪要：✅ 通过
- T29 切换议程：✅ 通过

---
总计：29/29 通过
```

---

## 已知限制（MVP 阶段）

| 限制 | 说明 | 计划解决 |
|---|---|---|
| 待办数据为 mock | 未接入真实飞书 API | 配置 FEISHU_APP_ID 后切换 |
| 声纹识别为 mock | pyannote 未安装时用随机向量 | 安装 `pip3 install pyannote.audio` |
| LCD 推送单向 | Pi 离线时静默跳过 | Pi 端部署后自动生效 |
| 无持久化记忆 | 会话文件重启后不自动恢复 | 后续加入自动加载 |

