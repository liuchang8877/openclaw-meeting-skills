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
