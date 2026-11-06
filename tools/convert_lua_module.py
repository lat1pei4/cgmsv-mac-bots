#!/usr/bin/env python3
"""把 UTF-8 的 cgmsv Lua 模組轉成伺服器可用的混合編碼。

用法: python3 -I convert_lua_module.py <輸入 UTF-8 .lua> <輸出 .lua>
- 字串常值（'...'、"..."、[[...]]）：OpenCC s2tw → Big5，給繁體用戶端顯示；短字串裡 Big5 第二位元組是 \\ 時補成 \\\\
- 其餘（識別字、CONST 名稱、註解）：GBK 簡體，對得上框架 Const.lua 的 GBK 常數名稱
- 識別字中若有 GBK 第二位元組不是英數字的字（Lua 詞法會斷掉），列出警告
"""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_msg_yml import to_big5  # noqa: E402

LONG_OPEN = re.compile(r"\[(=*)\[")


def tokenize(src):
    """回傳 [(kind, text)]，kind 為 code／comment／short／long。"""
    out, i, n, buf = [], 0, len(src), []

    def flush():
        if buf:
            out.append(("code", "".join(buf)))
            buf.clear()

    while i < n:
        c = src[i]
        if src.startswith("--", i):
            m = LONG_OPEN.match(src, i + 2)
            if m:
                end = src.find("]" + m.group(1) + "]", m.end())
                end = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            flush()
            out.append(("comment", src[i:end]))
            i = end
        elif c in "'\"":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            flush()
            out.append(("short", src[i:j + 1]))
            i = j + 1
        elif c == "[" and LONG_OPEN.match(src, i):
            m = LONG_OPEN.match(src, i)
            end = src.index("]" + m.group(1) + "]", m.end()) + len(m.group(1)) + 2
            flush()
            out.append(("long", src[i:end]))
            i = end
        else:
            buf.append(c)
            i += 1
    flush()
    return out


def s2tw(texts):
    sep = "\u0001"
    res = subprocess.run(["opencc", "-c", "s2tw"], input=(sep.join(texts) + sep + "END").encode("utf-8"),
                         capture_output=True, check=True).stdout.decode("utf-8").split(sep)[:-1]
    assert len(res) == len(texts)
    return res


def check_identifiers(code):
    bad = set()
    for word in re.findall(r"[^\x00-\x7f]+", code):
        for ch in word:
            b = ch.encode("gbk")
            if len(b) == 2 and not chr(b[1]).isalnum() and b[1] < 0x80:
                bad.add(ch)
    return bad


def main(src_path, dst_path):
    toks = tokenize(open(src_path, encoding="utf-8").read())
    idx = [k for k, (kind, _) in enumerate(toks) if kind in ("short", "long")]
    conv = s2tw([toks[k][1] for k in idx])
    converted = dict(zip(idx, conv))
    out, bad, unenc = bytearray(), set(), 0
    for k, (kind, text) in enumerate(toks):
        if kind == "short":
            b = to_big5(converted[k])
            unenc += b.count(b"?") - text.count("?")
            out += b
        elif kind == "long":
            out += converted[k].encode("cp950", "replace")
        else:
            if kind == "code":
                bad |= check_identifiers(text)
            out += text.encode("gbk")
    open(dst_path, "wb").write(bytes(out))
    print(f"strings={len(idx)} cp950_unencodable={unenc} -> {dst_path}")
    if bad:
        print("警告：識別字含 GBK 第二位元組為符號的字:", "".join(sorted(bad)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
