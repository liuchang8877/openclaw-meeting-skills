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
