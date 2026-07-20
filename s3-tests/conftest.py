# Injected into the s3-tests repo root (loaded for every test session).
#
# Why this exists: the root cause of s3-tests "cascades" against a not-fully-
# compatible server is a hung request leaving a BROKEN connection in botocore's
# shared urllib3 pool — every later test reuses it and hangs too. We bound every
# request at the socket level so a hang fails fast and botocore discards the dead
# connection (it never returns a failed connection to the pool). No cascade.
#
# This replaces the earlier pytest-timeout/pytest-forked approach:
#   - pytest-timeout (signal) fired SIGALRM mid-request → poisoned the pool.
#   - pytest-forked + signal timeout → SIGALRM in the parent's waitpid → crash.
# Bounding botocore's own timeouts avoids both failure modes entirely.
import botocore.config

_orig_init = botocore.config.Config.__init__


def _patched_init(self, *args, **kwargs):
    # Only set defaults the caller didn't specify.
    kwargs.setdefault("connect_timeout", 10)   # fail fast if the gateway won't accept
    kwargs.setdefault("read_timeout", 30)      # generous enough for large-object ops
    kwargs.setdefault("retries", {"max_attempts": 1})  # no retries: see raw behavior
    _orig_init(self, *args, **kwargs)


botocore.config.Config.__init__ = _patched_init
