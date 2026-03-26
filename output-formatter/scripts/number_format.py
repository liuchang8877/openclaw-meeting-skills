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
