#!/usr/bin/env python3
"""cgmsv 伺服器資料繁化：GBK 簡體 → Big5（cp950）繁體。

用法: python3 -I convert_big5.py <目錄> [<目錄> ...]
- 含 NUL 的檔案視為二進位，略過；原版日服遺留的 EUC-JP／Shift-JIS 檔也略過
- 合法 UTF-8 且含非 ASCII 的檔案：維持 UTF-8，只做簡轉繁
- 其餘：以 gb18030 解碼 → OpenCC s2tw → cp950 編碼；cp950 無法表示的字換成 '?' 並記錄
- 原地覆寫（請先備份）
"""
import collections
import re
import subprocess
import sys
from pathlib import Path

SEP = "\u0001FILESEP\u0001"


def s2tw(texts):
    """以單次 opencc 呼叫轉換多段文字。"""
    # opencc 會吃掉輸入最後的換行，所以結尾多接一段假資料再丟掉
    joined = SEP.join(list(texts) + ["END"])
    out = subprocess.run(["opencc", "-c", "s2tw"], input=joined.encode("utf-8"),
                         capture_output=True, check=True).stdout.decode("utf-8")
    parts = out.split(SEP)[:-1]
    if len(parts) != len(texts):
        raise RuntimeError("opencc 分隔失敗")
    return parts


# cp950 沒有、但有合理替代的字
REPLACE = {"¨": "…", "ー": "－", "″": "〃"}
KANA = re.compile("[ぁ-ヿ]")


def is_japanese(data):
    """原版日服遺留的 EUC-JP／Shift-JIS 檔（以 GBK 讀是亂碼），不轉換。"""
    nonascii = sum(1 for b in data if b >= 0x80) // 2 or 1
    for enc in ("euc_jp", "cp932"):
        try:
            if len(KANA.findall(data.decode(enc))) > nonascii * 0.15:
                return True
        except UnicodeDecodeError:
            pass
    return False


def classify(data):
    if b"\0" in data:
        return "binary"
    if all(b < 0x80 for b in data):
        return "ascii"
    try:
        data.decode("utf-8")
        return "utf8"
    except UnicodeDecodeError:
        pass
    if is_japanese(data):
        return "japanese"
    try:
        data.decode("gb18030")
        return "gbk"
    except UnicodeDecodeError:
        return "undecodable"


def main(dirs):
    stats = collections.Counter()
    unencodable = collections.Counter()
    jobs = []  # (path, kind, text)
    for d in dirs:
        for p in sorted(Path(d).rglob("*")):
            if not p.is_file():
                continue
            data = p.read_bytes()
            kind = classify(data)
            stats[kind] += 1
            if kind in ("utf8", "gbk"):
                text = data.decode("utf-8" if kind == "utf8" else "gb18030")
                jobs.append((p, kind, text))
            elif kind == "undecodable":
                print(f"略過（無法解碼）: {p}")

    batch = 300
    for i in range(0, len(jobs), batch):
        chunk = jobs[i:i + batch]
        converted = s2tw([t for _, _, t in chunk])
        for (p, kind, _), new in zip(chunk, converted):
            if kind == "utf8":
                p.write_bytes(new.encode("utf-8"))
            else:
                out = bytearray()
                for ch in new:
                    ch = REPLACE.get(ch, ch)
                    try:
                        out += ch.encode("cp950")
                    except UnicodeEncodeError:
                        unencodable[ch] += 1
                        out += b"?"
                p.write_bytes(bytes(out))
            stats[f"converted_{kind}"] += 1

    print("統計:", dict(stats))
    print("cp950 無法表示的字（前 30）:", unencodable.most_common(30))
    print("無法表示的總字數:", sum(unencodable.values()))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
