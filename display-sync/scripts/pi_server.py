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
