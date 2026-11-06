#!/usr/bin/env python3
"""遊戲端圖檔（client/CrossGate/bin 的 GraphicInfo*.bin／Graphic*.bin）解成 PNG，給角色管理頁顯示道具圖示。

格式（實測）：
- GraphicInfo：每筆 40 bytes `<IIIiiIIBBB5sI`＝檔內序號、在 Graphic 檔的位置、長度、x/y 偏移、寬、高、…、圖號。
  道具、NPC 用的「圖號」是最後一欄（itemset.txt 的圖號，例：國民頭盔 21477），每個 GraphicInfo 檔的序號都從 0 開始。
- Graphic：`RD` + 版本 + 1 byte + 寬 + 高 + 長度（16 bytes 表頭）；版本 1 是壓縮過的調色盤索引，由下往上一列一列。
  版本 ≥2 表頭後多 4 bytes 自帶調色盤長度，調色盤接在像素後面。索引 0 是透明。
- 調色盤：系統 16 色 + bin/pal/palet_00.cgp 前 224 色（BGR）+ 系統 16 色。

解出來的圖是遊戲公司的素材，只輸出到不進版控的目錄（預設 server-b/gmsv/lua/www/img/）。
- 動畫（寵物、角色）：AnimeInfo 每筆 12 bytes `<IIHH`＝動畫號（例：哥布林 101800）、在 Anime 檔的位置、動作數；
  Anime 檔每個動作 12 bytes `<HHII`＝方向、動作、毫秒、格數，接著每格 10 bytes `<IhhH`，第一欄是「配對的 GraphicInfo 檔」的檔內序號。
  同一動畫號有多筆時取第一筆；只取站立（動作 0）面向左下（方向 5）的第一格當寵物圖。

用法：python3 -I tools/cg_graphic.py items     # itemset.txt 用到的道具圖示全部解出
     python3 -I tools/cg_graphic.py pets      # enemybase.txt 的怪物／寵物圖（站立第一格）全部解出
     python3 -I tools/cg_graphic.py anime     # 所有動畫（角色全身、寵物、NPC）站立第一格
     python3 -I tools/cg_graphic.py faces     # 角色大頭照（圖號 240000～249999、64×72）
     python3 -I tools/cg_graphic.py ids 21477 21652   # 指定圖號
"""
import glob
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = os.path.join(ROOT, 'client', 'CrossGate', 'bin')
OUT = os.path.join(ROOT, 'server-b', 'gmsv', 'lua', 'www', 'img')
ITEMSET = os.path.join(ROOT, 'server-b', 'gmsv', 'data', 'itemset.txt')
ENEMYBASE = os.path.join(ROOT, 'server-b', 'gmsv', 'data', 'enemybase.txt')
# AnimeInfo 檔 → 它的格數指向的 GraphicInfo 檔
ANIME_PAIRS = [('AnimeInfo_4.bin', 'GraphicInfo_66.bin'), ('AnimeInfoEx_1.Bin', 'GraphicInfoEx_5.bin'),
               ('AnimeInfoV3_8.bin', 'GraphicInfoV3_19.bin'), ('AnimeInfo_Joy_91.bin', 'GraphicInfo_Joy_125.bin'),
               ('AnimeInfo_Joy_EX_107.bin', 'GraphicInfo_Joy_EX_111.bin'), ('AnimeInfo_Joy_CH1.Bin', 'GraphicInfo_Joy_CH1.bin'),
               ('Puk2/AnimeInfo_PUK2_4.bin', 'Puk2/GraphicInfo_PUK2_2.bin'), ('Puk3/AnimeInfo_PUK3_2.bin', 'Puk3/GraphicInfo_PUK3_1.bin')]
STAND, FACE = 0, 5
INFO_FILES = ['GraphicInfo_66.bin', 'GraphicInfoEx_5.bin', 'GraphicInfoV3_19.bin', 'GraphicInfo_Joy_125.bin',
              'GraphicInfo_Joy_CH1.bin', 'GraphicInfo_Joy_EX_111.bin', 'Puk2/GraphicInfo_PUK2_2.bin', 'Puk3/GraphicInfo_PUK3_1.bin']

HEAD = [(0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0), (0, 0, 128), (128, 0, 128), (0, 128, 128), (192, 192, 192),
        (192, 220, 192), (166, 202, 240), (222, 0, 0), (255, 95, 0), (255, 255, 160), (0, 95, 210), (80, 210, 255), (40, 225, 40)]
TAIL = [(150, 195, 245), (95, 160, 30), (70, 125, 195), (30, 85, 155), (55, 65, 70), (30, 35, 40), (255, 251, 240), (160, 160, 164),
        (128, 128, 128), (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)]


def palette():
    raw = open(os.path.join(BIN, 'pal', 'palet_00.cgp'), 'rb').read()
    mid = [(raw[i + 2], raw[i + 1], raw[i]) for i in range(0, 224 * 3, 3)]
    return HEAD + mid + TAIL


def graphic_info_paths():
    for name in INFO_FILES:
        path = os.path.join(BIN, name)
        if os.path.exists(path):
            yield path, path.replace('GraphicInfo', 'Graphic')
        else:  # 版本號不同的檔名
            for alt in glob.glob(os.path.join(BIN, os.path.dirname(name), 'GraphicInfo*.bin')):
                yield alt, alt.replace('GraphicInfo', 'Graphic')


def load_index(wanted):
    """圖號 → (Graphic 檔, 位置, 長度)；同一圖號以 INFO_FILES 前面的檔為準"""
    found, seen = {}, set()
    for info, data in graphic_info_paths():
        if info in seen:
            continue
        seen.add(info)
        b = open(info, 'rb').read()
        for i in range(len(b) // 40):
            _, addr, length, _, _, _, _, _, _, _, _, gid = struct.unpack_from('<IIIiiIIBBB5sI', b, i * 40)
            if gid in wanted and gid not in found:
                found[gid] = (data, addr, length)
    return found


def unrle(src, size):
    out, i = bytearray(), 0
    while i < len(src) and len(out) < size:
        b = src[i]
        kind, n = b >> 4, b & 0x0F
        i += 1
        if kind in (0, 1, 2):  # 直接複製 n bytes
            for _ in range(kind):
                n = (n << 8) | src[i]
                i += 1
            out += src[i:i + n]
            i += n
        elif kind in (8, 9, 0xA):  # 同一色重複
            color = src[i]
            i += 1
            for _ in range(kind - 8):
                n = (n << 8) | src[i]
                i += 1
            out += bytes([color]) * n
        elif kind in (0xC, 0xD, 0xE):  # 透明重複
            for _ in range(kind - 0xC):
                n = (n << 8) | src[i]
                i += 1
            out += bytes(n)
        else:
            raise ValueError('unknown RLE op %02x' % b)
    return bytes(out[:size])


def decode(data, base_pal):
    if data[:2] != b'RD':
        raise ValueError('not RD')
    ver = data[2]
    w, h, _ = struct.unpack_from('<III', data, 4)
    pal, body = base_pal, data[16:]
    pal_len = 0
    if ver >= 2:
        pal_len = struct.unpack_from('<I', data, 16)[0]
        body = data[20:]
    pixels = unrle(body, w * h + pal_len) if ver & 1 else body[:w * h + pal_len]
    if pal_len:
        p = pixels[w * h:w * h + pal_len]
        pal = [(p[i + 2], p[i + 1], p[i]) for i in range(0, pal_len - 2, 3)]
        pixels = pixels[:w * h]
    return w, h, pixels, pal


def png(w, h, pixels, pal):
    rows = []
    for y in range(h - 1, -1, -1):  # 圖檔由下往上
        row = bytearray(b'\x00')
        for idx in pixels[y * w:(y + 1) * w]:
            if idx == 0 or idx >= len(pal):
                row += b'\x00\x00\x00\x00'
            else:
                row += bytes(pal[idx]) + b'\xff'
        rows.append(bytes(row))

    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(b''.join(rows), 9)) + chunk(b'IEND', b''))


def anime_frames(wanted):
    """動畫號 → (Graphic 檔, 位置, 長度)：站立、面向左下的第一格（沒有就用第一個動作的第一格）"""
    found = {}
    for info_name, ginfo_name in ANIME_PAIRS:
        info, ginfo = os.path.join(BIN, info_name), os.path.join(BIN, ginfo_name)
        if not (os.path.exists(info) and os.path.exists(ginfo)):
            continue
        b = open(info, 'rb').read()
        gi = open(ginfo, 'rb').read()
        with open(info.replace('AnimeInfo', 'Anime'), 'rb') as data:
            for i in range(len(b) // 12):
                aid, addr, actions, _ = struct.unpack_from('<IIHH', b, i * 12)
                if aid not in wanted or aid in found:
                    continue
                data.seek(addr)
                pick = None
                for _ in range(actions):
                    head = data.read(12)
                    if len(head) < 12:
                        break
                    direction, action, _, frames = struct.unpack('<HHII', head)
                    first = struct.unpack('<IhhH', data.read(10))[0] if frames else None
                    data.seek(max(frames - 1, 0) * 10, 1)
                    if first is None:
                        continue
                    if pick is None or (action == STAND and direction == FACE):
                        pick = first
                    if action == STAND and direction == FACE:
                        break
                if pick is not None and pick * 40 + 40 <= len(gi):
                    _, gaddr, glen = struct.unpack_from('<III', gi, pick * 40)
                    found[aid] = (os.path.join(BIN, ginfo_name.replace('GraphicInfo', 'Graphic')), gaddr, glen)
    return found


def all_anime_ids():
    ids = set()
    for info_name, _ in ANIME_PAIRS:
        path = os.path.join(BIN, info_name)
        if os.path.exists(path):
            b = open(path, 'rb').read()
            ids.update(struct.unpack_from('<I', b, i * 12)[0] for i in range(len(b) // 12))
    return ids


def face_ids():
    ids = set()
    for info, _ in graphic_info_paths():
        b = open(info, 'rb').read()
        for i in range(len(b) // 40):
            r = struct.unpack_from('<IIIiiIIBBB5sI', b, i * 40)
            if 240000 <= r[11] < 250000 and (r[5], r[6]) == (64, 72):
                ids.add(r[11])
    return ids


def pet_image_ids():
    ids = set()
    for line in open(ENEMYBASE, encoding='big5', errors='ignore'):
        cols = line.rstrip('\n').split('\t')
        if line.startswith('#') or len(cols) < 31:
            continue
        try:
            ids.add(int(cols[30]))  # 第 31 欄：動畫號（哥布林 101800）
        except ValueError:
            pass
    return ids


def item_image_ids():
    ids = set()
    for line in open(ITEMSET, encoding='big5', errors='ignore'):
        cols = line.rstrip('\n').split('\t')
        if line.startswith('#') or len(cols) < 13:
            continue
        try:
            ids.add(int(cols[12]))  # 第 13 欄：圖號（國民頭盔 21477）
        except ValueError:
            pass
    return ids


def export(ids, index=None):
    os.makedirs(OUT, exist_ok=True)
    pal, index = palette(), index if index is not None else load_index(ids)
    handles, ok, bad = {}, 0, []
    for gid in sorted(ids):
        if gid not in index:
            bad.append(gid)
            continue
        path, addr, length = index[gid]
        f = handles.setdefault(path, open(path, 'rb'))
        f.seek(addr)
        try:
            w, h, pixels, p = decode(f.read(length), pal)
            with open(os.path.join(OUT, '%d.png' % gid), 'wb') as out:
                out.write(png(w, h, pixels, p))
            ok += 1
        except (ValueError, IndexError, struct.error):
            bad.append(gid)
    print('exported', ok, 'missing/failed', len(bad), bad[:10])


if __name__ == '__main__':
    if sys.argv[1:2] == ['items']:
        export(item_image_ids())
    elif sys.argv[1:2] == ['pets']:
        wanted = pet_image_ids()
        export(wanted, anime_frames(wanted))
    elif sys.argv[1:2] == ['anime']:
        wanted = all_anime_ids()
        export(wanted, anime_frames(wanted))
    elif sys.argv[1:2] == ['faces']:
        export(face_ids())
    elif sys.argv[1:2] == ['ids']:
        export({int(x) for x in sys.argv[2:]})
    else:
        print(__doc__)
