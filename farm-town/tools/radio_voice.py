"""生成收音机天气播报的人声片段。

用微软在线的神经网络语音（edge-tts）合成，再切掉首尾的静音、统一音量，
存成 audio/radio/ 下的 22050 Hz 16 位单声道 wav：
    today_<节气 id>.wav   “今天，立春。”
    tomorrow.wav          “明天，”
    w_<天气 id>.wav       “晴天。”“有雨。”……

台词和音色在 tools/radio_lines.json，节气名字来自 data/solar_terms.json。
需要联网，以及两个 Python 包：edge-tts、miniaudio。

在 farm-town/ 下运行：
    python tools\\radio_voice.py
"""
import array
import asyncio
import json
import os
import struct
import sys

import edge_tts
import miniaudio

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "radio")
RATE = 22050
PEAK = 22000
# 低于这个幅度算静音
QUIET = 500
PAD_HEAD = int(RATE * 0.06)
PAD_TAIL = int(RATE * 0.18)


def read_json(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return json.load(f)


async def synth(text, voice, rate):
    """返回合成出来的 mp3 数据。"""
    data = bytearray()
    async for chunk in edge_tts.Communicate(text, voice, rate=rate).stream():
        if chunk["type"] == "audio":
            data.extend(chunk["data"])
    return bytes(data)


def to_samples(mp3):
    decoded = miniaudio.decode(mp3, output_format=miniaudio.SampleFormat.SIGNED16,
                               nchannels=1, sample_rate=RATE)
    return array.array("h", decoded.samples)


def trim_and_level(samples):
    loud = [i for i, v in enumerate(samples) if abs(v) > QUIET]
    if not loud:
        raise RuntimeError("合成出来的片段是静音")
    start = max(0, loud[0] - PAD_HEAD)
    end = min(len(samples), loud[-1] + PAD_TAIL)
    cut = samples[start:end]
    gain = PEAK / max(abs(v) for v in cut)
    return array.array("h", (max(-32768, min(32767, round(v * gain))) for v in cut))


def write_wav(path, samples):
    raw = samples.tobytes()
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(raw)) + b"WAVEfmt ")
        f.write(struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(raw)) + raw)


async def main():
    lines = read_json("tools", "radio_lines.json")
    terms = read_json("data", "solar_terms.json")
    jobs = [("today_" + t["id"], lines["today"].replace("{term}", t["name"])) for t in terms]
    jobs.append(("tomorrow", lines["tomorrow"]))
    jobs += [("w_" + kind, text) for kind, text in lines["weather"].items()]

    os.makedirs(OUT, exist_ok=True)
    for name, text in jobs:
        mp3 = await synth(text, lines["voice"], lines.get("rate", "+0%"))
        samples = trim_and_level(to_samples(mp3))
        write_wav(os.path.join(OUT, name + ".wav"), samples)
        print("%-22s %.2fs  %s" % (name, len(samples) / RATE, text))
    print("共 %d 段，音色 %s" % (len(jobs), lines["voice"]))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    asyncio.run(main())
