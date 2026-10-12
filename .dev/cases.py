import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LP = "[lua:4rtefakt.livesplit] "


def server(extra=""):
    """The mock LiveSplit on a free port: (process, env additions, lines for the mod's settings)."""
    def start():
        p = subprocess.Popen([sys.executable, "-u", os.path.join(HERE, "mock_livesplit.py")], stdout=subprocess.PIPE, text=True)
        port = p.stdout.readline().strip()
        return p, {"CLERIA_DRIVE_REALTIME": "1"}, 'Address="ws://127.0.0.1:%s/livesplit"\n%s' % (port, extra)
    return start


CASES = {
    # A new game resets and starts the timer (queued until the socket opens); a floor boss's flag splits; a duel
    # (flag 156 up then down, no boss flag) splits too.
    "splits": dict(room="S_10/S_1009/S_1009", server=server(),
        drive="120:lua=ls;130:flag=220,1;190:flag=156,1;250:flag=156,0;330:lua=ls;360:quit",
        expect=[LP + "connected to ws://127.0.0.1:", LP + "-> reset", LP + "-> starttimer", LP + "status connected sent 2",
                LP + "-> split", LP + "-> split", LP + "status connected sent 4",
                "==== server", "client on /livesplit", "recv reset", "recv starttimer", "recv split", "recv split"]),
    # Mid-bosses off: the duel sends nothing. Game time on: initgametime, then the clock.
    "options": dict(room="S_10/S_1009/S_1009", server=server("SplitMidBosses=0\nGameTime=1"),
        drive="190:flag=156,1;250:flag=156,0;330:lua=ls;360:quit",
        expect=[LP + "-> starttimer", LP + "-> initgametime", "==== server", "recv initgametime", "recv setgametime (first)"],
        absent=["-> split", "recv split"]),
    # Nothing listening: the mod keeps trying and the game goes on.
    "no_server": dict(room="S_10/S_1009/S_1009", settings='Address="ws://127.0.0.1:1/livesplit"',
        env={"CLERIA_DRIVE_REALTIME": "1"},
        drive="200:lua=ls;230:quit", expect=[LP + "status not connected", " queued 2"]),
}
