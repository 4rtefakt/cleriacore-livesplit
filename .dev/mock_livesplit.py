"""A stand-in for LiveSplit's WebSocket server: accepts ws://127.0.0.1:<port>/livesplit and prints each command.

    python mock_livesplit.py        # prints the port on its first line
"""
import asyncio, sys
import websockets


async def handler(ws):
    path = getattr(getattr(ws, "request", None), "path", None) or getattr(ws, "path", "?")
    print("client on", path, flush=True)
    async for msg in ws:
        if not msg.startswith("setgametime"):
            print("recv", msg, flush=True)
        elif not getattr(handler, "gt", False):
            handler.gt = True
            print("recv setgametime (first)", flush=True)


async def main():
    async with websockets.serve(handler, "127.0.0.1", 0) as server:
        print(server.sockets[0].getsockname()[1], flush=True)
        await asyncio.Future()

asyncio.run(main())
