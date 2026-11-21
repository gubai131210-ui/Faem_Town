"""把收音机的词用代码念出来，存成 audio/radio/*.wav。

每个字是声母、韵母和声调，不再用微软在线语音。
在 farm-town/ 下运行：
    D:\\Miniconda3\\python.exe tools\\radio_voice.py
"""
import array
import json
import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "radio")
RATE = 22050
BASE = 172.0
PEAK = 20000

# 韵母：起点元音、终点元音、要不要鼻音。元音是 (F1, F2, F3)。
_F = {
    "a": (780, 1200, 2600),
    "o": (480, 820, 2500),
    "e": (520, 1480, 2480),
    "i": (280, 2280, 3200),
    "u": (340, 720, 2240),
    "v": (320, 1880, 2460),
}
_VOWEL = {
    "a": ("a", "a", False), "o": ("o", "o", False), "e": ("e", "e", False),
    "i": ("i", "i", False), "u": ("u", "u", False), "v": ("v", "v", False),
    "ai": ("a", "i", False), "ei": ("e", "i", False), "ao": ("a", "o", False),
    "an": ("a", "a", True), "en": ("e", "e", True), "ang": ("a", "o", True),
    "eng": ("e", "e", True), "ong": ("o", "u", True),
    "ia": ("i", "a", False), "iao": ("i", "o", False), "ian": ("i", "a", True),
    "in": ("i", "i", True), "ing": ("i", "i", True), "iang": ("i", "a", True),
    "iu": ("i", "u", False), "uo": ("u", "o", False), "ui": ("u", "i", False),
    "un": ("u", "e", True), "uang": ("u", "a", True), "ve": ("v", "e", False),
    "vn": ("v", "i", True),
}
# 播报里用到的字。声调 1 阴平、2 阳平、3 上声、4 去声。
_CHAR = {
    "今": ("j", "in", 1), "天": ("t", "ian", 1), "明": ("m", "ing", 2),
    "立": ("l", "i", 4), "春": ("ch", "un", 1), "雨": ("", "v", 3),
    "水": ("sh", "ui", 3), "惊": ("j", "ing", 1), "蛰": ("zh", "e", 2),
    "分": ("f", "en", 1), "清": ("q", "ing", 1), "谷": ("g", "u", 3),
    "夏": ("x", "ia", 4), "小": ("x", "iao", 3), "满": ("m", "an", 3),
    "芒": ("m", "ang", 2), "种": ("zh", "ong", 4), "至": ("zh", "i", 4),
    "暑": ("sh", "u", 3), "大": ("d", "a", 4), "秋": ("q", "iu", 1),
    "处": ("ch", "u", 3), "白": ("b", "ai", 2), "露": ("l", "u", 4),
    "寒": ("h", "an", 2), "霜": ("sh", "uang", 1), "降": ("j", "iang", 4),
    "冬": ("d", "ong", 1), "雪": ("x", "ve", 3), "晴": ("q", "ing", 2),
    "多": ("d", "uo", 1), "云": ("", "vn", 2), "有": ("", "iu", 3),
    "雷": ("l", "ei", 2), "雾": ("", "u", 4), "风": ("f", "eng", 1),
}


def read_json(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return json.load(f)


class _Pole:
    def __init__(self):
        self.y1 = 0.0
        self.y2 = 0.0

    def run(self, x, freq, bw):
        r = math.exp(-math.pi * bw / RATE)
        a1 = 2.0 * r * math.cos(2.0 * math.pi * freq / RATE)
        y = x + a1 * self.y1 - r * r * self.y2
        self.y2 = self.y1
        self.y1 = y
        return y


def _pitch(tone, u):
    if tone == 1:
        k = 1.0
    elif tone == 2:
        k = 0.76 + 0.34 * u
    elif tone == 3:
        k = 0.9 - 0.24 * (u / 0.45) if u < 0.45 else 0.66 + 0.32 * ((u - 0.45) / 0.55)
    else:
        k = 1.14 - 0.46 * u
    return BASE * k


def _lerp(a, b, u):
    return a + (b - a) * u


def _syllable(initial, vowel, tone):
    start, end, nasal = _VOWEL[vowel]
    head = 0.07 if initial else 0.0
    dur = 0.20 + head
    n = int(dur * RATE)
    poles = [_Pole(), _Pole(), _Pole(), _Pole()]
    out = []
    phase = 0.0
    rng = 0.17
    for i in range(n):
        t = i / RATE
        u = t / dur
        f0 = _pitch(tone, max(0.0, (t - head) / (dur - head)) if t > head else 0.0)
        phase += f0 / RATE
        pulse = 1.0 if phase >= 1.0 else 0.0
        if phase >= 1.0:
            phase -= 1.0
        rng = math.fmod(rng * 17.13 + 0.31, 1.0)
        noise = rng * 2.0 - 1.0
        src = 0.0
        if t < head:
            if initial in ("m", "n", "l"):
                src = pulse * 0.4
            else:
                src = noise * 0.55
        else:
            src = pulse * 0.85 + noise * 0.02
        vu = 0.0 if t < head else (t - head) / (dur - head)
        fa = _F[start]
        fb = _F[end]
        f1 = _lerp(fa[0], fb[0], vu)
        f2 = _lerp(fa[1], fb[1], vu)
        f3 = _lerp(fa[2], fb[2], vu)
        if nasal and vu > 0.62:
            f2 = _lerp(f2, 900, (vu - 0.62) / 0.38)
            src += pulse * 0.25
        y = poles[0].run(src, f1, 90)
        y += 0.65 * poles[1].run(src, f2, 110)
        y += 0.25 * poles[2].run(src, f3, 160)
        if nasal and vu > 0.62:
            y += 0.45 * poles[3].run(src, 280, 80)
        if t < head and initial not in ("m", "n", "l", ""):
            y = poles[3].run(noise, 1800 if initial in ("j", "q", "x") else 3200, 400) * 0.35
        env = min(t / 0.012, 1.0) * min((dur - t) / 0.03, 1.0)
        out.append(y * env)
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak for v in out]


def speak(text):
    samples = []
    for ch in text:
        if ch in ("，", ",", "、"):
            samples.extend([0.0] * int(0.10 * RATE))
            continue
        if ch in ("。", ".", "！", "？"):
            samples.extend([0.0] * int(0.16 * RATE))
            continue
        if ch not in _CHAR:
            raise SystemExit("没有这个字的读音：%s" % ch)
        initial, vowel, tone = _CHAR[ch]
        samples.extend(_syllable(initial, vowel, tone))
        samples.extend([0.0] * int(0.03 * RATE))
    if not samples:
        raise SystemExit("空的一句：%s" % text)
    peak = max(abs(v) for v in samples)
    if peak < 0.05:
        raise SystemExit("念出来是静音：%s" % text)
    gain = PEAK / peak
    return array.array("h", (max(-32767, min(32767, int(v * gain))) for v in samples))


def write_wav(path, samples):
    raw = samples.tobytes()
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(raw)) + b"WAVEfmt ")
        f.write(struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(raw)) + raw)
    os.replace(tmp, path)


def main():
    lines = read_json("tools", "radio_lines.json")
    terms = read_json("data", "solar_terms.json")
    os.makedirs(OUT, exist_ok=True)
    jobs = [("today_" + t["id"], lines["today"].replace("{term}", t["name"])) for t in terms]
    jobs.append(("tomorrow", lines["tomorrow"]))
    jobs += [("w_" + kind, text) for kind, text in lines["weather"].items()]
    for name, text in jobs:
        samples = speak(text)
        write_wav(os.path.join(OUT, name + ".wav"), samples)
        print("%s\t%s\t%d" % (name, text, len(samples)))
    print("COUNT", len(jobs))


if __name__ == "__main__":
    main()
