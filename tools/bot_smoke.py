#!/usr/bin/env python3
"""bot 冒煙測試：用管理 API 讓兩個 bot 走一遍「登入 → 組隊 → 打一場 → 回東醫 → 重新登入 → 練等」，逐項回報 PASS／FAIL。

用法：python3 -I tools/bot_smoke.py [隊長帳號] [隊員帳號]（預設 aitest01 aitest02，要先在管理頁加過）
改了 botlogin／botpanel／autobattle 之後跑一次。會把兩隻傳到芙蕾雅打怪；結束時隊員已離隊（重新登入）、練等已關。
"""
import json
import sys
import time
import urllib.request

API = 'http://127.0.0.1:10086/api/'
FIELD = (100, 500, 230)  # 芙蕾雅東門外 1004 區，會遇敵（470,196 是回城的傳送格）
NURSE = (1112, 8, 31)    # 東醫護士正下方


def call(api, body=None):
    req = urllib.request.Request(API + api, data=json.dumps(body).encode() if body else None)
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read())


def act(account, action, **kw):
    return call('botact', {'account': account, 'action': action, **kw})


def bots():
    return {b['account']: b for b in call('bots')}


def wait(cond, secs):
    end = time.time() + secs
    while time.time() < end:
        if cond(bots()):
            return True
        time.sleep(0.5)
    return False


def pos(b):
    c = b.get('char') or {}
    return c.get('floor'), c.get('x'), c.get('y')


def main():
    leader, member = (sys.argv[1:3] + ['aitest01', 'aitest02'][len(sys.argv[1:3]):])[:2]
    results = []

    def check(name, ok, detail=''):
        results.append(ok)
        print(f'{"PASS" if ok else "FAIL"}  {name}{"  " + detail if detail and not ok else ""}')
        return ok

    try:
        state = bots()
    except OSError as e:
        sys.exit(f'FAIL  管理 API 連不到（伺服器沒在跑？）：{e}')
    if not check('帳號已登錄', leader in state and member in state, f'沒有 {leader}／{member}，先在管理頁新增'):
        sys.exit(1)

    for a in (leader, member):
        if state[a]['state'] != 'online':
            act(a, 'login')
    if not check('兩隻都上線', wait(lambda s: all(s[a]['state'] == 'online' for a in (leader, member)), 30),
                 str({a: (bots()[a]['state'], bots()[a].get('err')) for a in (leader, member)})):
        sys.exit(1)

    for a in (leader, member):
        act(a, 'grind', on=False)  # 上次中途失敗留下的練等
        act(a, 'leave')
        act(a, 'auto', on=True)
    act(member, 'join', leader=leader)
    s = bots()
    check('組隊', s[leader]['char']['isLeader'] and s[member]['char'].get('leaderHex') == s[leader]['char']['nameHex'])

    act(leader, 'warp', floor=FIELD[0], x=FIELD[1], y=FIELD[2])
    check('傳送到野外（隊員跟著）', pos(bots()[member])[0] == FIELD[0], str(pos(bots()[member])))
    r = act(leader, 'encount')
    entered = check('遇敵', r['ok'] and wait(lambda s: s[leader]['char']['battle'], 5))
    if entered:
        check('戰鬥自動打完、回到地圖（Rg N／eL 0）',
              wait(lambda s: not s[leader]['char']['battle'] and not s[member]['char']['battle'], 90),
              '90 秒內沒結束：看 pktlog.py 該帳號 LYIm')

    act(leader, 'hospital')
    arrived = wait(lambda s: pos(s[leader]) == NURSE, 180)  # 一路走到東醫（路上會遇敵）
    check('走到東醫護士前', arrived, str(pos(bots()[leader])))
    if arrived:
        s = bots()
        f, x, y = pos(s[member])
        check('隊員跟在後面', f == NURSE[0] and max(abs(x - NURSE[1]), abs(y - NURSE[2])) == 1, str((f, x, y)))
        # 到護士前的下一步（0.4 秒後）才補，等一下
        check('全隊補滿血', wait(lambda s: all(s[a]['char']['hp'] == s[a]['char']['maxHp'] for a in (leader, member)), 3))

    # 狀態存在角色 ExtData：重新登入要恢復
    act(member, 'logout')
    time.sleep(2)
    act(member, 'login')
    back = wait(lambda s: s[member]['state'] == 'online', 20)
    check('重新登入後自動戰鬥自動恢復', back and bots()[member]['char']['auto'])

    # 練等：在野外開練等 → 打完一場回東醫 → 補完自己傳回練功點
    act(leader, 'warp', floor=FIELD[0], x=FIELD[1], y=FIELD[2])
    act(leader, 'grind', on=True, floor=FIELD[0], x=FIELD[1], y=FIELD[2])  # 固定練功點：最近的是東醫
    check('練等自動遇敵', wait(lambda s: s[leader]['char']['battle'] and s[leader].get('activity') == 'grind', 90))  # 每步照遇敵率擲骰
    sent = False
    for _ in range(5):  # 練等每 3 秒就遇下一場，戰鬥中不能回東醫，抓空檔
        wait(lambda s: not s[leader]['char']['battle'], 90)
        if act(leader, 'hospital')['ok']:
            sent = True
            break
    check('練等中回東醫', sent and wait(lambda s: pos(s[leader]) == NURSE, 180))
    check('補完自己回練功點', wait(lambda s: pos(s[leader])[0] == FIELD[0], 180), str(pos(bots()[leader])))  # 走回去（受傷時先繞去醫師）
    act(leader, 'grind', on=False)
    wait(lambda s: not s[leader]['char']['battle'], 90)

    print(f'\n{sum(results)}/{len(results)} PASS')
    sys.exit(0 if all(results) else 1)


if __name__ == '__main__':
    main()
