"""Isolated regressions for hook payload handling and non-destructive installation."""
import json
import os
from pathlib import Path
import shutil
import shlex
import signal
import stat
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SecurityTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="setup-security-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "other user home"
        self.home.mkdir()
        self.tmp = self.base / "tmp"
        self.tmp.mkdir()
        self.fake = self.base / "bin"
        self.fake.mkdir()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("CMUX_", "SESSION_MONITOR_", "CLAUDE_PLUGIN_"))}
        self.env.update(HOME=str(self.home), TMPDIR=str(self.tmp), PATH=str(self.fake)+":"+os.environ["PATH"])
        self.stub("cmux", "exit 1")

    def stub(self, name, body):
        path = self.fake / name
        path.write_text("#!/bin/sh\n"+body+"\n")
        path.chmod(0o755)
        return path

    def wait_for(self, predicate):
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(.02)
        self.fail("timed out waiting for isolated hook")

    def test_inputs_are_private_unique_and_removed(self):
        scripts = [("session-monitor", "update-session.sh", "session-monitor-input.*"),
                   ("cmux", "claude-status-hook.sh", "cmux-pane-state/hook-input.*")]
        for plugin, name, pattern in scripts:
            with self.subTest(plugin=plugin):
                script = ROOT / "plugins" / plugin / "hooks/scripts" / name
                procs = [subprocess.Popen(["sh", str(script), "running"], env=self.env,
                         stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) for _ in range(2)]
                try:
                    self.wait_for(lambda: len(list(self.tmp.glob(pattern))) == 2)
                    files = list(self.tmp.glob(pattern))
                    self.assertNotEqual(files[0], files[1])
                    for path in files:
                        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
                    for proc in procs:
                        proc.communicate(b"{}", timeout=4)
                        self.assertEqual(proc.returncode, 0)
                    self.wait_for(lambda: not list(self.tmp.glob(pattern)))
                finally:
                    for proc in procs:
                        if proc.poll() is None:
                            proc.kill(); proc.communicate()

    def test_session_end_retains_payload_after_parent_cleanup(self):
        # Use real nohup: a shell stub drops its inherited SIGHUP protection.
        source = ROOT / "plugins/session-monitor/hooks/scripts/update-session.sh"
        script = self.base / "session-hook.sh"
        trace = self.base / "hook.trace"
        child_pid_file = self.base / "child-pid"
        release = self.base / "release-child"
        done = self.base / "child-done"
        actual_nohup = shutil.which("nohup")
        self.assertIsNotNone(actual_nohup)
        fixture = source.read_text().replace('/usr/bin/open -g ', 'true ')
        fixture = fixture.replace('exec 2>/dev/null', 'exec 2>>"$TEST_TRACE"')
        fixture = fixture.replace('3<&- >/dev/null 2>&1 &', '3<&- >/dev/null 2>>"$TEST_TRACE" &')
        fixture = fixture.replace('SESSION_MONITOR_BG=1 nohup ',
                                  'SESSION_MONITOR_BG=1 '+shlex.quote(actual_nohup)+' ')
        # Hold the child before reading stdin until the parent has exited/unlinked.
        gate = '\n'.join([
            'if [ "${SESSION_MONITOR_BG:-}" = 1 ]; then',
            '  printf "%s\\n" "$$" > "$TEST_CHILD_PID"',
            '  while [ ! -f "$TEST_RELEASE" ]; do sleep 0.01; done',
            'fi',
        ])
        fixture = fixture.replace('umask 077', 'umask 077\n'+gate, 1)
        fixture = fixture.replace('\nexit 0\n', '\n: > "$TEST_CHILD_DONE"\nexit 0\n')
        script.write_text(fixture)
        script.chmod(0o755)
        data = self.home / "data"
        data.mkdir()
        sessions = data / "sessions.jsonl"
        sessions.write_text(json.dumps({"session_id":"finish", "cwd":"fixture"})+"\n"+json.dumps({"session_id":"keep"})+"\n")
        payload = json.dumps({"session_id":"finish", "cwd":str(self.home), "hook_event_name":"SessionEnd"})
        env = self.env | {"CLAUDE_PLUGIN_DATA":str(data), "TEST_CHILD_PID":str(child_pid_file),
                          "TEST_RELEASE":str(release), "TEST_CHILD_DONE":str(done), "TEST_TRACE":str(trace)}
        child_pid = None
        try:
            result = subprocess.run(["sh", str(script)], input=payload, text=True,
                                    env=env, capture_output=True, timeout=4)
            self.assertEqual(result.returncode, 0, result.stderr)
            try:
                self.wait_for(lambda: child_pid_file.exists() and child_pid_file.read_text().strip())
            except AssertionError as exc:
                self.fail(str(exc)+": "+(trace.read_text() if trace.exists() else "no trace"))
            child_pid = int(child_pid_file.read_text())
            self.assertFalse(list(self.tmp.glob('session-monitor-input.*')))
            # A real detached worker must survive HUP while awaiting input.
            os.kill(child_pid, signal.SIGHUP)
            release.touch()
            self.wait_for(done.exists)
            self.assertNotIn('finish', sessions.read_text())
            self.assertIn('keep', sessions.read_text())
            self.assertEqual(stat.S_IMODE(sessions.stat().st_mode), 0o600)
            self.wait_for(lambda: not list(self.tmp.glob('session-monitor-input.*')))
            self.assertFalse(list(data.glob('sessions.jsonl.tmp.*')))
        finally:
            release.touch()
            if child_pid is not None and not done.exists():
                try:
                    os.kill(child_pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass

    def test_xbar_preserves_other_plugins_and_backs_up_conflicts(self):
        target = self.home / "xbar plugins"
        target.mkdir()
        other = target / "unrelated.1s.sh"; other.write_text("do not touch")
        conflict = target / "focus.5s.sh"; conflict.write_text("custom plugin")
        stale = target / "kalloc1024.2m.sh"; stale.symlink_to(target / "missing")
        env = self.env | {"XBAR_PLUGIN_DIR": str(target)}
        cmd = ["bash", str(ROOT / "xbar/install.sh")]
        result = subprocess.run(cmd+["--dry-run"], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(conflict.read_text(), "custom plugin")
        self.assertEqual(len(list(target.iterdir())), 3)
        for _ in range(2):
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(other.read_text(), "do not touch")
        backups = list(target.glob('focus.5s.sh.backup-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "custom plugin")
        self.assertEqual(len(list(target.glob('kalloc1024.2m.sh.backup-*'))), 1)
        self.assertEqual(conflict.resolve(), (ROOT/'xbar/focus.5s.sh').resolve())

    def test_xbar_rejects_source_directory_and_directory_alias(self):
        source = self.base / "source xbar"
        shutil.copytree(ROOT / "xbar", source)
        alias = self.base / "source alias"
        alias.symlink_to(source, target_is_directory=True)
        before = {p.name: p.read_bytes() for p in source.iterdir() if p.is_file()}
        for target in (source, alias):
            with self.subTest(target=target.name):
                result = subprocess.run(["bash", str(source / "install.sh")],
                    env=self.env | {"XBAR_PLUGIN_DIR": str(target)}, capture_output=True, text=True)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("must not be the source directory", result.stderr)
                self.assertFalse(any(p.is_symlink() for p in source.iterdir()))
                self.assertEqual({p.name: p.read_bytes() for p in source.iterdir() if p.is_file()}, before)

    def test_xbar_preflights_all_sources_before_any_target_mutation(self):
        source = self.base / "incomplete xbar"
        shutil.copytree(ROOT / "xbar", source)
        (source / "kalloc1024.2m.sh").unlink()
        target = self.home / "existing plugins"
        target.mkdir()
        existing = target / "claude-sessions.5s.sh"
        existing.write_text("keep custom implementation")
        missing_target = self.home / "not created"
        for destination in (target, missing_target):
            with self.subTest(destination=destination.name):
                result = subprocess.run(["bash", str(source / "install.sh")],
                    env=self.env | {"XBAR_PLUGIN_DIR": str(destination)}, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("missing executable", result.stderr)
                self.assertFalse(existing.is_symlink())
                self.assertEqual(existing.read_text(), "keep custom implementation")
                self.assertEqual(list(target.iterdir()), [existing])
                self.assertFalse(missing_target.exists())



if __name__ == '__main__':
    unittest.main()
