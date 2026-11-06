#!/usr/bin/env python3
"""把 cgmsv.exe 內嵌的訊息表（lang/msg.yml，GBK 簡體）原地改成 Big5 繁體。

用法: python3 -I patch_exe_msg.py <cgmsv.exe 原檔> <輸出 exe>
- 訊息表以 NUL 結尾，改寫後長度必須 <= 原長；多出的位元組從空白行扣，不足補空白
- 常數名稱（`xxx%`）維持 GBK；轉換規則與 make_msg_yml.py 相同
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_msg_yml import CONST_VALUE, to_big5  # noqa: E402


def blob_now(parts):
    return b"\r\n".join(parts)


def main(src, dst):
    d = open(src, "rb").read()
    i = d.index("《欢迎进入魔力宝贝》".encode("gbk"))
    s, e = d.rfind(b"\0", 0, i) + 1, d.find(b"\0", i)
    lines = d[s:e].decode("gbk").split("\r\n")
    sep = "\u0001"
    conv = subprocess.run(["opencc", "-c", "s2tw"], input=(sep.join(lines) + sep + "END").encode("utf-8"),
                          capture_output=True, check=True).stdout.decode("utf-8").split(sep)[:-1]
    assert len(conv) == len(lines)
    out = [orig.encode("gbk") if CONST_VALUE.match(orig) else to_big5(new) for orig, new in zip(lines, conv)]
    size = e - s
    # 超出長度時，從尾端往前刪空白行
    while len(blob_now(out)) > size:
        idx = max((k for k, b in enumerate(out) if b == b"" and 0 < k < len(out) - 1), default=None)
        if idx is None:
            sys.exit(f"空間不足: {len(blob_now(out))} > {size}")
        del out[idx]
    blob = b"\r\n".join(out)
    blob += b" " * (size - len(blob))
    assert len(blob) == size
    open(dst, "wb").write(d[:s] + blob + d[e:])
    print(f"patched {size} bytes at {hex(s)} -> {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
