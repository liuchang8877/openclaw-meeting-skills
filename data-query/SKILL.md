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
