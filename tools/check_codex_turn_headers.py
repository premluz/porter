#!/usr/bin/env python3
"""Report structural header compatibility across real Codex surfaces; never print metadata or message text."""
import collections
import re
import sys
from pathlib import Path

MARKERS = (
    b'"type":"event_msg","payload":{"type":"task_complete"',
    b'"type":"event_msg","payload":{"type":"turn_aborted"',
)
HEADER = re.compile(rb'\{"timestamp":"[^"\n]+",(?:"ordinal":[0-9]+,)?')
ROOT = Path.home() / '.codex' / 'sessions'


def inspect(path):
    with path.open('rb') as stream:
        meta = stream.readline()
        surface = 'VSCode' if b'"originator":"codex_vscode"' in meta else 'other'
        for line in stream:
            for marker in MARKERS:
                offset = line.find(marker)
                if offset < 0:
                    continue
                header = line[:offset]
                shape = 'ordinal' if b'"ordinal":' in header else 'without ordinal'
                return surface, shape, HEADER.fullmatch(header) is not None
    return None


def main():
    if not ROOT.is_dir():
        raise RuntimeError('No Codex session directory; no real-header verification available')
    counts = collections.Counter()
    for path in ROOT.rglob('*.jsonl'):
        result = inspect(path)
        if result:
            counts[result] += 1
    if not counts:
        raise RuntimeError('No end markers; no real-header verification available')
    for (surface, shape, compatible), count in sorted(counts.items()):
        print(f'{surface}: {shape}, compatible={compatible}, sessions={count}')
    if any(not key[2] for key in counts):
        return 1
    if len({key[:2] for key in counts}) < 2:
        raise RuntimeError('Only one dataset shape found; second-dataset verification unavailable')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError) as error:
        print(f'Codex header check failed: {error}', file=sys.stderr)
        sys.exit(1)
