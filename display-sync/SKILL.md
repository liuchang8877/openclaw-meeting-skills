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
