#!/usr/bin/env python3
"""伺服器封包記錄（server-b/gmsv/log/packet_*.txt）查詢：列出某帳號的收送順序，轉成 UTF-8。

用法：python3 -I tools/pktlog.py <帳號|all> [regex] [-n 行數] [-f 檔案] [-A 行數]
  例：pktlog.py aitest01 'LYIm|Rg'      → aitest01 最近 60 行戰鬥封包
      pktlog.py 111 'LYIm C\\|20' -A 10  → 每次戰鬥結束後 10 行（看真遊戲端回了什麼）
Recv＝伺服器收到（遊戲端送出），Send＝伺服器送出。檔案是伺服器語系 Big5（地圖名等少數是 GBK，會顯示成亂碼）。
"""
import argparse
import glob
import os
import re
import sys

LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'server-b', 'gmsv', 'log')


def read_lines(path):
    with open(path, 'rb') as f:
        for raw in f.read().split(b'\n'):
            line = raw.rstrip(b'\r').decode('big5', 'replace')
            parts = line.split('\t', 4)
            if len(parts) == 5:
                yield parts  # 時間, [Send]/[Recv], fd, 帳號, 內容


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('account', help='帳號；all＝全部')
    ap.add_argument('pattern', nargs='?', help='只列內容符合這個 regex 的行')
    ap.add_argument('-n', type=int, default=60, help='只顯示最後幾筆（預設 60）')
    ap.add_argument('-A', type=int, default=0, help='符合的行之後再多列幾行同帳號的封包')
    ap.add_argument('-f', help='封包檔（預設最新的 packet_*.txt）')
    args = ap.parse_args()

    path = args.f or max(glob.glob(os.path.join(LOG_DIR, 'packet_*.txt')), default=None, key=os.path.getmtime)
    if not path:
        sys.exit('找不到封包記錄')
    rows = [p for p in read_lines(path) if args.account == 'all' or p[3] == args.account]
    if args.pattern:
        rx = re.compile(args.pattern)
        keep, after = [], 0
        for p in rows:
            if rx.search(p[4]):
                keep.append(p)
                after = args.A
            elif after > 0:
                keep.append(p)
                after -= 1
        rows = keep
    print(f'# {os.path.basename(path)}  <- 遊戲端送出（伺服器收到）  -> 伺服器送出', file=sys.stderr)
    for t, kind, _, acct, body in rows[-args.n:]:
        print(f'{t} {"<-" if kind == "[Recv]" else "->"} {acct:10} {body[:200]}')


if __name__ == '__main__':
    main()
