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
