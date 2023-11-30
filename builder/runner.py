import sys
import time
from subprocess import PIPE, Popen, run as run_native
from threading  import Thread
import logging

try:
    from Queue import Queue, Empty
except ImportError:
    from queue import Queue, Empty  # python 3.x

_NIX = 'posix' in sys.builtin_module_names


class RunError(Exception):

    def __init__(self, cmd, exception, code, out, err, user_msg=""):
        logging.info("RUNERR: %s, exception: %r" % (cmd, exception))
        self.cmd = cmd
        self.exception = exception
        self.code = code
        self.out = out
        self.err = err
        self.user_msg = user_msg

    def __repr__(self):
        return "RunError(cmd=%r, exception=%r, code=%r, out=%r, err=%r, user_msg=%r)" % (self.cmd, self.exception, self.code, self.out, self.err, self.user_msg)


def enqueue_output(out, queue):
    for line in iter(out.readline, b''):
        queue.put(line)
    out.close()

def try_read(queue, log=None, flush=True):
    if flush:
        out = ""
        r = try_read(queue, log, flush=False)

        while r != "":
            out += r
            r = try_read(queue, log, flush=False)

        return out
    try:
        line = queue.get_nowait()

        if log is not None:
            log.write(line)

        return line

    except Empty:
        return ""


def run(cmd, lock=False, log=None, errlog=None, message="", verbose=False):
    proc = None
    try: 
        proc = Popen(cmd, stdout=PIPE, stderr=PIPE, bufsize=0, close_fds=_NIX, text=True)
    except Exception as e:
        raise RunError(cmd, e, -1, "", "", message)

    logging.debug("RUNNING: %s, PID: %d" % (cmd, proc.pid))

    qo = Queue()
    to = Thread(target=enqueue_output, args=(proc.stdout, qo))
    to.daemon = True
    to.start()

    qe = Queue()
    te = Thread(target=enqueue_output, args=(proc.stderr, qe))
    te.daemon = True
    te.start()

    if not lock:
        return proc

    out = ""
    err = ""

    try:
        def consume(queue, log):
            read = try_read(queue, log)
            if verbose and read:
                sys.stdout.write(read)
                sys.stdout.flush()
            return read

        while proc.poll() is None:
            out += consume(qo, log)
            err += consume(qe, errlog)
            time.sleep(0.1)
        out += consume(qo, log)
        err += consume(qe, errlog)

    except Exception as e:
        raise RunError(cmd, e, proc.returncode, out, err, message)

    if proc.returncode:
        logging.debug("Program failed with return code: %d" % proc.returncode)
        logging.debug(err)
        logging.debug("Try running: %s" % " ".join(cmd))

    return (out, err, proc.returncode)


class Runner:

    def run(self, cmd, can_fail=False, **kwargs):
        if getattr(self, 'dry_run', False):
            logging.debug("Dry run: %s" % cmd)
            return
        if not 'lock' in kwargs:
            kwargs['lock'] = True
        if not 'verbose' in kwargs:
            kwargs['verbose'] = True
        res = run(cmd, **kwargs)
        if not can_fail and kwargs['lock'] and res[2] != 0:
            print("Command failed %s" % cmd)
            sys.exit(1)
        return res

def run_simple(cmd):
    logging.debug("Running command: %s" % cmd)
    res = run_native(cmd, stdout=PIPE, stderr=PIPE, text=True)
    logging.debug(res.stdout.strip())
    logging.debug(res.stderr.strip())
    return res
