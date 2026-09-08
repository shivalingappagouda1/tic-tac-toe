import asyncio
import json
import base64
import urllib.request
import websockets

async def click_at(ws, x, y, delay=0.5):
    print(f'Clicking at CSS ({x:.1f}, {y:.1f})')
    await ws.send(json.dumps({
        'id': 10,
        'method': 'Input.dispatchMouseEvent',
        'params': {'type': 'mousePressed', 'x': x, 'y': y, 'button': 'left', 'clickCount': 1}
    }))
    await asyncio.sleep(0.05)
    await ws.send(json.dumps({
        'id': 11,
        'method': 'Input.dispatchMouseEvent',
        'params': {'type': 'mouseReleased', 'x': x, 'y': y, 'button': 'left', 'clickCount': 1}
    }))
    await asyncio.sleep(delay)

async def capture_screen(ws, filename):
    await ws.send(json.dumps({'id': 20, 'method': 'Page.captureScreenshot', 'params': {'format': 'png'}}))
    while True:
        msg = json.loads(await ws.recv())
        if msg.get('id') == 20:
            img = base64.b64decode(msg['result']['data'])
            with open(filename, 'wb') as f:
                f.write(img)
            print(f'Screenshot saved to {filename}')
            break

async def main():
    port = 62229
    res = urllib.request.urlopen(f'http://127.0.0.1:{port}/json')
    tabs = json.loads(res.read())
    target = next(t for t in tabs if 'Tic-Tac-Toe' in t.get('title', ''))
    ws_url = target['webSocketDebuggerUrl']

    # Measured CSS coordinates in Vs Computer mode:
    cols = [257.4, 389.6, 521.7]
    rows = [250.4, 382.6, 514.8]
    cells = {
        0: (cols[0], rows[0]),
        1: (cols[1], rows[0]),
        2: (cols[2], rows[0]),
        3: (cols[0], rows[1]),
        4: (cols[1], rows[1]),
        5: (cols[2], rows[1]),
        6: (cols[0], rows[2]),
        7: (cols[1], rows[2]),
        8: (cols[2], rows[2]),
    }

    mode_2p = (350.0, 97.4)
    mode_com = (511.3, 97.4)
    diff_easy = (287.0, 137.0)
    diff_med = (382.0, 137.0)
    diff_hard = (478.0, 137.0)

    # Scroll down slightly or use buttons at bottom
    # Bottom buttons in SingleChildScrollView:
    new_round_btn = (302.6, 680.0)
    reset_btn = (518.3, 680.0)

    async with websockets.connect(ws_url, max_size=20*1024*1024) as ws:
        await ws.send(json.dumps({'id': 1, 'method': 'Runtime.enable'}))
        await ws.send(json.dumps({'id': 2, 'method': 'Page.enable'}))

        # 1. Switch to Easy difficulty and win as Human
        print('--- 1. Switching to Easy Mode ---')
        await click_at(ws, *diff_easy, delay=0.5)

        # Reset board
        print('--- Resetting for Human Win test ---')
        await click_at(ws, *mode_com, delay=0.5) # Re-taps mode to clear board

        # Human plays row 0: cells 0, 1, 2
        print('--- Human move 0 ---')
        await click_at(ws, *cells[0], delay=0.8) # Human X, computer responds
        print('--- Human move 1 ---')
        await click_at(ws, *cells[1], delay=0.8) # Human X, computer responds
        print('--- Human move 2 (Win) ---')
        await click_at(ws, *cells[2], delay=1.0) # Human X wins!

        await capture_screen(ws, r'C:\Users\shiva\.gemini\antigravity\brain\aa682331-a677-4e09-9ada-2a5ed29b3767\scratch\live_human_win.png')

        # 2. Hard Mode: Minimax test (Play to Draw or Computer Win)
        print('--- 2. Switching to Hard Mode ---')
        await click_at(ws, *diff_hard, delay=0.5)
        # Clear board by re-tapping Vs Computer
        await click_at(ws, *mode_com, delay=0.5)

        # Minimax duel: Human plays 0 (corner)
        print('--- Hard Mode: Human plays 0 ---')
        await click_at(ws, *cells[0], delay=0.8) # Computer must take 4 (center)
        # Human plays 8 (opposite corner)
        print('--- Hard Mode: Human plays 8 ---')
        await click_at(ws, *cells[8], delay=0.8) # Computer must take side (e.g. 1 or 3 or 5 or 7)
        # Human plays 2
        print('--- Hard Mode: Human plays 2 ---')
        await click_at(ws, *cells[2], delay=0.8) # Computer must block at 1
        # Human plays 7
        print('--- Hard Mode: Human plays 7 ---')
        await click_at(ws, *cells[7], delay=0.8) # Computer moves
        # Finish draw moves
        for c in [3, 5, 6]:
            await click_at(ws, *cells[c], delay=0.7)

        await capture_screen(ws, r'C:\Users\shiva\.gemini\antigravity\brain\aa682331-a677-4e09-9ada-2a5ed29b3767\scratch\live_hard_draw.png')

        # 3. Two-Player mode verification
        print('--- 3. Switching back to Two Players Mode ---')
        await click_at(ws, *mode_2p, delay=0.8)
        await capture_screen(ws, r'C:\Users\shiva\.gemini\antigravity\brain\aa682331-a677-4e09-9ada-2a5ed29b3767\scratch\live_2p_switched_back.png')

if __name__ == '__main__':
    asyncio.run(main())
