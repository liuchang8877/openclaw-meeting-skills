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
