#!/usr/bin/env python3
"""從 cgmsv.exe 抽出內建訊息表，繁化成 Big5，輸出為覆寫檔 lang/msg.yml。

用法: python3 -I make_msg_yml.py <cgmsv.exe> <輸出 msg.yml>
- 內建表是 GBK 的 `編號: "文字"` 格式，以「《欢迎进入魔力宝贝》」定位
- 常數名稱（例如 `动作_站立%`：沒有空白、只在結尾有一個 %）給 Lua 使用，維持原樣
- Big5 字第二位元組為 0x5C（\）時補成 \\，避免被當成跳脫字元
"""
import re
import subprocess
import sys

REPLACE = {"¨": "…", "ー": "－", "″": "〃"}
CONST_VALUE = re.compile(r'^\d+: "[^\s"%\\]+%"$')


def extract(exe):
    d = open(exe, "rb").read()
    i = d.index("《欢迎进入魔力宝贝》".encode("gbk"))
    return d[d.rfind(b"\0", 0, i) + 1:d.find(b"\0", i)].decode("gbk")


def to_big5(text):
    out = bytearray()
    for ch in text:
        ch = REPLACE.get(ch, ch)
        try:
            b = ch.encode("cp950")
        except UnicodeEncodeError:
            b = b"?"
        out += b
        if len(b) == 2 and b[1] == 0x5C:
            out += b"\\"
    return bytes(out)


def main(exe, dst):
    lines = extract(exe).split("\r\n")
    keep = [CONST_VALUE.match(l) is not None for l in lines]
    sep = "\u0001"
    conv = subprocess.run(["opencc", "-c", "s2tw"], input=(sep.join(lines) + sep + "END").encode("utf-8"),
                          capture_output=True, check=True).stdout.decode("utf-8").split(sep)[:-1]
    assert len(conv) == len(lines)
    out = []
    for orig, new, k in zip(lines, conv, keep):
        out.append(orig.encode("gbk") if k else to_big5(new))
    open(dst, "wb").write(b"\r\n".join(out))
    print(f"lines={len(lines)} const_kept={sum(keep)} -> {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
